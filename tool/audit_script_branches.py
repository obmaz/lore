#!/usr/bin/env python3
"""Generate a reproducible inventory of LORE script branches and audit findings.

Usage: python3 tool/audit_script_branches.py > PORT_BRANCH_AUDIT.md
The Pascal coordinate scan is heuristic; this report does not certify full parity.
"""

import json
import re
from collections import Counter, defaultdict
from pathlib import Path

from audit_lorespec import scan


ROOT = Path(__file__).resolve().parents[1]
SCRIPT_PATH = ROOT / "assets/data/scripts.json"
PORTAL_PATH = ROOT / "assets/data/portals.json"
SOURCE_PATH = ROOT / "repo_source/LORE_1993_src/LORESPEC.PAS"
WORLD_PATH = ROOT / "lib/game/lore_world_manager.dart"


def map_files():
    registry = WORLD_PATH.read_text(encoding="utf-8")
    pattern = re.compile(
        r"(?m)^\s*(\d+): const MapInfo\(.*?fileName: '([^']+)'",
        re.DOTALL,
    )
    return {int(map_id): name for map_id, name in pattern.findall(registry)}


def bounds(rule):
    return (
        rule.get("x", rule.get("xMin", 1)),
        rule.get("x", rule.get("xMax", 10**9)),
        rule.get("y", rule.get("yMin", 1)),
        rule.get("y", rule.get("yMax", 10**9)),
    )


def covers(rule, map_id, x, y):
    if rule["map"] != map_id:
        return False
    x0, x1, y0, y1 = bounds(rule)
    return x0 <= x <= x1 and y0 <= y <= y1 and {"x": x, "y": y} not in rule.get(
        "excludeCoords", []
    )


def contains(earlier, later):
    if earlier["map"] != later["map"] or earlier.get("trigger", "step") != later.get(
        "trigger", "step"
    ):
        return False
    ax0, ax1, ay0, ay1 = bounds(earlier)
    bx0, bx1, by0, by1 = bounds(later)
    if not (ax0 <= bx0 and ax1 >= bx1 and ay0 <= by0 and ay1 >= by1):
        return False
    if not earlier.get("excludeCoords"):
        return True
    # An excluded point only matters when it lies in the later domain.
    return all(not covers(later, later["map"], p["x"], p["y"]) for p in earlier["excludeCoords"])


def overlaps(left, right):
    if left["map"] != right["map"] or left.get("trigger", "step") != right.get(
        "trigger", "step"
    ):
        return False
    ax0, ax1, ay0, ay1 = bounds(left)
    bx0, bx1, by0, by1 = bounds(right)
    return max(ax0, bx0) <= min(ax1, bx1) and max(ay0, by0) <= min(ay1, by1)


def spatial_overlap(left, right):
    if left["map"] != right["map"]:
        return False
    ax0, ax1, ay0, ay1 = bounds(left)
    bx0, bx1, by0, by1 = bounds(right)
    return max(ax0, bx0) <= min(ax1, bx1) and max(ay0, by0) <= min(ay1, by1)


def contradictions(require):
    issues = []
    flags = set(require.get("allFlags", []))
    not_flags = set(require.get("notAllFlags", []))
    if require.get("flag") == require.get("flagNot") and require.get("flag"):
        issues.append("flag와 flagNot이 동일")
    if require.get("flagNot") in flags:
        issues.append("flagNot이 allFlags에도 포함")
    if require.get("flag") in not_flags:
        issues.append("flag가 notAllFlags에도 포함")
    if flags & not_flags:
        issues.append("allFlags와 notAllFlags가 겹침")
    if require.get("mindRead") and require.get("mindReadInactive"):
        issues.append("독심술 활성·비활성 동시 요구")
    low = require.get("minEspLevel")
    high = require.get("maxEspLevelBelow")
    if low is not None and high is not None and low >= high:
        issues.append("초능력 레벨 범위가 비어 있음")
    if require.get("tileAtPlayerZero") and require.get("tileAtPlayerValue") not in (None, 0):
        issues.append("타일 0과 다른 타일 값을 동시 요구")
    quests = require.get("quest", [])
    if isinstance(quests, dict):
        quests = [quests]
    for quest in quests:
        value = quest.get("eq")
        if value is not None and (
            (quest.get("lt") is not None and value >= quest["lt"])
            or (quest.get("gte") is not None and value < quest["gte"])
        ):
            issues.append(f"{quest['name']} 단계 범위가 비어 있음")
        if quest.get("lt") is not None and quest.get("gte") is not None and quest["gte"] >= quest["lt"]:
            issues.append(f"{quest['name']} 단계 범위가 비어 있음")
    return issues


def false_probes(require):
    probes = []
    for key, action in (
        ("flag", "제거"),
        ("flagNot", "추가"),
        ("partyMember", "현재 파티에서 제외"),
        ("enteredFromMap", "다른 맵에서 진입"),
        ("mindRead", "독심술 끄기"),
        ("mindReadInactive", "독심술 켜기"),
        ("tileAtPlayerZero", "타일을 0 이외로"),
        ("tileAtPlayerValue", "타일을 다른 값으로"),
        ("moveDyNot", "진입 방향을 금지 값으로"),
        ("minEspLevel", "초능력 레벨 낮추기"),
        ("maxEspLevelBelow", "초능력 레벨 높이기"),
        ("notMindReadOrLowEsp", "독심술 활성·고레벨"),
    ):
        if key in require and require[key] not in (False, None):
            probes.append(f"{key} {require[key]} → {action}")
    if require.get("allFlags"):
        probes.append(f"allFlags → {require['allFlags'][0]} 제거")
    if require.get("notAllFlags"):
        probes.append(f"notAllFlags → {require['notAllFlags'][0]} 추가")
    quests = require.get("quest", [])
    if isinstance(quests, dict):
        quests = [quests]
    for quest in quests:
        probes.append(f"{quest['name']} 단계 → 조건 밖 값")
    return "; ".join(probes) or "조건 없음"


def effect_summary(steps):
    effects = []

    def visit(items):
        for step in items:
            for key in (
                "setTile", "setTileArea", "setTileAtPlayer", "setTileAtTarget",
                "teleport", "nudge", "stepBack", "battle", "flag", "questStep", "join",
                "equip", "gold", "food", "exp", "partyClass", "block", "torch",
                "rigelBlessing", "randomFlag",
            ):
                if key not in step:
                    continue
                value = step[key]
                if key == "battle":
                    detail = [f"적 {len(value.get('monsters', []))}"]
                    if value.get("victoryFlag"):
                        detail.append("승리 플래그")
                    if value.get("enemyFirst"):
                        detail.append("적 선공")
                    if value.get("onRunAway") or value.get("retryOnRunAway"):
                        detail.append("도주 분기")
                    if value.get("onRunAwayIfDead"):
                        detail.append("도주 중 지정 슬롯 격퇴")
                    if value.get("victoryIfEnemyDead"):
                        detail.append(f"격퇴 슬롯 {value['victoryIfEnemyDead']}")
                    if value.get("onEnemyDeadFlags"):
                        detail.append("적별 격퇴 플래그")
                    effects.append("battle(" + ", ".join(detail) + ")")
                    visit(value.get("onRunAway", []))
                elif key in ("setTile", "setTileArea", "setTileAtPlayer", "setTileAtTarget"):
                    effects.append(key)
                elif key in ("flag", "join", "questStep"):
                    effects.append(f"{key}:{value if isinstance(value, str) else value.get('name', '?')}")
                else:
                    effects.append(key)
            choice = step.get("choice")
            if choice:
                for option in choice.get("options", []):
                    visit(option.get("steps", []))
            for branch in step.get("randomSteps", []):
                visit(branch)

    visit(steps)
    return ", ".join(dict.fromkeys(effects)) or "대사/연출"


def source_ref(rule):
    trigger = rule.get("trigger", "step")
    file_name = {
        "talk": "LORETALK.PAS",
        "step": "LORESPEC.PAS",
        "portal": "LOREENT.PAS",
        "enter": "LOREENT.PAS",
    }.get(trigger, "원본 미확인")
    line = re.search(r"^spec-\d+-L(\d+)", rule["id"])
    return file_name + (f":{line.group(1)}" if line else " (파일 추정)")


def location(rule):
    x0, x1, y0, y1 = bounds(rule)
    fmt = lambda a, b: "*" if a == 1 and b == 10**9 else str(a) if a == b else f"{a}..{b}"
    return f"({fmt(x0, x1)}, {fmt(y0, y1)})"


def audit(scripts, portals, source_events, dimensions):
    active = [s for s in scripts if not s.get("disabled")]
    disabled = [s for s in scripts if s.get("disabled")]
    findings = defaultdict(list)
    ids = defaultdict(list)
    for script in scripts:
        ids[script["id"]].append(script)
    for script_id, variants in ids.items():
        if len(variants) <= 1:
            continue
        identities = {
            (s["map"], s.get("trigger", "step"), location(s), json.dumps(s.get("require", {}), sort_keys=True))
            for s in variants
        }
        if any(s.get("once") for s in variants) or len(identities) != len(variants):
            findings["duplicate_ids"].append(f"{script_id} ({len(variants)}개)")
        else:
            findings["shared_ids"].append(f"{script_id} ({len(variants)}개 조건별 변형)")
    for i, script in enumerate(active):
        sid = script["id"]
        for reason in contradictions(script.get("require", {})):
            findings["contradictions"].append(f"{sid}: {reason}")
        if script["map"] not in dimensions:
            findings["invalid_coordinates"].append(f"{sid}: 맵 {script['map']} 데이터 없음")
        else:
            width, height = dimensions[script["map"]]
            x0, x1, y0, y1 = bounds(script)
            if x0 > width or y0 > height or x1 < 1 or y1 < 1 or x0 > x1 or y0 > y1:
                findings["invalid_coordinates"].append(f"{sid}: {location(script)} / {width}×{height}")
        if not script.get("steps"):
            findings["empty_steps"].append(sid)
        for earlier in active[:i]:
            if earlier.get("once") or earlier.get("require"):
                continue
            if contains(earlier, script):
                findings["shadowed"].append(f"{sid} ← {earlier['id']} (무조건·반복 규칙)")
                break
    for map_id, line, x, y, effects in source_events:
        covered = any(
            s.get("trigger", "step") == "step" and covers(s, map_id, x, y)
            for s in active
        ) or any(covers(p, map_id, x, y) for p in portals)
        if not covered:
            findings["missing_source_coordinates"].append(
                f"LORESPEC.PAS:{line} 맵 {map_id} ({x},{y}) 효과={','.join(effects) or '-'}"
            )
    for script in disabled:
        if not any(overlaps(script, candidate) for candidate in active):
            label = f"맵 {script['map']} `{script['id']}` {script.get('trigger', 'step')} {location(script)} — {source_ref(script)}"
            related = [portal for portal in portals if spatial_overlap(script, portal)]
            if not related:
                findings["disabled_without_cover"].append(label)
                continue
            teleports = [step["teleport"] for step in script["steps"] if "teleport" in step]
            if teleports and all(
                any(
                    portal.get("targetMap") == target.get("map")
                    and portal.get("targetX") == target.get("x")
                    and portal.get("targetY") == target.get("y")
                    for portal in related
                )
                for target in teleports
            ):
                findings["portal_target_match"].append(label)
            elif script["steps"] and all(
                set(step) <= {"nudge", "say"} for step in script["steps"]
            ):
                findings["portal_refusal"].append(label)
            elif any("block" in step for step in script["steps"]):
                findings["portal_guard"].append(label)
            else:
                findings["portal_unverified"].append(label)
    return active, disabled, findings


def report():
    scripts = json.loads(SCRIPT_PATH.read_text(encoding="utf-8"))["scripts"]
    portals = json.loads(PORTAL_PATH.read_text(encoding="utf-8"))["portals"]
    source_events, _ = scan(str(SOURCE_PATH))
    dimensions = {}
    for map_id, name in map_files().items():
        raw = (ROOT / "assets/maps" / f"{name}.MAP").read_bytes()
        dimensions[map_id] = (raw[0], raw[1])
    active, disabled, findings = audit(scripts, portals, source_events, dimensions)

    lines = [
        "# LORE 스크립트 분기 감사",
        "",
        "`python3 tool/audit_script_branches.py > PORT_BRANCH_AUDIT.md`로 재생성한다.",
        "원본 좌표 추출은 `audit_lorespec.py`의 휴리스틱이며 46개 `on/at` 좌표만",
        "잡는다. 조건식, 동적 좌표, 원본의 모든 실행 경로를 증명하지 않는다.",
        "가림 판정은 앞선 무조건·반복 규칙이 뒤 규칙의 전 좌표를 덮는 경우만 확정한다.",
        "",
        f"전체 {len(scripts)}개 / 활성 {len(active)}개 / 비활성 {len(disabled)}개 / 원본 추출 좌표 {len(source_events)}개.",
        "",
        "## 맵별 현황",
        "",
        "| 맵 | 크기 | 활성 | 비활성 | step | talk | portal | enter |",
        "| ---: | :--- | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for map_id in sorted(dimensions):
        a = [s for s in active if s["map"] == map_id]
        d = [s for s in disabled if s["map"] == map_id]
        counts = Counter(s.get("trigger", "step") for s in a)
        width, height = dimensions[map_id]
        lines.append(
            f"| {map_id} | {width}×{height} | {len(a)} | {len(d)} | "
            f"{counts['step']} | {counts['talk']} | {counts['portal']} | {counts['enter']} |"
        )

    lines += ["", "## 검토 필요 항목", ""]
    categories = (
        ("missing_source_coordinates", "원본 추출 좌표 중 활성 규칙/포털에 없는 곳"),
        ("disabled_without_cover", "활성 규칙·포털이 모두 겹치지 않는 비활성 항목"),
        ("portal_target_match", "포털과 좌표가 겹치고 이동 목적지가 일치하는 비활성 항목"),
        ("portal_refusal", "포털과 겹치는 진입 거절 이동 분기"),
        ("portal_guard", "포털과 겹치는 차단·플래그 분기"),
        ("portal_unverified", "포털과 겹치지만 효과를 분류하지 못한 분기"),
        ("shadowed", "앞선 반복 규칙에 확정적으로 가린 규칙"),
        ("contradictions", "동시에 만족할 수 없는 조건"),
        ("invalid_coordinates", "맵 밖 또는 잘못된 좌표"),
        ("duplicate_ids", "중복 ID"),
        ("empty_steps", "효과 없는 스크립트"),
    )
    for key, title in categories:
        items = findings[key]
        lines += [f"### {title}: {len(items)}개", ""]
        lines += [f"- {item}" for item in items] or ["- 없음"]
        lines.append("")

    lines += [
        "이동 목적지 일치는 부수 효과(전투·플래그·지도 변화)의 동등성을 증명하지 않는다.",
        "포털 거절·차단 분기는 UI 및 전투 실행 경로와 별도 대조해야 한다.",
        "",
    ]

    lines += ["### 같은 ID를 공유하는 조건별 포털 분기", ""]
    lines += [f"- {item}" for item in findings["shared_ids"]] or ["- 없음"]
    lines.append("")

    lines += [
        "### 비활성으로 보관한 분기",
        "",
        "실행되지 않는 원본 보관 항목이다. 아래 목록은 이식 완료 증거가 아니다.",
        "",
    ]
    for s in disabled:
        note = " ".join(s.get("note", "조건/효과 미기록").split())
        lines.append(f"- 맵 {s['map']} `{s['id']}` {source_ref(s)} — {note}")

    lines += ["", "## 활성 분기 시나리오 목록", ""]
    lines += [
        "참 조건은 `require` 그대로이며, 거짓 탐침은 해당 조건을 뒤집는 대표 입력이다.",
        "거짓 탐침의 실제 후속 규칙은 실행 엔진의 우선순위 및 다른 조건에 따라 달라진다.",
        "",
    ]
    for map_id in sorted({s["map"] for s in active}):
        lines += [f"### 맵 {map_id}", "", "| 규칙 / 원본 | 트리거 좌표 | 참 조건 | 거짓 탐침 | 타일·전투·상태 효과 |", "| :--- | :--- | :--- | :--- | :--- |"]
        for s in (item for item in active if item["map"] == map_id):
            require = s.get("require", {})
            condition = json.dumps(require, ensure_ascii=False, separators=(",", ":")) if require else "조건 없음"
            fields = [
                f"`{s['id']}`<br>{source_ref(s)}",
                f"{s.get('trigger', 'step')} {location(s)}",
                condition,
                false_probes(require),
                effect_summary(s.get("steps", [])),
            ]
            lines.append("| " + " | ".join(str(v).replace("|", "\\|") for v in fields) + " |")
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


if __name__ == "__main__":
    print(report(), end="")

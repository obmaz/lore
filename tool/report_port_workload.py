"""Summarize where source branches live before assigning behavioral groups.

Counts are workload signals only. They do not measure implementation coverage.
"""

import argparse
import json
import re
from collections import Counter

from source_branch_inventory import ROOT, SOURCE, inventory, lex


OUTPUT = ROOT / "docs/audits/workload_audit.md"
TOP_LEVEL_ROUTINE = re.compile(
    r"^(?:\{\$[^}]*\}\s*)*(?:procedure|function)\s+([A-Za-z_][A-Za-z_0-9]*)\b",
    re.IGNORECASE,
)
MAP_FILES = {"LORESPEC.PAS", "LORETALK.PAS", "LOREENT.PAS"}
PLATFORM_FILES = {"ADLIB.PAS", "UHANX.PAS", "VOICE.PAS"}


def has_key(value, key):
    if isinstance(value, dict):
        return key in value or any(has_key(child, key) for child in value.values())
    if isinstance(value, list):
        return any(has_key(child, key) for child in value)
    return False


def battle_evidence():
    scripts = json.loads((ROOT / "assets/data/scripts.json").read_text())["scripts"]
    scenarios = json.loads(
        (ROOT / "test/fixtures/source_parity.json").read_text()
    )["scenarios"]
    battle_entries = [rule for rule in scripts
                      if not rule.get("disabled") and has_key(rule.get("steps", []), "battle")]
    battle_ids = {rule["id"] for rule in battle_entries}
    referenced = {scenario["selected"] for scenario in scenarios
                  if scenario.get("selected") in battle_ids}
    result_actions = Counter()
    for scenario in scenarios:
        if scenario.get("selected") not in battle_ids:
            continue
        for action in {step["action"] for step in scenario["trace"]}:
            if action in ("victory", "retreat"):
                result_actions[action] += 1
    return battle_entries, battle_ids, referenced, result_actions


def routine_starts(filename):
    # DOS text contains bytes that str.splitlines() treats as Unicode separators.
    lines = (SOURCE / filename).read_bytes().decode("latin1").split("\n")
    implementation = next(
        (line for line, text in enumerate(lines, 1)
         if text.strip().lower() == "implementation"),
        0,
    )
    starts = []
    for line, text in enumerate(lines, 1):
        if line <= implementation:
            continue
        match = TOP_LEVEL_ROUTINE.match(text)
        if match:
            starts.append((line, match.group(1)))
    return starts


def routine_for_line(starts, line):
    return next((name for start, name in reversed(starts) if start <= line), "program")


def map_arms(filename):
    """Return numeric map case arm spans for the three map dispatch units."""
    tokens = lex((SOURCE / filename).read_bytes())
    arms = []
    for start in range(len(tokens) - 3):
        if [token[0] for token in tokens[start : start + 4]] != [
            "case", "party", ".", "map"
        ]:
            continue
        at = start + 4
        if tokens[at][0] != "of":
            continue
        at += 1
        stack = ["case"]
        previous = at
        active = None
        while at < len(tokens):
            word, line = tokens[at]
            if word == "case":
                stack.append("case")
            elif word == "begin":
                stack.append("begin")
            elif word == "end":
                stack.pop()
                if not stack:
                    if active is not None:
                        arms.append((active, tokens[previous][1], line))
                    break
            elif len(stack) == 1 and word == ":":
                label = [token[0] for token in tokens[previous:at]
                         if token[0] not in (",", ";")]
                if len(label) == 1 and label[0].isdigit():
                    active = int(label[0])
                    previous = at + 1
            elif len(stack) == 1 and word == ";":
                if active is not None:
                    arms.append((active, tokens[previous][1], line))
                    active = None
                previous = at + 1
            at += 1
        else:
            raise ValueError(f"Unterminated map case in {filename}:{tokens[start][1]}")
    return arms


def classify(data):
    by_file = Counter()
    by_routine = Counter()
    by_map = Counter()
    unattributed_map_sites = Counter()
    routine_index = {name: routine_starts(name) for name in data["source_files"]}
    arm_index = {name: map_arms(name) for name in MAP_FILES}
    for site in data["sites"]:
        if "outcomes" not in site:
            continue
        filename = site["file"]
        by_file[filename] += 1
        routine = routine_for_line(routine_index[filename], site["line"])
        by_routine[(filename, routine)] += 1
        if filename in MAP_FILES:
            maps = {number for number, begin, end in arm_index[filename]
                    if begin <= site["line"] <= end}
            if len(maps) == 1:
                by_map[(filename, maps.pop())] += 1
            else:
                unattributed_map_sites[filename] += 1
    return by_file, by_routine, by_map, unattributed_map_sites


def report(data):
    by_file, by_routine, by_map, unattributed = classify(data)
    core = sum(count for filename, count in by_file.items()
               if filename not in MAP_FILES | PLATFORM_FILES)
    map_total = sum(by_file[name] for name in MAP_FILES)
    platform = sum(by_file[name] for name in PLATFORM_FILES)
    main_core = sum(by_file[name] for name in
                    ("LOREBATT.PAS", "LOREMENU.PAS", "LORESUB.PAS"))
    lines = [
        "# LORE 이식 작업량 1차 분해",
        "",
        "`python3 tool/report_port_workload.py --check`로 재생성 결과를 검사한다.",
        "원본의 구문 분기 지점을 파일·최상위 루틴·지도 분기로 나눈 결과다.",
        "이는 **작업량의 위치**를 보여 주며, 미구현 수나 완료율이 아니다.",
        "",
        "| 영역 | 분기 지점 | 해석 |",
        "| --- | ---: | --- |",
        f"| 지도 특수·대화·진입 (`LORESPEC`·`LORETALK`·`LOREENT`) | {map_total} | 지도별 사건과 반복되는 진입·대화 패턴이 섞여 있음 |",
        f"| 공통 게임·UI·저장 로직 (나머지 본체 8개 파일) | {core} | 전투·주문·시설·이동·생성 등 공통 엔진 규칙 |",
        f"| DOS 화면·음악·음성 유닛 | {platform} | 플랫폼 대체 범위 |",
        f"| 합계 | {map_total + core + platform} | 전체 도달 원본 |",
        "",
        f"공통 영역 {core}개 중 전투(`LOREBATT`), 주문·메뉴(`LOREMENU`), "
        f"공통 처리(`LORESUB`) 세 파일에 {main_core}개가 모여 있다. "
        "지도 사건만 확인해서 이식 완료를 선언할 수 없는 이유다.",
        "",
        "## 공통 영역에서 분기가 많은 루틴",
        "",
        "| 파일 | 최상위 루틴 | 분기 지점 |",
        "| --- | --- | ---: |",
    ]
    for (filename, routine), count in by_routine.most_common():
        if filename in MAP_FILES | PLATFORM_FILES:
            continue
        if count < 10:
            continue
        lines.append(f"| {filename} | {routine} | {count} |")
    cases = sorted(
        (site for site in data["sites"] if site["kind"] == "case"),
        key=lambda site: site["case_labels"],
        reverse=True,
    )
    lines.extend([
        "",
        "## 선택지가 많은 `case`",
        "",
        "| 원본 | 루틴 | 라벨 묶음 |",
        "| --- | --- | ---: |",
    ])
    for site in cases[:10]:
        filename = site["file"]
        routine = routine_for_line(routine_starts(filename), site["line"])
        lines.append(
            f"| {filename}:{site['line']} | {routine} | {site['case_labels']} |"
        )
    lines.extend([
        "",
        "아래 지도 표는 세 지도 분기 유닛의 `case party.map` 안에 위치한 분기만 센다.",
        "각 맵 행은 서로 다른 사건 수가 아니다. 한 사건의 중첩 조건과 반복도 포함한다.",
        "",
        "## 지도별 원본 분기 위치",
        "",
        "| 맵 | 특수 | 대화 | 진입·표지 | 합계 |",
        "| ---: | ---: | ---: | ---: | ---: |",
    ])
    for number in range(1, 28):
        values = [by_map[(name, number)] for name in
                  ("LORESPEC.PAS", "LORETALK.PAS", "LOREENT.PAS")]
        lines.append(f"| {number} | {values[0]} | {values[1]} | {values[2]} | {sum(values)} |")
    battle_entries, battle_ids, referenced, result_actions = battle_evidence()
    lines.extend([
        "",
        "지도 분기 밖의 지점: " + ", ".join(
            f"{name} {unattributed[name]}개" for name in sorted(MAP_FILES)
        ) + ". 루틴 공통 처리·지도 분기 식·분기 밖 코드가 포함된다.",
        "",
        "## 현재 전투 사건 검증 증거",
        "",
        f"활성 스크립트에는 전투 호출이 포함된 규칙 {len(battle_entries)}개, "
        f"고유 ID {len(battle_ids)}개가 있다. `source_parity.json`의 원본 근거 "
        f"시나리오에서 선택된 ID는 {len(referenced)}개다. 해당 시나리오 중 "
        f"승리 후속을 재생한 것은 {result_actions['victory']}건, "
        f"도주 후속을 재생한 것은 {result_actions['retreat']}건이다.",
        "이는 **해당 원본 근거 명세의 연결 현황**이며, 나머지 ID가 미구현이거나",
        "다른 테스트에서 검증되지 않았다는 뜻은 아니다. 동일 ID의 조건별 규칙과",
        "한 규칙의 연속 전투도 있으므로 ID 수를 독립 사건 수로 보지 않는다.",
        "",
        "원본 근거 명세에 연결되지 않은 전투 ID:",
        "",
    ])
    lines.extend(f"- `{name}`" for name in sorted(battle_ids - referenced))
    lines.extend([
        "",
        "## 작업량 해석",
        "",
        "- `case`의 상수 선택지는 데이터 표 한 건으로 처리할 수 있지만, 조건과 효과가",
        "  다른 지도 사건·전투 결과는 개별 의미 검토가 필요하다.",
        "- 지도별 숫자가 큰 곳부터 수작업을 시작하기보다, 공통 규칙을 먼저 검증하고",
        "  각 지도에는 예외적인 효과만 남기는 것이 재작업을 줄인다.",
        "- 다음 산출물은 원본 지점별 `자료 표/공통 규칙/고유 사건` 검증 묶음이다.",
        "  이 묶음이 확정되기 전에는 작업 기간을 추정하지 않는다.",
        "",
    ])
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    rendered = report(inventory())
    if args.check:
        if OUTPUT.read_text() != rendered:
            raise SystemExit("LORE workload audit is stale; regenerate it")
    else:
        OUTPUT.write_text(rendered)
    print(rendered)


if __name__ == "__main__":
    main()

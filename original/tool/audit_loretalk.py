#!/usr/bin/env python3
"""Inventory literal LORETALK.PAS `at(x,y)` locations and their data providers.

This checks spatial reachability only. A matching script or dialogue is not
proof that its conditions, choices, messages, or effects match Pascal.
"""

import json
import re
from collections import Counter
from pathlib import Path

from audit_lorespec import decode, scan


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "repo_source/LORE_1993_src/LORETALK.PAS"
SCRIPTS = ROOT / "test/fixtures/legacy_rules/scripts.json"
FACILITIES = ROOT / "test/fixtures/legacy_rules/facilities.json"
AT = re.compile(r"\bat\s*\(\s*(\d+)\s*,\s*(\d+)\s*\)", re.I)


def source_coordinates(path=SOURCE):
    events, _ = scan(str(path))
    lines = [decode(raw) for raw in path.read_bytes().split(b"\n")]
    return [
        (map_id, int(x), int(y), line)
        for map_id, line, _, _, _ in events
        for x, y in AT.findall(lines[line - 1])
    ]


def covers(rule, map_id, x, y):
    if rule["map"] != map_id:
        return False
    if rule.get("x") is not None and rule["x"] != x:
        return False
    if rule.get("y") is not None and rule["y"] != y:
        return False
    if not (rule.get("xMin", 1) <= x <= rule.get("xMax", 10**9)):
        return False
    if not (rule.get("yMin", 1) <= y <= rule.get("yMax", 10**9)):
        return False
    return {"x": x, "y": y} not in rule.get("excludeCoords", [])


def direct_providers():
    """Literal Dart LoreScript declarations; spatial coverage, not parity proof."""
    code = (ROOT / 'lib/logic/lore_talk_procedures.dart').read_text(encoding='utf-8')
    found = {}
    for name, body in re.findall(r'static const (\w+) = LoreScript\((.*?)\n  \);', code, re.S):
        if not re.search(r"trigger:\s*'talk'", body):
            continue
        fields = [re.search(rf'\b{field}:\s*(\d+)', body) for field in ('map', 'x', 'y')]
        if all(fields):
            found[tuple(int(field.group(1)) for field in fields)] = f'LoreTalkProcedures.{name}'
    dispatcher = (ROOT / 'lib/logic/lore_talk_dispatcher.dart').read_text(encoding='utf-8')
    for map_id, x, y, name in re.findall(r'\((\d+),\s*(\d+),\s*(\d+)\): LoreTalkProcedure\.(\w+)', dispatcher):
        found[(int(map_id), int(x), int(y))] = f'LoreTalkProcedure.{name}'
    mode = (ROOT / 'lib/logic/lore_talk_mode.dart').read_text(encoding='utf-8')
    parts = re.split(r'^      case (\d+):', mode, flags=re.M)
    for index in range(1, len(parts), 2):
        map_id = int(parts[index])
        for x,y in AT.findall(parts[index + 1]):
            found.setdefault((map_id,int(x),int(y)), 'LoreTalkMode.run')
    return found


def facility_providers():
    code = (ROOT / 'lib/game/lore_world_manager.dart').read_text(encoding='utf-8')
    return {(int(m),int(x),int(y)) for m,x,y in re.findall(
        r'_FacilityRule\(map: (\d+), x: (\d+), y: (\d+), facility:',code)}


def providers(coordinate, scripts, facilities):
    map_id, x, y, _ = coordinate
    found = []
    if (map_id, x, y) in direct_providers():
        found.append('dart-procedure')
    if (map_id,x,y) in facility_providers():
        return ['dart-facility']
    return found


def report(source=SOURCE, script_path=SCRIPTS, facility_path=FACILITIES):
    coordinates = source_coordinates(source)
    scripts, facilities = [], []  # Historical JSON cannot provide runtime coverage.
    rows = [
        (*entry, providers(entry, scripts, facilities))
        for entry in coordinates
    ]
    missing = [row for row in rows if not row[4]]
    by_map = Counter(row[0] for row in rows)
    lines = [
        "# LORETALK 좌표 대조",
        "",
        "`python3 tool/audit_loretalk.py > docs/audits/talk_audit.md`로 재생성한다.",
        "원본 `at(x,y)`의 모든 리터럴 좌표를 직접 Dart talkmode·시설 좌표와 대조한다. 실행 앱은 JSON 규칙을 읽지 않는다.",
        "조건·선택지·문구·효과의 동등성은 검사하지 않는다. 동적 좌표도 범위 밖이다.",
        "",
        f"원본 좌표 {len(rows)}건 / 제공자 없는 좌표 {len(missing)}건.",
        "맵별: " + ", ".join(f"{map_id}: {count}" for map_id, count in sorted(by_map.items())) + ".",
        "",
        "| 원본 줄 | 맵 | 좌표 | 제공자 |",
        "| --- | ---: | ---: | --- |",
    ]
    for map_id, x, y, line, found in rows:
        lines.append(f"| LORETALK.PAS:{line} | {map_id} | ({x},{y}) | {', '.join(found) or '미커버'} |")
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    print(report(), end="")

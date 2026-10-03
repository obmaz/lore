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
SCRIPTS = ROOT / "assets/data/scripts.json"
FACILITIES = ROOT / "assets/data/facilities.json"
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


def providers(coordinate, scripts, facilities):
    map_id, x, y, _ = coordinate
    found = []
    if any(
        not rule.get("disabled")
        and rule.get("trigger", "step") == "talk"
        and covers(rule, map_id, x, y)
        for rule in scripts
    ):
        found.append("script")
    if any(covers(rule, map_id, x, y) for rule in facilities):
        found.append("facility")
    return found


def report(source=SOURCE, script_path=SCRIPTS, facility_path=FACILITIES):
    coordinates = source_coordinates(source)
    scripts = json.loads(script_path.read_text(encoding="utf-8"))["scripts"]
    facilities = json.loads(facility_path.read_text(encoding="utf-8"))["facilities"]
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
        "원본 `at(x,y)`의 모든 리터럴 좌표를 활성 talk 스크립트와 시설 데이터와 대조한다.",
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

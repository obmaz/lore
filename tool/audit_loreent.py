#!/usr/bin/env python3
"""Compare LOREENT.PAS map loads with JSON portal destinations.

This checks source map, explicit `at(x,y)` entrances, and destination triples.
It does not compare battle, dialogue, refusal, or post-load tile effects.
"""

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "repo_source/LORE_1993_src/LOREENT.PAS"
PORTALS = ROOT / "test/fixtures/legacy_rules/portals.json"


def scan_entermode(raw):
    implementation = raw.lower().index("implementation")
    start = raw.lower().index("procedure entermode;", implementation)
    end = raw.lower().index("procedure sign;", start)
    body = raw[start:end]
    cases = list(re.finditer(r"(?m)^\s*(\d+)\s*:\s*(?:begin|if\b)", body))
    loads = re.finditer(r"with party do begin(.*?)end;\s*load\s*;", body, re.I | re.S)
    result = []
    for load in loads:
        previous = [case for case in cases if case.start() < load.start()]
        if not previous:
            raise ValueError("map load has no source map case")
        source_map = int(previous[-1].group(1))
        assignments = {}
        for field in ("map", "xaxis", "yaxis"):
            found = re.search(rf"\b{field}\s*:=\s*(\d+)", load.group(1), re.I)
            if found is None:
                raise ValueError(f"map load has no {field} assignment")
            assignments[field] = int(found.group(1))

        # Only the first five world maps use `at(x,y)` to select an entrance.
        # Later branches select by a border or an in-map portal tile.
        point = None
        if source_map <= 5:
            prior = body[previous[-1].start() : load.start()]
            ats = list(re.finditer(r"\bat\(\s*(\d+)\s*,\s*(\d+)\s*\)", prior, re.I))
            if not ats:
                raise ValueError(f"world map {source_map} load has no at(x,y)")
            point = (int(ats[-1].group(1)), int(ats[-1].group(2)))
        line = raw.count("\n", 0, start) + body.count("\n", 0, load.start()) + 1
        result.append((line, source_map, point, assignments["map"], assignments["xaxis"], assignments["yaxis"]))
    return result


def matching_portals(entrance, portals):
    _, source_map, point, target_map, target_x, target_y = entrance
    matches = []
    for portal in portals:
        if (portal["map"], portal["targetMap"], portal["targetX"], portal["targetY"]) != (
            source_map, target_map, target_x, target_y
        ):
            continue
        if point is not None and (portal.get("x"), portal.get("y")) != point:
            continue
        matches.append(portal)
    return matches


def report(source=SOURCE, portal_path=PORTALS):
    entrances = scan_entermode(source.read_text(encoding="utf-8", errors="replace"))
    portals = json.loads(portal_path.read_text(encoding="utf-8"))["portals"]
    missing = [entry for entry in entrances if not matching_portals(entry, portals)]
    lines = [
        "# LOREENT 진입 경로 대조",
        "",
        "`python3 tool/audit_loreent.py > docs/audits/entrance_audit.md`로 재생성한다.",
        "원본의 `with party do ... load`와 출발 맵, 명시적 `at(x,y)`, 목적지 맵·좌표를 비교한다.",
        "전투·대사·진입 거절·로드 후 타일 효과는 이 검사 범위 밖이다.",
        "",
        f"원본 진입 {len(entrances)}건 / 목적지 매칭 {len(entrances) - len(missing)}건 / 미매칭 {len(missing)}건.",
        "",
        "| 원본 줄 | 출발 맵·좌표 | 목적지 | 포털 규칙 수 |",
        "| --- | --- | --- | ---: |",
    ]
    for entry in entrances:
        line, source_map, point, target_map, target_x, target_y = entry
        origin = f"{source_map} {point if point is not None else '(범위/타일)'}"
        lines.append(
            f"| LOREENT.PAS:{line} | {origin} | {target_map} ({target_x},{target_y}) | {len(matching_portals(entry, portals))} |"
        )
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    print(report(), end="")

#!/usr/bin/env python3
"""Extract and execute the simple coordinate routes in LORESPEC map 17.

The supported Pascal forms are deliberately narrow. A changed form fails
extraction instead of silently reporting coverage. Run --write to refresh the
fixture and --check to reject drift in CI.
"""

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'repo_source/LORE_1993_src/LORESPEC.PAS'
MAP = ROOT / 'assets/maps/DEN4.MAP'
FIXTURE = ROOT / 'test/fixtures/map17_route_parity.json'

PATTERNS = {
    'set_y': r'if y = (\d+) then y := (\d+);',
    'row_tiles': (
        r'if y = (\d+) then for i := (\d+) to (\d+) do begin\s+'
        r'map\[i,(\d+)\] := (\d+); map\[i,(\d+)\] := (\d+);'
    ),
    'column_and_nudge': (
        r'if x = (\d+) then begin\s+for j := (\d+) to (\d+) do '
        r'map\[(\d+),j\] := (\d+);\s+y := y - (\d+);'
    ),
    'row_and_teleport': (
        r'if y = (\d+) then begin\s+for i := (\d+) to (\d+) do begin\s+'
        r'map\[i,(\d+)\] := (\d+); map\[i,(\d+)\] := (\d+);\s+'
        r'end;\s+x := (\d+); y := (\d+);'
    ),
}


def extract_rules(source: str):
    start = source.index('Procedure specialevent_part2;')
    map_start = source.index('17 : begin', start)
    map_end = source.index('18 : begin', map_start)
    scope = source[map_start:map_end]
    rules = []
    for kind, pattern in PATTERNS.items():
        matches = list(re.finditer(pattern, scope))
        if len(matches) != 1:
            raise ValueError(f'{kind}: expected one Pascal form, found {len(matches)}')
        match = matches[0]
        rules.append({
            'kind': kind,
            'line': source.count('\n', 0, map_start + match.start()) + 1,
            'args': [int(value) for value in match.groups()],
            '_offset': match.start(),
        })
    rules.sort(key=lambda rule: rule.pop('_offset'))
    return rules


def execute(rules, x: int, y: int, height: int):
    writes = []
    safe_position = [x, y]
    for rule in rules:
        kind, args = rule['kind'], rule['args']
        if kind == 'set_y' and y == args[0]:
            y = args[1]
        elif kind == 'row_tiles' and y == args[0]:
            _, first, last, row1, tile1, row2, tile2 = args
            writes += [[first, last, row1, row1, tile1],
                       [first, last, row2, row2, tile2]]
        elif kind == 'column_and_nudge' and x == args[0]:
            _, first, last, column, tile, distance = args
            writes.append([column, column, first, last, tile])
            y -= distance
        elif kind == 'row_and_teleport' and y == args[0]:
            _, first, last, row1, tile1, row2, tile2, dest_x, dest_y = args
            writes += [[first, last, row1, row1, tile1],
                       [first, last, row2, row2, tile2]]
            x, y = dest_x, dest_y
        if 1 <= y <= height:
            safe_position = [x, y]
    result = {'sourceEnd': [x, y], 'safeEnd': safe_position, 'writes': writes}
    if not 1 <= y <= height:
        result['safetyNote'] = 'Original route leaves the map; keep last valid position'
    return result


def fixture():
    source = SOURCE.read_bytes().decode('latin-1')
    rules = extract_rules(source)
    raw_map = MAP.read_bytes()
    width, height = raw_map[:2]
    cases = []
    for y in range(1, height + 1):
        for x in range(1, width + 1):
            tile = raw_map[2 + (y - 1) * width + x - 1]
            passable = tile in (0, 52, 53, 54) or 41 <= tile <= 50
            # y=95 has a preceding wantexit branch; x=22 has a boss branch.
            if not passable or y == 95 or x == 22:
                continue
            if not (x == 72 or y in (38, 44, 80)):
                continue
            result = execute(rules, x, y, height)
            cases.append({'start': [x, y], **result})
    return {'map': 17, 'source': 'LORESPEC.PAS', 'rules': rules,
            'cases': cases}


def render(data):
    """Keep one replay case per line so fixture diffs remain reviewable."""
    lines = ['{', '  "map": 17,', '  "source": "LORESPEC.PAS",',
             '  "rules": [']
    for index, rule in enumerate(data['rules']):
        comma = ',' if index + 1 < len(data['rules']) else ''
        lines.append('    ' + json.dumps(rule, ensure_ascii=False) + comma)
    lines += ['  ],', '  "cases": [']
    for index, case in enumerate(data['cases']):
        comma = ',' if index + 1 < len(data['cases']) else ''
        lines.append('    ' + json.dumps(case, ensure_ascii=False) + comma)
    lines += ['  ]', '}', '']
    return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true')
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    generated = render(fixture())
    if args.write:
        FIXTURE.write_text(generated, encoding='utf-8')
    elif args.check:
        if not FIXTURE.exists() or FIXTURE.read_text(encoding='utf-8') != generated:
            raise SystemExit('map17 route fixture is stale: run --write')
    else:
        print(generated, end='')


if __name__ == '__main__':
    main()

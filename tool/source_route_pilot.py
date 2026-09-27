#!/usr/bin/env python3
"""Extract and execute supported coordinate routes from original LORESPEC.

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
MAP_FILES = {17: 'DEN4', 20: 'DEN7'}

PATTERNS_17 = {
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
PATTERNS_20 = {
    'tile_gate': (
        r'if y = (\d+) then begin\s+if map\[x,y\] = 0 then y := (\d+)'
        r'\s+else begin\s+with party do begin\s+'
        r'xaxis := (\d+); yaxis := (\d+); map := (\d+);'
    ),
}


def extract_rules(source: str, map_id: int = 17):
    start = source.index('Procedure specialevent_part2;')
    map_start = source.index(f'{map_id} : begin', start)
    map_end = source.index(f'{map_id + 1} : begin', map_start)
    scope = source[map_start:map_end]
    rules = []
    patterns = PATTERNS_17 if map_id == 17 else PATTERNS_20
    for kind, pattern in patterns.items():
        matches = list(re.finditer(pattern, scope))
        expected = 2 if kind == 'tile_gate' else 1
        if len(matches) != expected:
            raise ValueError(f'{kind}: expected {expected} Pascal forms, found {len(matches)}')
        for match in matches:
            rules.append({
                'kind': kind,
                'line': source.count('\n', 0, map_start + match.start()) + 1,
                'args': [int(value) for value in match.groups()],
                '_offset': match.start(),
            })
    rules.sort(key=lambda rule: rule.pop('_offset'))
    return rules


def execute(rules, x: int, y: int, height: int, *, map_id=17, tile=None):
    writes = []
    safe_position = [x, y]
    result_map = map_id
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
        elif kind == 'tile_gate' and y == args[0]:
            _, passage_y, dest_x, dest_y, dest_map = args
            if tile == 0:
                y = passage_y
            else:
                x, y, result_map = dest_x, dest_y, dest_map
                safe_position = [x, y]
                break  # 원본 else 분기의 exit
        if 1 <= y <= height:
            safe_position = [x, y]
    result = {'sourceEnd': [x, y], 'safeEnd': safe_position, 'writes': writes}
    if map_id != result_map or map_id == 20:
        result['sourceMap'] = result_map
    if not 1 <= y <= height:
        result['safetyNote'] = 'Original route leaves the map; keep last valid position'
    return result


def fixture(map_id=17):
    source = SOURCE.read_bytes().decode('latin-1')
    rules = extract_rules(source, map_id)
    raw_map = (ROOT / f'assets/maps/{MAP_FILES[map_id]}.MAP').read_bytes()
    width, height = raw_map[:2]
    cases = []
    for y in range(1, height + 1):
        for x in range(1, width + 1):
            tile = raw_map[2 + (y - 1) * width + x - 1]
            passable = tile in (0, 52, 53, 54) or 41 <= tile <= 50
            # Exit and boss branches are outside this route-only interpreter.
            if not passable or y in (95, 96) or (map_id == 17 and x == 22):
                continue
            if map_id == 17 and not (x == 72 or y in (38, 44, 80)):
                continue
            if map_id == 20 and y not in (88, 71):
                continue
            for tile_value in ((0, tile) if map_id == 20 else (tile,)):
                result = execute(
                    rules, x, y, height, map_id=map_id, tile=tile_value,
                )
                case = {'start': [x, y], **result}
                if map_id == 20:
                    case['tileAtPlayer'] = tile_value
                cases.append(case)
    return {'map': map_id, 'source': 'LORESPEC.PAS', 'rules': rules,
            'cases': cases}


def render(data):
    """Keep one replay case per line so fixture diffs remain reviewable."""
    lines = ['{', f'  "map": {data["map"]},', '  "source": "LORESPEC.PAS",',
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
    parser.add_argument('--map', type=int, choices=MAP_FILES, default=17)
    args = parser.parse_args()
    destination = ROOT / f'test/fixtures/map{args.map}_route_parity.json'
    generated = render(fixture(args.map))
    if args.write:
        destination.write_text(generated, encoding='utf-8')
    elif args.check:
        if not destination.exists() or destination.read_text(encoding='utf-8') != generated:
            raise SystemExit(f'map{args.map} route fixture is stale: run --map {args.map} --write')
    else:
        print(generated, end='')


if __name__ == '__main__':
    main()

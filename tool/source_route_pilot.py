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
MAP_FILES = {17: 'DEN4', 19: 'DEN6', 20: 'DEN7'}

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
    if map_id == 19:
        return [extract_lever_a(scope, source, map_start),
                *extract_lever_b(scope, source, map_start)]
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


def extract_lever_a(scope: str, source: str, map_start: int):
    begin = scope.index('if on(11,40) then begin')
    end = scope.index('if on(41,39) then begin', begin)
    body = scope[begin:end]
    pattern = (
        r'if on\((\d+),(\d+)\) then begin\s+if party\.etc\[(\d+)\] > 0'
        r'[\s\S]*?map\[(\d+),(\d+)\] := (\d+);\s+'
        r'map\[(\d+),(\d+)\] := (\d+);'
    )
    match = re.search(pattern, body)
    if match is None:
        raise ValueError('map 19 first lever changed its Pascal form')
    line = source.count('\n', 0, map_start + begin) + 1
    return {'kind': 'lever_a', 'line': line,
            'args': [int(value) for value in match.groups()]}


def execute_lever_a(rule, *, swamp_walk: bool):
    x, y, _swamp_bit, tx1, ty1, tile1, tx2, ty2, tile2 = rule['args']
    writes = [] if swamp_walk else [
        [tx1, tx1, ty1, ty1, tile1],
        [tx2, tx2, ty2, ty2, tile2],
    ]
    return {'start': [x, y], 'sourceMap': 19, 'sourceEnd': [x, y],
            'safeEnd': [x, y], 'writes': writes,
            'swampWalkActive': swamp_walk, 'puzzleCleared': False,
            'randomRoomCount': 0}


def extract_lever_b(scope: str, source: str, map_start: int):
    begin = scope.index('if on(41,39) then begin')
    end = scope.index('if (y in [8..12])', begin)
    body = scope[begin:end]
    patterns = [
        r'if on\((\d+),(\d+)\) then begin\s+if party\.etc\[(\d+)\] > 0',
        r'map\[(\d+),(\d+)\] := (\d+);\s+if not odd\(party\.etc\[(\d+)\]\)',
        r'for j := (\d+) to (\d+) do begin\s+map\[(\d+),j\] := (\d+);\s+map\[(\d+),j\] := (\d+);',
        r'map\[(\d+),(\d+)\] := (\d+); map\[(\d+),(\d+)\] := (\d+);',
        r'for j := (\d+) to (\d+) do\s+for i := (\d+) to (\d+) do map\[i,j\] := (\d+);',
        r'party\.etc\[40\] := \(random\((\d+)\)\+1\) shl 1;',
    ]
    values = []
    for pattern in patterns:
        matches = list(re.finditer(pattern, body))
        if len(matches) != 1:
            raise ValueError(f'map 19 lever pattern {pattern}: found {len(matches)}')
        values.append([int(value) for value in matches[0].groups()])
    line = source.count('\n', 0, map_start + begin) + 1
    return [{'kind': 'lever_b', 'line': line, 'args': values}]


def execute_lever_b(rule, *, swamp_walk: bool, puzzle_cleared: bool):
    trigger, primary, columns, ends, center, random = rule['args']
    x, y, _swamp_bit = trigger
    writes = []
    if not swamp_walk:
        writes.append([primary[0], primary[0], primary[1], primary[1], primary[2]])
        if not puzzle_cleared:
            low, high, left, left_tile, right, right_tile = columns
            writes += [[left, left, low, high, left_tile],
                       [right, right, low, high, right_tile]]
            writes += [[ends[0], ends[0], ends[1], ends[1], ends[2]],
                       [ends[3], ends[3], ends[4], ends[4], ends[5]]]
            low, high, left, right, tile = center
            writes.append([left, right, low, high, tile])
    return {'start': [x, y], 'sourceMap': 19, 'sourceEnd': [x, y],
            'safeEnd': [x, y], 'writes': writes,
            'swampWalkActive': swamp_walk, 'puzzleCleared': puzzle_cleared,
            'randomRoomCount': random[0] if writes and not puzzle_cleared else 0}


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
    if map_id == 19:
        cases = [execute_lever_a(rules[0], swamp_walk=walk)
                 for walk in (False, True)]
        cases += [
            execute_lever_b(rules[1], swamp_walk=walk, puzzle_cleared=cleared)
            for walk in (False, True) for cleared in (False, True)]
        return {'map': map_id, 'source': 'LORESPEC.PAS',
                'rules': rules, 'cases': cases}
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

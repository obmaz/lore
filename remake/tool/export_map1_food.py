#!/usr/bin/env python3
"""Execute the original GROUND1 food cache over visited, food, and direction."""

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'repo_source/LORE_1993_src/LORESPEC.PAS'
MAP = ROOT / 'assets/maps/GROUND1.MAP'
OUTPUT = ROOT / 'test/fixtures/map1_food_parity.json'


def fixture():
    source = SOURCE.read_bytes().decode('latin-1')
    start = source.index('      1 : begin')
    end = source.index('      4 : begin', start)
    scope = source[start:end]
    pattern = (
        r'if party\.etc\[(\d+)\] and bit(\d+) = 0 then begin[\s\S]*?'
        r'if party\.food > (\d+) then party\.food := (\d+)\s*'
        r'else party\.food := party\.food \+ (\d+);\s*'
        r'party\.etc\[\1\] := party\.etc\[\1\] or bit\2;'
    )
    matches = list(re.finditer(pattern, scope, re.I))
    if len(matches) != 1:
        raise ValueError(f'expected one GROUND1 food cache, found {len(matches)}')
    match = matches[0]
    etc, bit, threshold, cap, amount = map(int, match.groups())
    raw_map = MAP.read_bytes()
    width, height = raw_map[:2]
    positions = [(x, y) for y in range(2, height) for x in range(2, width)
                 if raw_map[2 + (y - 1) * width + x - 1] == 0]
    if len(positions) != 1:
        raise ValueError(f'expected one interior GROUND1 special tile, found {len(positions)}')
    x, y = positions[0]
    cases = []
    for visited in (False, True):
        for food in (0, threshold, threshold + 1, cap):
            for direction, (dx, dy) in enumerate(((0, -1), (0, 1), (-1, 0), (1, 0))):
                expected_food = food if visited else (cap if food > threshold else food + amount)
                cases.append({
                    'map': 1, 'x': x, 'y': y, 'visited': visited, 'food': food,
                    'direction': direction, 'end': [x + dx, y + dy],
                    'expectedFood': expected_food, 'flag': f'etc{etc}_bit{bit}',
                })
    return {'source': 'LORESPEC.PAS',
            'line': source.count('\n', 0, start + match.start()) + 1,
            'cases': cases}


def render(data):
    lines = ['{', '  "source": "LORESPEC.PAS",',
             f'  "line": {data["line"]},', '  "cases": [']
    for index, case in enumerate(data['cases']):
        comma = ',' if index + 1 < len(data['cases']) else ''
        lines.append('    ' + json.dumps(case, ensure_ascii=False) + comma)
    return '\n'.join([*lines, '  ]', '}', ''])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    rendered = render(fixture())
    if args.check:
        if not OUTPUT.exists() or OUTPUT.read_text() != rendered:
            raise SystemExit('map 1 food fixture is stale')
    else:
        OUTPUT.write_text(rendered)


if __name__ == '__main__':
    main()

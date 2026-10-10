#!/usr/bin/env python3
"""Execute both original K_DEN2 lever branches over every saved-bit state."""

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'repo_source/LORE_1993_src/LORESPEC.PAS'
OUTPUT = ROOT / 'test/fixtures/map25_lever_parity.json'

LEVER = re.compile(
    r'if on\((\d+),(\d+)\) then begin\s*'
    r'party\.etc\[(\d+)\] := party\.etc\[\3\] or bit(\d+);'
    r'[\s\S]*?if \(party\.etc\[\3\] and bit(\d+) > 0\) and '
    r'\(party\.etc\[\3\] and bit(\d+) > 0\)\s*'
    r'then begin\s*map\[(\d+),(\d+)\] := (\d+);\s*'
    r'map\[(\d+),(\d+)\] := (\d+);',
    re.I,
)


def fixture():
    source = SOURCE.read_bytes().decode('latin-1')
    start = source.index('      25 : begin')
    end = source.index('      26 : begin', start)
    scope = source[start:end]
    matches = list(LEVER.finditer(scope))
    if len(matches) != 2:
        raise ValueError(f'expected two K_DEN2 levers, found {len(matches)}')
    branches = []
    for match in matches:
        x, y, etc, bit, first, second, x1, y1, tile1, x2, y2, tile2 = map(int, match.groups())
        if (etc, first, second) != (45, 7, 8):
            raise ValueError('K_DEN2 lever flag contract changed')
        branches.append({
            'line': source.count('\n', 0, start + match.start()) + 1,
            'x': x, 'y': y, 'bit': bit,
            'door': [[x1, y1, tile1], [x2, y2, tile2]],
        })
    cases = []
    for branch in branches:
        for a in (False, True):
            for b in (False, True):
                after_a = a or branch['bit'] == 7
                after_b = b or branch['bit'] == 8
                cases.append({
                    'line': branch['line'], 'map': 25,
                    'x': branch['x'], 'y': branch['y'],
                    'a': a, 'b': b,
                    'setBit': branch['bit'],
                    'door': branch['door'] if after_a and after_b else [],
                })
    return {'source': 'LORESPEC.PAS', 'levers': len(branches), 'cases': cases}


def render(data):
    lines = ['{', '  "source": "LORESPEC.PAS",',
             f'  "levers": {data["levers"]},', '  "cases": [']
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
            raise SystemExit('map 25 lever fixture is stale')
    else:
        OUTPUT.write_text(rendered)


if __name__ == '__main__':
    main()

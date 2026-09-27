#!/usr/bin/env python3
"""Extract the simple ordered door and seal routes from LORESPEC map 12."""

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'repo_source/LORE_1993_src/LORESPEC.PAS'
OUTPUT = ROOT / 'test/fixtures/map12_state_parity.json'


def one(pattern, scope):
    matches = list(re.finditer(pattern, scope, re.I | re.S))
    if len(matches) != 1:
        raise ValueError(f'expected one map 12 Pascal form, found {len(matches)}: {pattern}')
    return matches[0]


def fixture():
    source = SOURCE.read_bytes().decode('latin-1')
    start = source.index('      12 : begin')
    end = source.index('      13 : begin', start)
    scope = source[start:end]
    door = one(
        r'\(y=(\d+)\) and \(y1<>(\d+)\).*?if x = (\d+) then begin.*?'
        r'map\[(\d+),(\d+)\] := (\d+);.*?else begin.*?'
        r'x := (\d+); y := (\d+);', scope,
    )
    seal = one(
        r'\(y=(\d+)\) and \(party\.etc\[(\d+)\]<(\d+)\).*?'
        r'if x = (\d+) then begin.*?map\[(\d+),(\d+)\] := (\d+);.*?'
        r'party\.etc\[\2\] := (\d+);.*?else begin.*?'
        r'for i := (\d+) to (\d+) do map\[x,i\] := (\d+);', scope,
    )
    d = list(map(int, door.groups()))
    s = list(map(int, seal.groups()))
    door_line = source.count('\n', 0, start + door.start()) + 1
    seal_line = source.count('\n', 0, start + seal.start()) + 1
    cases = []
    for x in (d[2], d[2] - 1):
        for move_dy in (0, d[1]):
            triggered = move_dy != d[1]
            cases.append({
                'line': door_line, 'map': 12, 'x': x, 'y': d[0],
                'moveDy': move_dy, 'gaia': 0,
                'end': [d[6], d[7]] if triggered and x != d[2] else [x, d[0]],
                'tile': [d[3], d[4], d[5]] if triggered and x == d[2] else None,
                'questSet': None, 'trap': None,
            })
    for x in (s[3], s[3] - 1):
        for gaia in (0, s[2]):
            triggered = gaia < s[2]
            cases.append({
                'line': seal_line, 'map': 12, 'x': x, 'y': s[0],
                'moveDy': 0, 'gaia': gaia, 'end': [x, s[0]],
                'tile': [s[4], s[5], s[6]] if triggered and x == s[3] else None,
                'questSet': s[7] if triggered and x == s[3] else None,
                'trap': [x, s[8], s[9], s[10]] if triggered and x != s[3] else None,
            })
    return {'source': 'LORESPEC.PAS', 'map': 12, 'cases': cases}


def render(data):
    lines = ['{', '  "source": "LORESPEC.PAS",', '  "map": 12,', '  "cases": [']
    for index, case in enumerate(data['cases']):
        comma = ',' if index + 1 < len(data['cases']) else ''
        lines.append('    ' + json.dumps(case, ensure_ascii=False) + comma)
    return '\n'.join([*lines, '  ]', '}', ''])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    data = render(fixture())
    if args.check:
        if not OUTPUT.exists() or OUTPUT.read_text() != data:
            raise SystemExit('map 12 replay fixture is stale')
    else:
        OUTPUT.write_text(data)


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Execute the literal one-time gold cache branches in LORESPEC maps 9 and 14."""

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'repo_source/LORE_1993_src/LORESPEC.PAS'
OUTPUT = ROOT / 'test/fixtures/source_gold_replay.json'

PATTERN = re.compile(
    r'if \(on\((\d+),(\d+)\)\) and '
    r'\(party\.etc\[(\d+)\] and bit(\d+) = 0\) then begin\s*'
    r'findgold\((\d+)\);\s*'
    r'party\.etc\[\3\] := party\.etc\[\3\] or bit\4;',
    re.I,
)


def fixture():
    source = SOURCE.read_bytes().decode('latin-1')
    cases = []
    for map_id, following in ((9, 10), (14, 15)):
        start = source.index(f'      {map_id} : begin')
        end = source.index(f'      {following} : begin', start)
        scope = source[start:end]
        for match in PATTERN.finditer(scope):
            x, y, etc, bit, gold = map(int, match.groups())
            line = source.count('\n', 0, start + match.start()) + 1
            for collected in (False, True):
                cases.append({
                    'line': line, 'map': map_id, 'x': x, 'y': y,
                    'flag': f'etc{etc}_bit{bit}', 'collected': collected,
                    'gold': 0 if collected else gold,
                })
    return {'source': 'LORESPEC.PAS', 'caches': len(cases) // 2,
            'cases': cases}


def render(data):
    lines = ['{', '  "source": "LORESPEC.PAS",',
             f'  "caches": {data["caches"]},', '  "cases": [']
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
            raise SystemExit('source gold replay fixture is stale')
    else:
        OUTPUT.write_text(data)


if __name__ == '__main__':
    main()

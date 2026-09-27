#!/usr/bin/env python3
"""Extract map 24 programmer conversation's persistent Pascal effects."""

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'repo_source/LORE_1993_src/LORETALK.PAS'
OUTPUT = ROOT / 'test/fixtures/map24_talk_parity.json'


def fixture():
    source = SOURCE.read_bytes().decode('latin-1')
    start = source.index('     24 : begin')
    end = source.index('     27 : begin', start)
    scope = source[start:end]
    pattern = (
        r'if at\((\d+),(\d+)\) then begin[\s\S]*?'
        r'party\.etc\[(\d+)\] := party\.etc\[\3\] or bit(\d+);\s*'
        r'map\[(\d+),(\d+)\] := (\d+);'
    )
    matches = list(re.finditer(pattern, scope, re.I))
    if len(matches) != 1:
        raise ValueError(f'expected one map 24 persistent conversation, found {len(matches)}')
    match = matches[0]
    x, y, etc, bit, tile_x, tile_y, tile = map(int, match.groups())
    return {'source': 'LORETALK.PAS',
            'line': source.count('\n', 0, start + match.start()) + 1,
            'map': 24, 'talkAt': [x, y], 'sourceFlag': [etc, bit],
            'tile': [tile_x, tile_y, tile]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    rendered = json.dumps(fixture(), ensure_ascii=False, indent=2) + '\n'
    if args.check:
        if not OUTPUT.exists() or OUTPUT.read_text() != rendered:
            raise SystemExit('map 24 talk fixture is stale')
    else:
        OUTPUT.write_text(rendered)


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Generate executable portal destinations from every LOREENT.PAS map load."""

import argparse
import json
from pathlib import Path

from audit_loreent import matching_portals, scan_entermode

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'repo_source/LORE_1993_src/LOREENT.PAS'
PORTALS = ROOT / 'assets/data/portals.json'
OUTPUT = ROOT / 'test/fixtures/source_entrance_replay.json'


def fixture():
    source = SOURCE.read_text(encoding='utf-8', errors='replace')
    portals = json.loads(PORTALS.read_text())['portals']
    entries = scan_entermode(source)
    cases = []
    for entry in entries:
        line, source_map, point, target_map, target_x, target_y = entry
        matching = matching_portals(entry, portals)
        if not matching:
            raise ValueError(f'LOREENT.PAS:{line} has no portal destination')
        for portal in matching:
            x = point[0] if point else portal.get('x', portal.get('xMin'))
            y = point[1] if point else portal.get('y', portal.get('yMin'))
            if x is None or y is None:
                raise ValueError(f'LOREENT.PAS:{line} has no replay coordinate')
            cases.append({
                'line': line, 'map': source_map, 'x': x, 'y': y,
                'target': [target_map, target_x, target_y],
            })
    return {'source': 'LOREENT.PAS', 'loads': len(entries), 'cases': cases}


def render(data):
    lines = ['{', '  "source": "LOREENT.PAS",',
             f'  "loads": {data["loads"]},', '  "cases": [']
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
            raise SystemExit('source entrance replay fixture is stale')
    else:
        OUTPUT.write_text(data)


if __name__ == '__main__':
    main()

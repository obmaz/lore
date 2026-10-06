#!/usr/bin/env python3
"""Extract LORESPEC wantexit destinations and replay their portal coordinates."""

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'repo_source/LORE_1993_src/LORESPEC.PAS'
PORTALS = ROOT / 'test/fixtures/legacy_rules/portals.json'
OUTPUT = ROOT / 'test/fixtures/source_exit_replay.json'

MAP_CASE = re.compile(r'(?m)^      (\d+) :')
DESTINATION = re.compile(
    r'with party do begin\s*xaxis := (\d+); yaxis := (\d+); map := (\d+);'
    r'\s*end;\s*load\s*;', re.I,
)


def source_exits(source):
    start = source.index('Procedure specialevent_part1;')
    end = source.index('Procedure specialevent;', start)
    scope = source[start:end]
    cases = list(MAP_CASE.finditer(scope))
    result = []
    for index, case in enumerate(cases):
        map_id = int(case.group(1))
        body = scope[case.end():cases[index + 1].start() if index + 1 < len(cases) else len(scope)]
        exit_match = re.search(r'if wantexit then begin', body, re.I)
        if exit_match is None:
            continue
        destination = DESTINATION.search(body, exit_match.end())
        if destination is None:
            raise ValueError(f'map {map_id} exit has no literal destination')
        target_x, target_y, target_map = map(int, destination.groups())
        source_offset = start + case.end() + exit_match.start()
        result.append({
            'line': source.count('\n', 0, source_offset) + 1,
            'map': map_id,
            'target': [target_map, target_x, target_y],
        })
    return result


def fixture():
    source = SOURCE.read_bytes().decode('latin-1')
    portals = json.loads(PORTALS.read_text())['portals']
    exits = source_exits(source)
    cases = []
    for entry in exits:
        destination = entry['target']
        matching = [p for p in portals if p['map'] == entry['map'] and
                    [p['targetMap'], p['targetX'], p['targetY']] == destination]
        if len(matching) != 1:
            raise ValueError(f"LORESPEC.PAS:{entry['line']} has {len(matching)} matching exits")
        portal = matching[0]
        x = portal.get('x', portal.get('xMin', 1))
        y = portal.get('y', portal.get('yMin', 1))
        cases.append({**entry, 'x': x, 'y': y})
    return {'source': 'LORESPEC.PAS', 'exits': len(exits), 'cases': cases}


def render(data):
    lines = ['{', '  "source": "LORESPEC.PAS",',
             f'  "exits": {data["exits"]},', '  "cases": [']
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
            raise SystemExit('source exit replay fixture is stale')
    else:
        OUTPUT.write_text(data)


if __name__ == '__main__':
    main()

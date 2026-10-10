"""Extract Load's map classes and facing boundary cases from original Pascal.

This proves source-expression parity, not independent EXE/BGI equivalence.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'repo_source/LORE_1993_src/LORESUB.PAS'
OUTPUT = ROOT / 'test/fixtures/source_load_facing.json'


def fixture():
    source = SOURCE.read_bytes()
    text = source.decode('latin1')
    implementation = text.lower().index('implementation')
    start = text.index('Procedure Load;', implementation)
    body = text[start:text.index('Procedure Save;', start)]
    assert 'if ymax div 2 > y then face := 0 else face := 1;' in body
    assert 'if (position <> town) or (party.map = 26) then face := face + 4;' in body
    names = {int(i): name.upper() for i, name in re.findall(r"(\d+)\s*:\s*s := '([a-z0-9_]+)'", body)}
    classes = {}
    position = body.split('case party.map of')[2].split('end;')[0]
    for labels, category in re.findall(r'([\d.,]+)\s*:\s*position := (\w+)', position):
        for label in labels.split(','):
            bounds = [int(n) for n in label.split('..')]
            for i in range(bounds[0], bounds[-1] + 1):
                classes[i] = category
    assert set(names) == set(range(1, 28))
    cases = []
    for i, name in sorted(names.items()):
        height = (ROOT / f'repo_source/LORE_1993_runtime/{name}.MAP').read_bytes()[1]
        category = classes.get(i, 'keep')
        for y in sorted({1, height // 2 - 1, height // 2, height - 1, height}):
            face = (0 if height // 2 > y else 1) + (4 if category != 'town' or i == 26 else 0)
            cases.append(dict(map=i, name=name, category=category, height=height, y=y, face=face))
    return dict(source='LORESUB.PAS:1677-1759', sha256=hashlib.sha256(source).hexdigest(),
                scope='Original Pascal expression and MAP headers; not native EXE execution.', cases=cases)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    output = json.dumps(fixture(), ensure_ascii=False, indent=2) + '\n'
    if args.check:
        if not OUTPUT.exists() or OUTPUT.read_text() != output:
            raise SystemExit('Load facing fixture drifted')
        print('Load facing fixture is current')
    else:
        OUTPUT.write_text(output)


if __name__ == '__main__':
    main()

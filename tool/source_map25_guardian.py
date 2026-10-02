"""Extract the closed LORESPEC map 25 guardian branch for independent replay.

This is a narrow source recognizer, not a Pascal interpreter. Unsupported
guards fail rather than silently generating expectations for different logic.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'repo_source/LORE_1993_src/LORESPEC.PAS'
OUTPUT = ROOT / 'test/fixtures/map25_guardian_parity.json'


def extract(source):
    match = re.search(r'if y = 43 then begin(.*?)\s+if on\(15,34\)', source, re.S)
    if match is None:
        raise ValueError('Map 25 guardian boundary moved')
    branch = match.group(1)

    def require(pattern):
        result = re.search(pattern, branch, re.S | re.I)
        if result is None:
            raise ValueError(f'Unsupported map 25 source: {pattern}')
        return result

    torch = require(r'if party\.etc\[(\d+)\] = 0 then begin\s*party\.etc\[\1\] := (\d+);')
    army = require(r'enemynumber := (\d+);\s*for i := (\d+) to (\d+) do joinenemy\(i,(\d+)\);\s*joinenemy\((\d+),(\d+)\);')
    battle = require(r'battlemode\((TRUE|FALSE)\);\s*if party\.etc\[6\] = 255 then exit;\s*if party\.etc\[6\] > 0 then begin\s*inc\(y\);\s*scroll\(TRUE\);\s*exit;\s*end;')
    corridor = require(r'for i := (\d+) to (\d+) do map\[i,y\] := (\d+);')
    guides = require(r'enemynumber := (\d+);\s*joinenemy\(1,(\d+)\);\s*joinenemy\(2,(\d+)\);')
    promotion = require(r"talk\(''\);\s*for i := (\d+) to (\d+) do\s*if player\[i\]\.name <> '' then player\[i\]\.class := (\d+);")
    if re.search(r'\brandom\s*\(', branch, re.I):
        raise ValueError('Guardian replay has no random-call model')
    if int(army[1]) != int(army[5]) or (int(army[2]), int(army[3])) != (1, int(army[1]) - 1):
        raise ValueError('Unsupported enemy slot layout')
    if int(guides[1]) != 2:
        raise ValueError('Unsupported guide roster')

    printed = re.findall(r"Print\(\d+,'((?:''|[^'])*)'\s*(?:\+\s*player\[(\d+)\]\.name)?\);", branch)
    if len(printed) != 16 or printed[6][1] != '1' or any(slot for _, slot in printed[:6] + printed[7:]):
        raise ValueError('Unsupported guardian dialogue layout')
    lines = [text.replace("''", "'") for text, _ in printed]
    return {
        'source': 'LORESPEC.PAS',
        'scope': 'map25 y43; presentation delays adapted; portal excluded',
        'torchSlot': int(torch[1]), 'torchValue': int(torch[2]),
        'battleMonsters': [int(army[4])] * (int(army[3]) - int(army[2]) + 1) + [int(army[6])],
        'enemyFirst': battle[1].upper() == 'FALSE',
        'introActors': [int(army[6])],
        'introLines': lines[:4], 'victoryLines': lines[4:6],
        'guideActors': [int(guides[2]), int(guides[3])],
        'guideLines': lines[6:], 'greetingSlot': int(printed[6][1]),
        'corridorWrites': [[x, 43, int(corridor[3])] for x in range(int(corridor[1]), int(corridor[2]) + 1)],
        'promotionSlots': list(range(int(promotion[1]), int(promotion[2]) + 1)),
        'promotionClass': int(promotion[3]), 'randomCalls': 0,
    }


def replay(contract, torch, result):
    return {
        'torch': torch, 'battleResult': result,
        'afterTorch': torch if torch else contract['torchValue'],
        'nudge': [0, 1] if 0 < result < 255 else [0, 0],
        'writes': contract['corridorWrites'] if result == 0 else [],
        'guideActors': contract['guideActors'] if result == 0 else [],
        'promotionClass': contract['promotionClass'] if result == 0 else None,
        'exit': result != 0,
    }


def fixture():
    raw = SOURCE.read_bytes()
    contract = extract(raw.decode('johab'))
    contract['sourceSha256'] = hashlib.sha256(raw).hexdigest()
    contract['cases'] = [replay(contract, torch, result)
                         for torch in (0, 1, 255) for result in (0, 1, 254, 255)]
    return contract


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    data = fixture()
    if args.check:
        if json.loads(OUTPUT.read_text(encoding='utf-8')) != data:
            raise SystemExit('Map 25 guardian fixture has drifted')
    else:
        OUTPUT.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()

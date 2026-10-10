"""Narrow source recognizer for the closed map 26 arm and map 25 boundaries.

This extracts guards and literals; it is not a general Pascal interpreter or
a DOS execution trace. BGI frames and End_Demo internals are outside this scope.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'test/fixtures/map26_final_parity.json'


def extract(spec, entry):
    match = re.search(r'\n\s*26 : begin(.*?)\n\s*27 : if wantexit', spec, re.S)
    if match is None:
        raise ValueError('Map 26 arm boundary changed')
    branch = match[1]

    def require(pattern, text=branch):
        found = re.search(pattern, text, re.S | re.I)
        if found is None:
            raise ValueError(f'Unsupported source: {pattern}')
        return found

    movement = require(r'face := 5;\s*delay\(1500\);\s*for i := 1 to (\d+) do begin\s*dec\(y\);.*?face := 6;\s*while x < (\d+) do begin\s*inc\(x\);.*?face := 5;')
    roster = require(r'enemynumber := (\d+);\s*for i := 1 to enemynumber do joinenemy\(i,(\d+)\+i\);')
    require(r'aux := FALSE;\s*repeat\s*displayenemies\(TRUE\);\s*battlemode\(FALSE\);\s*if party\.etc\[6\] = 255 then exit;\s*if \(party\.etc\[6\] > 0\) and \(not enemy\[7\]\.dead\) then begin')
    require(r'PressAnyKey;\s*end\s*else aux := TRUE;\s*until aux;')
    require(r"talk\(''\);\s*End_Demo;\s*end;")
    if re.search(r'\brandom\s*\(', branch, re.I):
        raise ValueError('No final battle random-call model')
    printed = re.findall(r"Print\(13,'([^']*)'\);", branch)
    if len(printed) != 30:
        raise ValueError('Final dialogue layout changed')
    require(r'if y = 46 then begin\s*if wantexit then begin\s*with party do begin\s*xaxis := 25; yaxis := 45; map := 23;.*?else begin\s*dec\(y\); scroll\(TRUE\);', spec)
    require(r"25 : if wantenter\('CHAMBER OF NECROMANCER'\) then begin\s*party\.etc\[1\] := 1;", entry)
    require(r'enemynumber := 6;\s*for i := 1 to 5 do joinenemy\(i,63\);\s*joinenemy\(6,72\);\s*displayenemies\(TRUE\);\s*battlemode\(TRUE\);\s*if party\.etc\[6\] = 255 then exit;\s*if party\.etc\[6\] > 0 then begin\s*x := 25; y := 45;.*?map := 26; xaxis := 25; yaxis := 15;', entry)
    return {
        'scope': 'LORESPEC:2104-2201; map25 exit/entry boundaries; BGI and End_Demo internals excluded',
        'northSteps': int(movement[1]), 'eastUntilX': int(movement[2]),
        'faces': [5, 6, 5],
        'monsters': [int(roster[2]) + i for i in range(1, int(roster[1]) + 1)],
        'enemyFirst': True, 'introLines': printed[:11],
        'retryLines': printed[11:13], 'farewellLines': printed[13:],
        'keyEnemySlot': 7, 'randomCalls': 0,
        'entryMonsters': [63] * 5 + [72], 'entryEnemyFirst': False,
        'entryTorch': 1, 'entryDestination': [26, 25, 15],
        'escapeDestination': [25, 25, 45], 'exitDestination': [23, 25, 45],
    }


def final_path(result, key_dead):
    if result == 255:
        return 'exit'
    if result > 0 and not key_dead:
        return 'retry'
    return 'farewell'


def fixture():
    raw = {name: (ROOT / 'repo_source/LORE_1993_src' / name).read_bytes()
           for name in ('LORESPEC.PAS', 'LOREENT.PAS')}
    data = extract(*(raw[name].decode('johab') for name in raw))
    data['sourceSha256'] = {name: hashlib.sha256(value).hexdigest() for name, value in raw.items()}
    data['movements'] = [{'start': [x, 15], 'end': [max(x, data['eastUntilX']), 15 - data['northSteps']]}
                         for x in (24, 25, 26, 27)]
    data['results'] = [{'result': result, 'keyDead': dead, 'path': final_path(result, dead)}
                       for result in (0, 1, 2, 254, 255) for dead in (False, True)]
    return data


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    data = fixture()
    if args.check:
        if json.loads(OUTPUT.read_text(encoding='utf-8')) != data:
            raise SystemExit('Map 26 fixture has drifted')
    else:
        OUTPUT.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()

"""Extract the closed LORESPEC `case 23` (KEEP3) branches for independent replay.

This is a narrow source recognizer, not a Pascal interpreter. Unsupported
guards fail rather than silently generating expectations for different logic.
The `y = 46` wantexit boundary is recorded but replayed by the portal tests.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'repo_source/LORE_1993_src/LORESPEC.PAS'
OUTPUT = ROOT / 'test/fixtures/map23_keep3_parity.json'

PRINT = re.compile(
    r"Print\((\d+),'((?:''|[^'])*)'"
    r"(?:\+player\[(\d+)\]\.name\+'((?:''|[^'])*)')?\);")


def text(raw):
    return raw.replace("''", "'")


def extract(source):
    match = re.search(r'\n\s+23 : begin(.*?)\n\s+24 : begin', source, re.S)
    if match is None:
        raise ValueError('Map 23 branch boundary moved')
    case = match.group(1)

    def require(pattern, scope):
        result = re.search(pattern, scope, re.S | re.I)
        if result is None:
            raise ValueError(f'Unsupported map 23 source: {pattern}')
        return result

    if not re.match(r'\s*if map\[x,y\] = 0 then exit;\s*Clear;', case):
        raise ValueError('Unsupported map 23 source: tile guard')
    if re.search(r'\brandom\s*\(', case, re.I):
        raise ValueError('Map 23 replay has no random-call model')
    exit_ = require(
        r'if y = 46 then begin\s*if wantexit then begin\s*with party do begin\s*'
        r'xaxis := (\d+); yaxis := (\d+); map := (\d+);\s*end;\s*load;\s*scroll\(TRUE\);\s*end\s*'
        r'else begin\s*dec\(y\); scroll\(TRUE\);\s*end;\s*end;', case)
    split = require(r'if y = 26 then begin(.*?)\n\s+end;\s*if on\((\d+),(\d+)\) then begin(.*?)\n\s+end;\s*$', case)
    impostor, lever_x, lever_y, lever = split[1], int(split[2]), int(split[3]), split[4]

    disguise = require(
        r'enemynumber := 1;\s*joinenemy\(1,(\d+)\);\s*with enemy\[1\] do begin\s*'
        r"name := '([^']*)';\s*E_number := (\d+);\s*end;", impostor)
    if len(re.findall(r'joinenemy\(1,\d+\);', impostor)) != 2:
        raise ValueError('Unsupported map 23 source: impostor roster')
    mirror = require(
        r"enemynumber := (\d+);\s*for i := 1 to \1 do begin\s*"
        r"if player\[i\]\.name = '' then joinenemy\(i,(\d+)\)\s*else turn_mind\(i,i\);\s*"
        r'enemy\[i\]\.E_number := (\d+);\s*end;', impostor)
    loop = require(
        r'aux := FALSE;\s*repeat\s*displayenemies\(TRUE\);\s*battlemode\((TRUE|FALSE)\);\s*'
        r'if party\.etc\[6\] = 255 then exit;\s*if party\.etc\[6\] > 0 then begin\s*Clear;\s*'
        r"Print\(\d+,'[^']*'\);\s*PressAnyKey;\s*end\s*else aux := TRUE;\s*until aux;", impostor)
    duel = require(
        r'battlemode\((TRUE|FALSE)\);\s*if party\.etc\[6\] = 255 then exit;\s*'
        r'if party\.etc\[6\] > 0 then begin\s*inc\(y\);\s*scroll\(TRUE\);\s*exit;\s*end;', impostor)
    victory_writes = require(
        r'map\[(\d+),(\d+)\] := (\d+);\s*for j := (\d+) to (\d+) do\s*for i := (\d+) to (\d+) do '
        r'map\[i,j\] := (\d+);\s*PressAnyKey;\s*scroll\(TRUE\);', impostor)
    if impostor.count('PressAnyKey;') != 6:
        raise ValueError('Unsupported map 23 source: acknowledgement layout')

    prints = PRINT.findall(impostor)
    if len(prints) != 20 or prints[0][2] != '1' or any(p[2] for p in prints[1:]):
        raise ValueError('Unsupported impostor dialogue layout')
    lines = [text(p[1]) for p in prints]
    greeting_suffix = text(prints[0][3])

    lever_writes = require(
        r'map\[(\d+),(\d+)\] := (\d+);\s*map\[(\d+),(\d+)\] := (\d+);\s*'
        r'for j := (\d+) to (\d+) do\s*for i := (\d+) to (\d+) do\s*'
        r'if map\[i,j\] = (\d+) then map\[i,j\] := (\d+);\s*'
        r'for i := (\d+) to (\d+) do map\[i,(\d+)\] := (\d+);', lever)
    lever_prints = PRINT.findall(lever)
    if len(lever_prints) != 3 or any(p[2] for p in lever_prints):
        raise ValueError('Unsupported lever dialogue layout')
    if lever.count('PressAnyKey;') != 1:
        raise ValueError('Unsupported map 23 source: lever acknowledgement')

    def ints(result, *indexes):
        return [int(result[index]) for index in indexes]

    if int(disguise[1]) != 70 or int(mirror[2]) != 60:
        raise ValueError('Unsupported map 23 enemy numbers')
    return {
        'source': 'LORESPEC.PAS',
        'scope': 'map23 y26 impostor and (25,27) lever; presentation adapted; y46 exit recorded',
        'tileGuard': 0, 'exit': {
            'targetMap': int(exit_[3]), 'targetX': int(exit_[1]), 'targetY': int(exit_[2]),
            'rejectDy': -1},
        'impostorMonster': int(disguise[1]), 'impostorName': disguise[2],
        'impostorENumber': int(disguise[3]),
        'mirrorCount': int(mirror[1]), 'mirrorEmptySlotMonster': int(mirror[2]),
        'mirrorENumber': int(mirror[3]),
        'mirrorEnemyFirst': loop[1].upper() == 'FALSE',
        'duelEnemyFirst': duel[1].upper() == 'FALSE',
        'greetingSlot': int(prints[0][2]), 'greetingSuffix': greeting_suffix,
        'introLines': lines[:4], 'illusionLines': lines[4:10], 'retryLines': lines[10:11],
        'duelLines': lines[11:13], 'victoryLines': lines[13:18], 'endLines': lines[18:20],
        'escapeDy': 1,
        'victoryWrites': {
            'tile': ints(victory_writes, 1, 2, 3),
            'area': {'x': ints(victory_writes, 6, 7), 'y': ints(victory_writes, 4, 5),
                     'value': int(victory_writes[8])},
        },
        'lever': {
            'x': lever_x, 'y': lever_y,
            'tiles': [ints(lever_writes, 1, 2, 3), ints(lever_writes, 4, 5, 6)],
            'area': {'x': ints(lever_writes, 9, 10), 'y': ints(lever_writes, 7, 8),
                     'onlyIf': int(lever_writes[11]), 'value': int(lever_writes[12])},
            'row': {'x': ints(lever_writes, 13, 14), 'y': int(lever_writes[15]),
                    'value': int(lever_writes[16])},
            'lines': [text(p[1]) for p in lever_prints],
        },
        'clearedFlags': 0, 'randomCalls': 0,
    }


def replay(contract, results):
    """Observable events for successive BattleMode(FALSE) results (etc[6])."""
    events = ['scene:intro', 'scene:illusion']
    results = list(results)
    while True:
        result = results.pop(0)
        events.append(f'battle:mirror:{result}')
        if result == 255:
            return events
        if result > 0:
            events.append('scene:retry')
            continue
        break
    events.extend(['scene:duel', f'battle:duel:{results[0]}'])
    result = results[0]
    if result == 255:
        return events
    if result > 0:
        return events + [f'nudge:0,{contract["escapeDy"]}']
    victory = contract['victoryWrites']
    return events + [
        'scene:victory', 'write:tile:%d,%d=%d' % tuple(victory['tile']),
        'write:area:%d-%d,%d-%d=%d' % (*victory['area']['x'], *victory['area']['y'],
                                       victory['area']['value']),
        'scene:end',
    ]


def load_source():
    """Source bytes and text with LF endings, so CRLF checkouts hash the same."""
    raw = SOURCE.read_bytes().replace(b'\r\n', b'\n')
    return raw, raw.decode('johab')


def fixture():
    raw, source = load_source()
    contract = extract(source)
    contract['sourceSha256'] = hashlib.sha256(raw).hexdigest()
    sequences = [
        [255], [1, 255], [1, 254, 255], [0, 255], [0, 1], [0, 254],
        [1, 0, 255], [1, 0, 1], [1, 1, 0, 0],
    ]
    contract['cases'] = [{'results': results, 'events': replay(contract, results)}
                         for results in sequences]
    return contract


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    data = fixture()
    if args.check:
        if json.loads(OUTPUT.read_text(encoding='utf-8')) != data:
            raise SystemExit('Map 23 KEEP3 fixture has drifted')
    else:
        OUTPUT.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()

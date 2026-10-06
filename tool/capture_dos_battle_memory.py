#!/usr/bin/env python3
"""Read game records from an owned, running DOSBox process; never write RAM.

Locate once at a save checkpoint using its actual 330-byte PLAYER file. Reuse
that locator through play. Host pointers stay in the local locator, never in
committed observations. Linux /proc access is required only for capture.
--check validates preserved bytes and their decoded records, not DOS execution.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import struct

from check_dos_new_game import records, party

ROOT = Path(__file__).resolve().parents[1]
EXE = ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE'
OFFSETS = dict(seed=0x364c, party=0x64ca, players=0x6536,
               enemyCount=0x6f37, enemies=0x6f38)


def enemies(data, count):
    assert len(data) == 245 and 0 <= count <= 7
    result = []
    for i in range(count):
        r = data[i*35:(i+1)*35]
        assert r[1] <= 16
        enemy = dict(eNumber=r[0], name=r[2:2+r[1]].decode('ascii'))
        enemy.update(zip(('strength', 'mentality', 'endurance', 'resistance',
                         'agility', 'accArms', 'accMagic', 'ac', 'special',
                         'castLevel', 'specialCastLevel', 'level'), r[18:30]))
        enemy['hp'] = struct.unpack('<h', r[30:32])[0]
        assert all(v in (0, 1) for v in r[32:35])
        enemy.update(zip(('isPoisoned', 'isUnconscious', 'isDead'),
                         map(bool, r[32:35])))
        result.append(enemy)
    return result


def decode(state):
    result = dict(state)
    result['records'] = records(bytes.fromhex(state['players']))
    result['partyRecord'] = party(bytes.fromhex(state['party']))
    result['enemyRecords'] = enemies(bytes.fromhex(state['enemies']), state['enemyCount'])
    result['sha256'] = {key: hashlib.sha256(bytes.fromhex(state[key])).hexdigest()
                        for key in ('party', 'players', 'enemies')}
    if 'commandsHex' in state:
        raw = bytes.fromhex(state['commandsHex'])
        assert len(raw) == 18
        result['commands'] = [list(raw[i:i+3]) for i in range(0,18,3)]
        result['sha256']['commands'] = hashlib.sha256(raw).hexdigest()
    return result


def locate(pid, player_file):
    pattern = player_file.read_bytes()
    assert len(pattern) == 330
    signature = EXE.read_bytes()[225719:225738]
    found = []
    fd = os.open(f'/proc/{pid}/mem', os.O_RDONLY)
    try:
        for line in Path(f'/proc/{pid}/maps').read_text().splitlines():
            columns = line.split()
            if columns[1][:2] != 'rw' or len(columns) != 5:
                continue
            lo, hi = (int(v, 16) for v in columns[0].split('-'))
            if hi - lo < 0x1000000:
                continue
            data = os.pread(fd, 0x100000, lo)
            at, code = data.find(pattern), data.find(signature)
            if at < 0 or code < 0:
                continue
            assert data.find(pattern, at + 1) == -1
            assert data.find(signature, code + 1) == -1
            found.append(dict(pid=pid, mapping=lo, player=lo+at, random=lo+code))
    finally:
        os.close(fd)
    assert len(found) == 1, 'Need a unique live original player/code match'
    return found[0]


def capture(locator):
    fd = os.open(f"/proc/{locator['pid']}/mem", os.O_RDONLY)
    try:
        assert os.pread(fd, 19, locator['random']) == EXE.read_bytes()[225719:225738]
        ds = locator['player'] - OFFSETS['players']
        def read(name, size):
            value = os.pread(fd, size, ds+OFFSETS[name])
            assert len(value) == size
            return value
        state = dict(seed=struct.unpack('<I', read('seed', 4))[0],
                     party=read('party', 108).hex(), players=read('players', 330).hex(),
                     enemyCount=read('enemyCount', 1)[0], enemies=read('enemies', 245).hex())
        # Capture at an input wait, not during execution; reject torn reads.
        assert state == dict(seed=struct.unpack('<I', read('seed', 4))[0],
                     party=read('party', 108).hex(), players=read('players', 330).hex(),
                     enemyCount=read('enemyCount', 1)[0], enemies=read('enemies', 245).hex())
        commands = os.pread(fd, 18, ds+0x64b8)
        assert len(commands) == 18
        assert commands == os.pread(fd, 18, ds+0x64b8)
        state['commandsHex'] = commands.hex()
        return decode(state)
    finally:
        os.close(fd)


def check():
    f = json.loads((ROOT/'test/fixtures/dos_first_field_battle.json').read_text())
    assert f['executableSha256'] == hashlib.sha256(EXE.read_bytes()).hexdigest()
    assert f['offsets'] == OFFSETS
    for state in (f['initial'], f['encounter'], *f['checkpoints'].values()):
        raw = {k: state[k] for k in ('seed', 'party', 'players', 'enemyCount', 'enemies')}
        assert decode(raw) == state
    departure = json.loads((ROOT/'test/fixtures/dos_new_game.json').read_text())['castleRoute']['departure']
    assert f['initial']['players'] == departure['files']['PLAYER1.DAT']['hex']
    assert f['initial']['party'] == departure['files']['PARTY1.DAT']['hex']
    second = f['secondEncounter']
    for state in (second['initial'], second['encounter'],
                  second['enemyPhaseReadKey'], second['partyCommandWait']):
        raw = {k: state[k] for k in OFFSETS}
        assert decode(raw) == state
    assert second['initial'] == f['checkpoints']['victory']
    assert second['enemyPhaseReadKey'] == second['partyCommandWait']
    x, y = departure['party']['x'], departure['party']['y']
    ground = (ROOT/'repo_source/LORE_1993_runtime/GROUND1.MAP').read_bytes()
    for route in (f, second):
        seed = route['initial']['seed']
        for i, step in enumerate(route['movement']):
            dx, dy = {'Up': (0, -1), 'Down': (0, 1),
                      'Left': (-1, 0), 'Right': (1, 0)}[step['key']]
            x, y = x+dx, y+dy
            assert 4 < x < 97 and 4 < y < 97
            assert 24 <= ground[2+(y-1)*100+x-1] <= 47
            assert step['seedBefore'] == seed
            seed = (seed*0x08088405+1) & 0xffffffff
            if i < len(route['movement'])-1:
                assert (seed >> 16) % 40 != 0
            else:
                assert (seed >> 16) % 40 == 0
                seed = (seed*0x08088405+1) & 0xffffffff
                count = (seed >> 16) % 5 + 1
                ids = []
                for _ in range(count):
                    seed = (seed*0x08088405+1) & 0xffffffff
                    ids.append((seed >> 16) % 10 + 1)
                assert ids == [r['eNumber'] for r in route['encounter']['enemyRecords']]
            assert step['seedAfter'] == seed
        assert seed == route['encounter']['seed']
    continued = json.loads((ROOT/'test/fixtures/dos_second_field_battle.json').read_text())
    assert continued['executableSha256'] == f['executableSha256']
    assert continued['initial'] == second['partyCommandWait']
    for state in (continued['initial'], continued['victory'],
                  *(s[k] for s in continued['rounds'] for k in ('partyPhase','enemyPhase')),
                  *(s[k] for s in continued['rests'] for k in ('wait','afterKey'))):
        assert decode({k:state[k] for k in OFFSETS}) == state
    for previous, rest in zip([continued['victory'], *[r['afterKey'] for r in continued['rests']]], continued['rests']):
        assert rest['wait']['seed'] == previous['seed']
        assert rest['afterKey']['seed'] == (previous['seed']*0x08088405+1)&0xffffffff
        assert rest['wait']['records'] == rest['afterKey']['records']
    observed = continued['completedCommandRead']
    assert observed == decode({k:observed[k] for k in (*OFFSETS,'commandsHex')})
    assert observed['commands'] == continued['rounds'][-1]['completedCommands']
    assert observed['players'] == continued['rests'][-1]['afterKey']['players']
    check_resumed()
    print('Original live DOS battles, recovery bytes and route RNG: verified')


def check_resumed():
    """Validate independent reload observations and a normal native disk save."""
    f = json.loads((ROOT/'test/fixtures/dos_resumed_field_battle.json').read_text())
    assert f['executableSha256'] == hashlib.sha256(EXE.read_bytes()).hexdigest()
    assert f['offsets'] == OFFSETS
    states = [f[k] for k in ('initial', 'encounter', 'enemyFirst', 'victory',
                             'selectionRead', 'firstExecutionRead')]
    states += [r[k] for r in f['rounds'] for k in ('partyPhase', 'enemyPhase')]
    states += [f['save'][k] for k in ('wait', 'afterKey')]
    for state in states:
        keys = (*OFFSETS, *(['commandsHex'] if 'commandsHex' in state else []))
        assert decode({k: state[k] for k in keys}) == state
    departure = json.loads((ROOT/'test/fixtures/dos_new_game.json').read_text())['castleRoute']['departure']
    assert f['initial']['players'] == departure['files']['PLAYER1.DAT']['hex']
    assert f['initial']['party'] == departure['files']['PARTY1.DAT']['hex']
    seed = f['initial']['seed']
    x, y = departure['party']['x'], departure['party']['y']
    ground = (ROOT/'repo_source/LORE_1993_runtime/GROUND1.MAP').read_bytes()
    for i, step in enumerate(f['movement']):
        dx, dy = {'Up': (0,-1), 'Down': (0,1), 'Left': (-1,0), 'Right': (1,0)}[step['key']]
        x, y = x+dx, y+dy
        assert 4 < x < 97 and 4 < y < 97
        assert 24 <= ground[2+(y-1)*100+x-1] <= 47
        assert step['seedBefore'] == seed
        seed = (seed*0x08088405+1) & 0xffffffff
        if i < len(f['movement'])-1:
            assert (seed >> 16) % 40 != 0
        else:
            assert (seed >> 16) % 40 == 0
            seed = (seed*0x08088405+1) & 0xffffffff
            count = (seed >> 16) % 5 + 1
            ids = []
            for _ in range(count):
                seed = (seed*0x08088405+1) & 0xffffffff
                ids.append((seed >> 16) % 10 + 1)
            assert ids == [r['eNumber'] for r in f['encounter']['enemyRecords']]
        assert step['seedAfter'] == seed
    assert seed == f['encounter']['seed']
    for r in f['rounds']:
        assert r['partyPhase']['commands'] == r['completedCommands']
    saved = f['save']
    for value in saved['files'].values():
        raw = bytes.fromhex(value['hex'])
        assert len(raw) == value['length']
        assert hashlib.sha256(raw).hexdigest() == value['sha256']
    assert records(bytes.fromhex(saved['files']['PLAYER1.DAT']['hex'])) == saved['records']
    assert party(bytes.fromhex(saved['files']['PARTY1.DAT']['hex'])) == saved['partyRecord']
    assert saved['files']['PLAYER1.DAT']['hex'] == f['victory']['players']
    assert saved['files']['PARTY1.DAT']['hex'] == saved['wait']['party']
    assert saved['files']['SAVE1.MAP']['hex'] == ground.hex()
    assert saved['partyRecord'] == dict(f['victory']['partyRecord'], x=x, y=y)
    assert saved['wait']['seed'] == f['victory']['seed']
    assert saved['afterKey']['seed'] == (saved['wait']['seed']*0x08088405+1)&0xffffffff
    assert saved['afterKey']['players'] == saved['wait']['players']


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--pid', type=int)
    parser.add_argument('--players', type=Path)
    parser.add_argument('--locator', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    if args.check:
        check()
    elif args.pid and args.players and args.locator:
        args.locator.write_text(json.dumps(locate(args.pid, args.players))+'\n')
    elif args.locator and args.output:
        args.output.write_text(json.dumps(capture(json.loads(args.locator.read_text())),
                                         ensure_ascii=False, indent=2)+'\n')
    else:
        parser.error('Use --check, --pid/--players/--locator, or --locator/--output')

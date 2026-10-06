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
    check_menace_entry()
    check_menace_center()
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


def check_menace_entry():
    """Connect native recovery, source menus, two map payloads and gold saves."""
    f = json.loads((ROOT/'test/fixtures/dos_menace_entry.json').read_text())
    assert f['executableSha256'] == hashlib.sha256(EXE.read_bytes()).hexdigest()
    states = [f['initial'], f['goldCollected'], *f['portal'].values(),
              f['goldRevisit']['left'], f['goldRevisit']['returned']]
    states += [r[k] for r in f['rests'] for k in ('wait', 'afterKey')]
    states += [f['difficulty'][k] for k in ('before', 'maxEnemySelected', 'after')]
    states += [f['goldDifficulty'][k] for k in ('before', 'after')]
    states += [f[k][s] for k in ('approachSave', 'insideSave', 'goldSave')
               for s in ('wait', 'afterKey')]
    for state in states:
        assert decode({k: state[k] for k in (*OFFSETS, 'commandsHex')}) == state
    previous = json.loads((ROOT/'test/fixtures/dos_resumed_field_battle.json').read_text())['save']
    assert f['initial']['players'] == previous['files']['PLAYER1.DAT']['hex']
    assert f['initial']['party'] == previous['files']['PARTY1.DAT']['hex']
    seed = f['initial']['seed']
    for rest in f['rests']:
        assert rest['wait']['seed'] == seed
        seed = (seed*0x08088405+1) & 0xffffffff
        assert rest['afterKey']['seed'] == seed
        assert rest['wait']['players'] == rest['afterKey']['players']
    for name in ('difficulty', 'goldDifficulty'):
        d = f[name]
        assert d['after']['seed'] == (d['before']['seed']*0x08088405+1)&0xffffffff
        assert d['after']['partyRecord']['etc'][6:8] == [5,3]
        assert d['after']['players'] == d['before']['players']
    for slot, key, mapname in ((1,'approachSave','GROUND1'), (2,'insideSave','DEN1'),
                                (3,'goldSave','DEN1')):
        saved = f[key]
        files = saved['files']
        for value in files.values():
            raw = bytes.fromhex(value['hex'])
            assert len(raw) == value['length']
            assert hashlib.sha256(raw).hexdigest() == value['sha256']
        assert party(bytes.fromhex(files[f'PARTY{slot}.DAT']['hex'])) == saved['partyRecord']
        assert records(bytes.fromhex(files[f'PLAYER{slot}.DAT']['hex'])) == saved['records']
        assert files[f'PARTY{slot}.DAT']['hex'] == saved['wait']['party']
        assert files[f'PLAYER{slot}.DAT']['hex'] == saved['wait']['players']
        assert bytes.fromhex(files[f'SAVE{slot}.MAP']['hex']) == (EXE.parent/f'{mapname}.MAP').read_bytes()
    for moves, start, mapname, final, no_last_draw in (
        (f['movement'], f['difficulty']['after'], 'GROUND1', f['approachSave'], False),
        (f['goldMovement'], f['goldDifficulty']['after'], 'DEN1', f['goldSave'], True),
    ):
        raw = (EXE.parent/f'{mapname}.MAP').read_bytes()
        width, height = raw[:2]
        x, y = start['partyRecord']['x'], start['partyRecord']['y']
        seed = start['seed']
        for i, step in enumerate(moves):
            dx, dy = {'Up':(0,-1),'Down':(0,1),'Left':(-1,0),'Right':(1,0)}[step['key']]
            x, y = x+dx, y+dy
            assert 4 < x < width-3 and 4 < y < height-3
            tile = raw[2+(y-1)*width+x-1]
            assert step['seedBefore'] == seed
            if no_last_draw and i == len(moves)-1:
                assert tile == 0
            else:
                assert (24 if mapname == 'GROUND1' else 41) <= tile <= 47
                seed = (seed*0x08088405+1)&0xffffffff
                assert (seed >> 16) % 100 != 0
            assert step['seedAfter'] == seed
        assert (x,y) == (final['partyRecord']['x'],final['partyRecord']['y'])
        assert seed == final['wait']['seed']
    portal = f['portal']
    assert portal['request']['seed'] == portal['decline']['seed'] == portal['escape']['seed']
    assert portal['entered']['seed'] == (portal['request']['seed']*0x08088405+1)&0xffffffff
    assert portal['entered']['partyRecord'] == f['insideSave']['partyRecord']
    assert portal['entered']['partyRecord']['etc'][6:8] == [2,3]
    for key in ('approachSave', 'insideSave'):
        saved = f[key]
        assert saved['afterKey']['seed'] == (saved['wait']['seed']*0x08088405+1)&0xffffffff
    gold = f['goldSave']
    assert gold['partyRecord']['gold'] == f['insideSave']['partyRecord']['gold']+400
    assert gold['partyRecord']['etc'][31] == 4
    assert gold['afterKey']['seed'] == gold['wait']['seed']
    assert f['goldRevisit']['left']['seed'] == (gold['afterKey']['seed']*0x08088405+1)&0xffffffff
    assert f['goldRevisit']['returned']['seed'] == f['goldRevisit']['left']['seed']
    assert f['goldRevisit']['returned']['partyRecord']['gold'] == gold['partyRecord']['gold']


def check_menace_center():
    """Validate native path/bytes and Main's shared last-key Esc boundary."""
    f = json.loads((ROOT/'test/fixtures/dos_menace_center.json').read_text())
    assert f['executableSha256'] == hashlib.sha256(EXE.read_bytes()).hexdigest()
    previous = json.loads((ROOT/'test/fixtures/dos_menace_entry.json').read_text())
    assert f['initial'] == previous['goldRevisit']['returned']
    def states(value):
        if isinstance(value, dict):
            if all(k in value for k in OFFSETS):
                assert decode({k:value[k] for k in (*OFFSETS,'commandsHex')}) == value
            else:
                for child in value.values(): states(child)
        elif isinstance(value, list):
            for child in value: states(child)
    states(f)
    raw = (EXE.parent/'DEN1.MAP').read_bytes()
    width,height = raw[:2]
    def tile(x,y):
        assert 4<x<width-3 and 4<y<height-3
        return raw[2+(y-1)*width+x-1]
    def next_seed(seed): return (seed*0x08088405+1)&0xffffffff
    x,y=6,44
    seed=f['initial']['seed']
    for i,step in enumerate(f['movement']):
        dx,dy={'Up':(0,-1),'Down':(0,1),'Left':(-1,0),'Right':(1,0)}[step['key']]
        x,y=x+dx,y+dy
        assert 41<=tile(x,y)<=47
        assert step['seedBefore']==seed
        seed=next_seed(seed)
        if i==len(f['movement'])-1:
            assert (seed>>16)%100==0
            seed=next_seed(seed)
            count=(seed>>16)%3+1
            ids=[]
            for _ in range(count):
                seed=next_seed(seed);ids.append((seed>>16)%8+5)
            assert ids==[r['eNumber'] for r in f['encounter']['enemyRecords']]==[10,12,10]
        else: assert (seed>>16)%100!=0
        assert step['seedAfter']==seed
    assert (x,y)==(16,39)
    assert seed==f['encounter']['seed']
    assert f['enemyFirst']['partyRecord']['etc'][5]==1
    assert f['runAway']['wait']['partyRecord']['etc'][5]==2
    assert f['runAway']['afterKey']==f['runAway']['wait']
    seed=f['runAway']['afterKey']['seed']
    for i,step in enumerate(f['centerMovement']):
        dx,dy={'Up':(0,-1),'Down':(0,1),'Left':(-1,0),'Right':(1,0)}[step['key']]
        x,y=x+dx,y+dy
        assert step['seedBefore']==seed
        if i==len(f['centerMovement'])-1: assert tile(x,y)==0
        else:
            assert 41<=tile(x,y)<=47
            seed=next_seed(seed)
            assert (seed>>16)%100!=0
        assert step['seedAfter']==seed
    assert (x,y)==tuple(f['center']['position'])==(25,8)
    center=f['center']
    assert center['wait']['seed']==center['afterKey']['seed']==seed
    assert center['wait']['partyRecord']['etc'][9]==3
    assert center['afterKey']['partyRecord']['etc'][9]==4
    assert center['wait']['players']==center['afterKey']['players']
    d=f['menuDetour']
    assert d['maxEscape']['partyRecord']['etc'][6:8]==[5,5]
    assert d['frequencySelected']['partyRecord']['etc'][6:8]==[1,5]
    assert d['maxEscape']['seed']==d['frequencySelected']['seed']==seed
    for key in d['keys']:
        assert key=='Down'
        y+=1
        assert 41<=tile(x,y)<=47
        seed=next_seed(seed)
        assert (seed>>16)%20!=0
    assert (x,y)==(25,11)
    assert d['afterMovement']['seed']==seed
    assert f['saveCancel']['wait']==f['saveCancel']['afterEscape']
    assert f['saveCancel']['afterEscape']['seed']==seed
    difficulty=f['restoreDifficulty']
    assert difficulty['before']['seed']==seed
    assert difficulty['maxSelected']['partyRecord']['etc'][6:8]==[1,3]
    seed=next_seed(seed)
    assert difficulty['after']['seed']==seed
    assert difficulty['after']['partyRecord']['etc'][6:8]==[5,3]
    assert f['optionCancel']['before']==f['optionCancel']['afterEscape']
    assert f['optionCancel']['afterEscape']['seed']==seed
    for rest in f['rests']:
        assert rest['wait']['seed']==seed
        assert rest['wait']['partyRecord']['food']==0
        if not rest['escape']: seed=next_seed(seed)
        assert rest['afterKey']['seed']==seed
        assert rest['afterKey']['players']==rest['wait']['players']
    for key,state in zip(f['revisit']['keys'],f['revisit']['states']):
        assert key=='Up'
        y-=1
        if tile(x,y)!=0:
            seed=next_seed(seed)
            assert (seed>>16)%100!=0
        assert state['seed']==seed
        assert state['partyRecord']['etc'][9]==4
        assert state['players']==f['runAway']['afterKey']['players']
    assert (x,y)==(25,8)
    # party.x/y intentionally remain stale: this run ended before an actual Save.
    assert f['revisit']['states'][-1]['partyRecord']['x']==6
    assert f['revisit']['states'][-1]['partyRecord']['y']==44


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

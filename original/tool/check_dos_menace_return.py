#!/usr/bin/env python3
"""Validate preserved original checkpoint/return bytes, not replay DOS itself.

LORESUB.PAS Load/Save; LOREMAIN.PAS Move_Mode; LOREBATT.PAS EncounterEnemy;
LORESPEC.PAS MENACE centre; LORETALK.PAS Lord Ahn stages4..6.
The new journey's combat key/RAM captures are retained, but this checker does
not claim a full new battle replay or a complete new-game-to-ending comparison.
"""
import hashlib
import json
from pathlib import Path

from capture_dos_battle_memory import decode
from check_dos_new_game import party, records

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / 'test/fixtures/dos_menace_return.json'


def next_seed(seed):
    return (seed * 0x08088405 + 1) & 0xffffffff


def check_state(state):
    raw = {k: state[k] for k in ('seed', 'party', 'players', 'enemyCount',
                                'enemies', 'commandsHex')}
    decoded = decode(raw)
    for key in ('records', 'partyRecord', 'enemyRecords', 'sha256', 'commands'):
        if key in state:
            assert state[key] == decoded[key], key
    return decoded


def check_save(saved, slot):
    files = saved['files']
    for name, f in files.items():
        raw = bytes.fromhex(f['hex'])
        assert len(raw) == f['length'], name
        assert hashlib.sha256(raw).hexdigest() == f['sha256'], name
    assert party(bytes.fromhex(files[f'PARTY{slot}.DAT']['hex'])) == saved['partyRecord']
    assert records(bytes.fromhex(files[f'PLAYER{slot}.DAT']['hex'])) == saved['records']
    m = bytes.fromhex(files[f'SAVE{slot}.MAP']['hex'])
    assert len(m) == 2 + m[0] * m[1]
    return files


def check():
    f = json.loads(FIXTURE.read_text())
    original = ROOT / 'repo_source/LORE_1993_runtime'
    assert hashlib.sha256((original / 'LORE.EXE').read_bytes()).hexdigest() == f['executableSha256']
    old = json.loads((ROOT / 'test/fixtures/dos_menace_entry.json').read_text())['goldSave']
    initial = check_state(f['goldRestart'])
    assert initial['players'] == old['files']['PLAYER3.DAT']['hex']
    loaded = bytearray.fromhex(old['files']['PARTY3.DAT']['hex'])
    loaded[8 + 6] = 2  # Load normalizes frequency5, preserving every other byte.
    assert initial['party'] == loaded.hex()
    center = check_save(f['centerSave'], 2)
    assert f['centerSave']['partyRecord']['etc'][9] == 4
    assert (f['centerSave']['partyRecord']['x'], f['centerSave']['partyRecord']['y']) == (25, 8)
    assert bytes.fromhex(center['SAVE2.MAP']['hex']) == (original / 'DEN1.MAP').read_bytes()
    reload = f['centerReload']
    for i in reload['inputs']:
        check_state(i['before']); check_state(i['after'])
    states = [i['after'] for i in reload['inputs']]
    loaded = bytearray.fromhex(center['PARTY2.DAT']['hex'])
    loaded[8 + 6] = 2
    assert states[0]['party'] == loaded.hex()
    assert states[0]['players'] == center['PLAYER2.DAT']['hex']
    assert states[1]['seed'] == next_seed(states[0]['seed'])
    assert (states[1]['seed'] >> 16) % 40 != 0
    assert states[2]['seed'] == states[1]['seed']  # Special centre: completed quest stays4.
    for state in states:
        assert state['partyRecord']['etc'][9] == 4
        assert state['players'] == states[0]['players']
    resaved = check_save(reload['save'], 1)
    assert resaved['PLAYER1.DAT'] == center['PLAYER2.DAT']
    assert resaved['SAVE1.MAP'] == center['SAVE2.MAP']
    assert resaved['PARTY1.DAT']['hex'] == loaded.hex()
    castle = check_save(f['castleSave'], 1)
    expected = bytearray((original / 'TOWN1.MAP').read_bytes())
    for x, y, value in ((49,52,47),(50,52,44),(51,52,44),(52,52,44),(53,52,47),
                        (49,53,47),(50,53,44),(51,53,44),(52,53,44),(53,53,45),
                        *((x,88,44) for x in range(49,54))):
        expected[2 + (y - 1) * expected[0] + x - 1] = value
    assert bytes.fromhex(castle['SAVE1.MAP']['hex']) == expected
    for i in f['nativeJourney']['inputs']:
        check_state(i['before']); check_state(i['after'])
    encounters = 0
    for leg in f['nativeJourney']['legs']:
        check_state(leg['initial'])
        route = f['nativeJourney']['routes'][leg['label']]
        map_name = 'GROUND1.MAP' if leg['label'] == 'castle' else 'DEN1.MAP'
        data = (original / map_name).read_bytes()
        positions = []
        x, y = route['start']
        for key in route['keys']:
            dx, dy = {'Up': (0,-1), 'Down': (0,1), 'Left': (-1,0), 'Right': (1,0)}[key]
            x += dx; y += dy
            positions.append((x,y))
        for step in leg['steps']:
            before, after = check_state(step['before']), check_state(step['after'])
            assert step['key'] == route['keys'][step['index']]
            x, y = positions[step['index']]
            tile = data[2 + (y - 1) * data[0] + x - 1]
            seed = before['seed']
            normal = 24 <= tile <= 47 if leg['label'] == 'castle' else 41 <= tile <= 47
            if normal:
                seed = next_seed(seed)
                if (seed >> 16) % (before['partyRecord']['etc'][6] * 20) == 0:
                    encounters += 1
                    seed = next_seed(seed)
                    count = (seed >> 16) % before['partyRecord']['etc'][7] + 1
                    ids = []
                    for _ in range(count):
                        seed = next_seed(seed)
                        ids.append((seed >> 16) % (10 if leg['label'] == 'castle' else 8)
                                   + (1 if leg['label'] == 'castle' else 5))
                    assert ids == [e['eNumber'] for e in after['enemyRecords']]
            assert seed == after['seed']
    assert encounters == 6
    ahn = f['lordAhn']
    seed = ahn['movement']['initial']['seed']
    for step in ahn['movement']['steps']:
        assert step['seedBefore'] == seed
        seed = next_seed(seed)
        assert step['seedAfter'] == seed  # Town encounters return before enemy rolls.
    assert seed == ahn['movement']['after']['seed']
    assert ahn['movement']['initial']['players'] == ahn['movement']['after']['players']
    before = ahn['inputs'][0]['before']
    check_state(before)
    for i in ahn['inputs']:
        a, b = check_state(i['before']), check_state(i['after'])
        assert a['seed'] == b['seed'] == seed
    wait = ahn['inputs'][0]['after']
    assert before['partyRecord']['etc'][9] == 4
    assert wait['partyRecord']['etc'][9] == 5
    for a, b in zip(before['records'], wait['records']):
        expected = dict(a, experience=a['experience'] + 1000)
        assert b == expected  # All six named members, including unconscious ones.
    for i in ahn['inputs']:
        assert i['after']['players'] == wait['players']
    assert ahn['inputs'][2]['after']['partyRecord']['etc'][9] == 5
    for i in ahn['inputs'][3:]:
        assert i['after']['partyRecord']['etc'][9] == 6
    final = check_save(ahn['save'], 1)
    assert final['PLAYER1.DAT']['hex'] == wait['players']
    assert final['SAVE1.MAP'] == castle['SAVE1.MAP']
    assert ahn['save']['partyRecord']['etc'][9] == 6
    assert (ahn['save']['partyRecord']['x'], ahn['save']['partyRecord']['y']) == (51,29)
    for i in ahn['saveInputs']:
        check_state(i['before']); check_state(i['after'])
    assert ahn['saveInputs'][2]['after']['seed'] == seed
    assert ahn['saveInputs'][3]['after']['seed'] == next_seed(seed)
    print('Original MENACE centre disk save/reload and Lord Ahn reward/hint/revisit records: verified')


if __name__ == '__main__':
    check()

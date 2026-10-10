#!/usr/bin/env python3
"""Check preserved original bytes, not rerun DOS or prove the whole campaign.

LORESUB.PAS Grocery/Save, LOREMENU.PAS Rest, LOREENT.PAS LASTDITCH entry,
LOREBATT.PAS EncounterEnemy, LORETALK.PAS Lord request/Polaris.
"""
import hashlib
import json
from pathlib import Path

from check_dos_menace_return import check_save, check_state, next_seed

ROOT = Path(__file__).resolve().parents[1]


def check():
    f = json.loads((ROOT / 'test/fixtures/dos_lastditch_arrival.json').read_text())
    previous = json.loads((ROOT / 'test/fixtures/dos_menace_return.json').read_text())
    original = ROOT / 'repo_source/LORE_1993_runtime'
    assert hashlib.sha256((original / 'LORE.EXE').read_bytes()).hexdigest() == f['executableSha256']
    assert f['walks']['grocery']['initial'] == previous['lordAhn']['saveInputs'][-1]['after']
    for saved in ('readySave', 'arrivalSave', 'polarisSave'):
        check_save(f[saved], 1)
    inputs = {i['capture']: i for i in f['inputs']}
    for i in inputs.values():
        check_state(i['before']); check_state(i['after'])

    def state(number):
        return inputs[f'lore_{number}.png']['after']

    assert (state(110)['partyRecord']['gold'], state(110)['partyRecord']['food']) == (2025, 50)
    assert state(109)['players'] == state(110)['players']
    assert state(109)['seed'] == state(110)['seed']
    for wait, food in zip((111, 113, 115, 117), (46, 43, 41, 40)):
        assert state(wait)['partyRecord']['food'] == food
        assert state(wait)['seed'] == inputs[f'lore_{wait}.png']['before']['seed']
        assert state(wait + 1)['seed'] == next_seed(state(wait)['seed'])
        assert state(wait + 1)['players'] == state(wait)['players']
    assert [r['hp'] for r in state(117)['records']] == [9, 17, 5, 11, 17, 95]
    assert all(r['unconscious'] == 0 for r in state(117)['records'])

    encounters = 0
    for label, leg in f['walks'].items():
        check_state(leg['initial']); check_state(leg['after'])
        if label == 'lord-pagination':
            assert len(leg['steps']) == 1
            before = check_state(leg['steps'][0]['before'])
            after = check_state(leg['steps'][0]['after'])
            assert before['partyRecord']['etc'][12] == 0
            assert after['partyRecord']['etc'][12] == 1
            expected = bytearray.fromhex(before['party']); expected[8 + 12] = 1
            assert after['party'] == expected.hex()
            assert before['seed'] == after['seed']
            assert before['players'] == after['players']
            continue
        route_label = 'ground' if label.startswith('ground') else label
        route = f['routes'][route_label]
        if label in ('grocery', 'exit'):
            data = bytes.fromhex(previous['lordAhn']['save']['files']['SAVE1.MAP']['hex'])
        else:
            data = (original / ('GROUND1.MAP' if label.startswith('ground') else 'TOWN2.MAP')).read_bytes()
        x, y = route['start']; positions = []
        for key in route['keys']:
            dx, dy = {'Up': (0, -1), 'Down': (0, 1), 'Left': (-1, 0), 'Right': (1, 0)}[key]
            x += dx; y += dy; positions.append((x, y))
        last = leg['initial']
        for step in leg['steps']:
            before, after = check_state(step['before']), check_state(step['after'])
            assert before['seed'] == last['seed']
            assert step['key'] == route['keys'][step['index']]
            x, y = positions[step['index']]
            tile = data[2 + (y - 1) * data[0] + x - 1]
            assert (24 if label.startswith('ground') else 27) <= tile <= 47
            seed = next_seed(before['seed'])
            if label.startswith('ground') and (seed >> 16) % 40 == 0:
                encounters += 1
                seed = next_seed(seed); count = (seed >> 16) % 3 + 1
                ids = []
                for _ in range(count):
                    seed = next_seed(seed); ids.append((seed >> 16) % 10 + 1)
                assert ids == [e['eNumber'] for e in after['enemyRecords']]
            assert after['seed'] == seed
            assert after['players'] == before['players']
            last = after
        assert last['seed'] == leg['after']['seed']
    assert encounters == 1
    enemies = f['walks']['ground0']['after']['enemyRecords']
    assert sum(r['luck'] for r in state(127)['records']) // 6 > sum(e['agility'] for e in enemies) // len(enemies)
    assert state(127)['players'] == f['walks']['ground0']['after']['players']
    assert state(127)['seed'] == f['walks']['ground0']['after']['seed']

    assert state(137)['partyRecord']['etc'][12] == 0
    assert state(142)['partyRecord']['etc'][12] == 1
    assert state(137)['players'] == state(142)['players']
    for number in (137, 138, 139, 140, 142, 143, 144):
        assert state(number)['seed'] == state(137)['seed']
    assert state(143)['partyRecord']['etc'][12] == 1
    for number in (146, 147, 148, 149, 150):
        assert state(number)['players'] == state(146)['players']
        assert state(number)['seed'] == state(146)['seed']
    before, after = state(150), state(151)
    assert before['seed'] == after['seed']
    for index in (0, 1, 3, 4, 5):
        assert before['records'][index] == after['records'][index]
    p = after['records'][2]
    assert (p['name'], p['classId'], p['battleLevel'], p['magicLevel'], p['experience']) == ('Polaris', 4, 3, 3, 6000)
    assert (p['hp'], p['sp'], p['weapon'], p['shield'], p['armor'], p['ac']) == (30, 48, 4, 1, 1, 3)
    town = (original / 'TOWN2.MAP').read_bytes()
    assert bytes.fromhex(f['arrivalSave']['files']['SAVE1.MAP']['hex']) == town
    expected = bytearray(town); expected[2 + 40 * expected[0] + 36] = 44
    assert bytes.fromhex(f['polarisSave']['files']['SAVE1.MAP']['hex']) == expected
    for saved, number in (('readySave', 121), ('arrivalSave', 134), ('polarisSave', 154)):
        assert f[saved]['files']['PARTY1.DAT']['hex'] == state(number)['party']
        assert f[saved]['files']['PLAYER1.DAT']['hex'] == state(number)['players']
    assert (f['polarisSave']['partyRecord']['x'], f['polarisSave']['partyRecord']['y']) == (37, 42)
    assert state(155)['seed'] == next_seed(state(154)['seed'])
    p = f['pyramid']
    for saved in ('arrivalSave', 'spearSave'):
        check_save(p[saved], 1)
    observed = {i['capture']: i for i in p['inputs']}
    for i in observed.values():
        check_state(i['before']); check_state(i['after'])

    def phase(number):
        return observed[f'lore_{number}.png']['after']

    movement = p['entryMovement']
    assert movement['initial'] == state(155)
    seed = movement['initial']['seed']
    for step in movement['steps']:
        before, after = check_state(step['before']), check_state(step['after'])
        assert before['seed'] == seed
        seed = next_seed(seed)
        assert after['seed'] == seed
        assert after['players'] == before['players']
    assert movement['after']['seed'] == seed
    assert observed['lore_157.png']['before'] == movement['after']
    for number in (157, 159, 166):
        assert phase(number)['seed'] == observed[f'lore_{number}.png']['before']['seed']
    for number in (158, 160, 161, 162, 163, 164, 165, 167):
        assert phase(number)['seed'] == next_seed(observed[f'lore_{number}.png']['before']['seed'])
    assert phase(167)['partyRecord']['mapId'] == 11
    for number, saved in ((170, 'arrivalSave'), (226, 'spearSave')):
        assert p[saved]['files']['PARTY1.DAT']['hex'] == phase(number)['party']
        assert p[saved]['files']['PLAYER1.DAT']['hex'] == phase(number)['players']
        assert bytes.fromhex(p[saved]['files']['SAVE1.MAP']['hex']) == (original / 'T_DEN1.MAP').read_bytes()
    seed = next_seed(phase(170)['seed'])
    assert (seed >> 16) % 40 == 0
    seed = next_seed(seed); count = (seed >> 16) % 3 + 1
    ids = []
    for _ in range(count):
        seed = next_seed(seed); ids.append((seed >> 16) % 10 + 6)
    assert phase(171)['seed'] == seed
    assert [e['eNumber'] for e in phase(171)['enemyRecords']] == ids == [6]
    assert phase(205)['partyRecord']['etc'][5] == 2
    assert phase(206)['partyRecord']['mapId'] == 7
    assert phase(209)['party'] == p['arrivalSave']['files']['PARTY1.DAT']['hex']
    assert phase(209)['players'] == p['arrivalSave']['files']['PLAYER1.DAT']['hex']
    for number in (210, 211, 212, 213, 215, 216, 217, 218, 220, 221, 222, 223, 226, 227):
        assert phase(number)['seed'] == observed[f'lore_{number}.png']['before']['seed']
    for number in (214, 219):
        assert phase(number)['seed'] == next_seed(observed[f'lore_{number}.png']['before']['seed'])
    for number in (210, 211, 212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222):
        assert phase(number)['players'] == phase(209)['players']
        assert phase(number)['partyRecord']['etc'][32] == 0
    assert phase(223)['partyRecord']['etc'][32] == 128
    for index in (0, 2, 3, 4, 5):
        assert phase(223)['records'][index] == phase(209)['records'][index]
    knight = dict(phase(209)['records'][1]); knight.update(weapon=3, weaPower=18)
    assert phase(223)['records'][1] == knight
    assert (p['spearSave']['partyRecord']['x'], p['spearSave']['partyRecord']['y']) == (25, 44)
    print('Original PYRAMID entry, genuine encounter provenance and closed spear branches: passed')
    print('Original LASTDITCH arrival, recovery, quest/recruit waits and saves: passed')


if __name__ == '__main__':
    check()

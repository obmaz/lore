#!/usr/bin/env python3
"""Check preserved native continuation bytes, not full campaign parity."""
import hashlib
import json
from pathlib import Path

from check_dos_menace_return import check_save, check_state, next_seed

ROOT = Path(__file__).resolve().parents[1]


def check():
    f = json.loads((ROOT / 'test/fixtures/dos_gaia_continuation.json').read_text())
    assert f['executableSha256'] == hashlib.sha256(
        (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()).hexdigest()
    previous = None
    captures = {}
    for block in [*f['trace'], *[b for c in f.get('continuations', []) for b in c['trace']]]:
        if 'walk' in block:
            walk = block['walk']
            before, after = walk['before'], walk['after']
            check_state(before)
            check_state(after)
            seed = before['seed']
            x, y = before['live']['x'], before['live']['y']
            for step in walk['steps']:
                dx, dy = {'Up': (0, -1), 'Down': (0, 1),
                          'Left': (-1, 0), 'Right': (1, 0)}[step['key']]
                x, y = x + dx, y + dy
                seed = next_seed(seed)
                assert (x, y, seed) == (step['x'], step['y'], step['seedAfter'])
            assert (x, y, seed) == (after['live']['x'], after['live']['y'], after['seed'])
            for key in ('party', 'players', 'enemies', 'commandsHex', 'enemyCount'):
                assert before[key] == after[key]
            assert before['live']['mapSha256'] == after['live']['mapSha256']
        else:
            input_ = block['input']
            before, after = input_['before'], input_['after']
            check_state(before)
            check_state(after)
            if input_['capture'] is not None:
                assert input_['capture'] not in captures
                captures[input_['capture']] = input_
        starts = [c['trace'][0] for c in f.get('continuations', [])]
        if block in starts:
            previous = None
        if previous is not None:
            assert before == previous
        previous = after

    def state(n):
        return captures[f'lore_{n:03}.png']['after']

    origin = json.loads((ROOT / 'test/fixtures/dos_pyramid_success.json').read_text())['lordSave']
    initial = next(iter(f['trace'][0].values()))['before']
    assert initial['party'] == origin['files']['PARTY1.DAT']['hex']
    assert initial['players'] == origin['files']['PLAYER1.DAT']['hex']
    restart = next(iter(f['continuations'][0]['trace'][0].values()))['before']
    assert restart['party'] == f['saves']['gaiaRecovered']['files']['PARTY1.DAT']['hex']
    assert restart['players'] == f['saves']['gaiaRecovered']['files']['PLAYER1.DAT']['hex']
    assert [p['battleLevel'] for p in state(437)['records']] == [3, 3, 3, 3, 3, 5]
    seed = state(424)['seed']
    for _ in range(4):
        seed = next_seed(seed)
    assert state(437)['seed'] == seed
    assert state(437)['partyRecord']['gold'] == state(424)['partyRecord']['gold'] - 20
    for tag, n in [('trained', 447), ('valiant', 461), ('gaiaRequest', 583), ('gaiaRecovered', 631), ('evilSealSuccess', 832), ('evilReturn', 913)]:
        saved = check_save(f['saves'][tag], 1)
        assert saved['PARTY1.DAT']['hex'] == state(n)['party']
        assert saved['PLAYER1.DAT']['hex'] == state(n)['players']
        assert state(n)['live']['mapSha256'] == hashlib.sha256(
            bytes.fromhex(saved['SAVE1.MAP']['hex'])[2:]).hexdigest()
    assert state(454)['partyRecord']['mapId'] == 7
    assert state(455)['partyRecord']['mapId'] == 8
    assert state(455)['seed'] == state(454)['seed']
    assert state(571)['partyRecord']['etc'][13] == 0
    assert state(579)['partyRecord']['etc'][13] == 0
    assert state(580)['partyRecord']['etc'][13] == 1
    assert state(571)['records'] == state(580)['records']
    assert state(584)['seed'] == next_seed(state(583)['seed'])
    assert state(585)['records'] == state(586)['records']
    for observed in f['soundChecks']:
        assert observed['beforeSound'] in (0, 1)
        assert observed['afterSound'] == (1 - observed['beforeSound']
                                        if observed['keys'] == ['BackSpace']
                                        else observed['beforeSound'])
        for phase in ('before', 'after'):
            check_state(observed[phase])
    assert hashlib.sha256(bytes.fromhex(f['ramMapBeforeSeal']['hex'])[2:]).hexdigest() == captures['lore_828.png']['before']['live']['mapSha256']
    assert state(828)['partyRecord']['etc'][13] == 2
    assert state(907)['partyRecord']['etc'][13] == 2
    assert state(908)['partyRecord']['etc'][13] == 3
    assert state(910)['partyRecord']['etc'][13] == 4
    before_reward = captures['lore_907.png']['before']
    for before, after in zip(before_reward['records'], state(907)['records']):
        assert after['experience'] == before['experience'] + 10000
        assert {k: v for k, v in after.items() if k != 'experience'} == {k: v for k, v in before.items() if k != 'experience'}
    assert state(913)['seed'] == state(907)['seed']
    assert state(914)['seed'] == next_seed(state(913)['seed'])
    print('Original training, GROUND GATE, GAIA request, saves and SoundOn: verified')


if __name__ == '__main__':
    check()

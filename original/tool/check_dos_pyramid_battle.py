#!/usr/bin/env python3
"""Check preserved original PYRAMID bytes, not rerun DOS or prove campaign parity."""
import hashlib
import json
from pathlib import Path

from check_dos_menace_return import check_state

ROOT = Path(__file__).resolve().parents[1]


def check():
    f = json.loads((ROOT / 'test/fixtures/dos_pyramid_battle.json').read_text())
    original = ROOT / 'repo_source/LORE_1993_runtime'
    assert f['executableSha256'] == hashlib.sha256((original / 'LORE.EXE').read_bytes()).hexdigest()
    saved = json.loads((ROOT / 'test/fixtures/dos_lastditch_arrival.json').read_text())['pyramid']['spearSave']
    map_hash = hashlib.sha256(bytes.fromhex(saved['files']['SAVE1.MAP']['hex'])[2:]).hexdigest()
    by_capture = {}
    previous = None
    for input_ in f['inputs']:
        assert input_['capture'] not in by_capture
        by_capture[input_['capture']] = input_
        for phase in ('before', 'after'):
            state = input_[phase]
            check_state(state)
            assert state['live']['mapSha256'] == map_hash
            assert state['partyRecord']['mapId'] == 11
            assert state['partyRecord']['etc'][12] == 1
        if previous is not None:
            # ctrl-F5 screenshots between inputs consume no gameplay RNG.
            assert input_['before'] == previous
        previous = input_['after']

    def state(n):
        return by_capture[f'lore_{n:03}.png']['after']

    assert state(55)['players'] == saved['files']['PLAYER1.DAT']['hex']
    sphinx, second, mummy = state(56)['enemyRecords']
    assert sphinx == second
    assert (sphinx['eNumber'], sphinx['level'], sphinx['hp'], sphinx['special']) == (20, 4, 18, 0)
    assert (mummy['eNumber'], mummy['name'], mummy['ac'], mummy['hp']) == (26, 'Major Mummy', 1, 70)
    assert state(60)['seed'] == state(64)['seed']
    assert state(60)['records'][0]['unconscious'] == 0
    assert state(64)['records'][0]['unconscious'] == 1
    assert state(78)['commands'][2:] == [[1, 4, 3], [1, 1, 3], [1, 0, 3], [1, 10, 3]]
    assert state(110)['enemyRecords'][2]['hp'] == 0
    assert state(110)['enemyRecords'][2]['isUnconscious']
    assert not state(110)['enemyRecords'][2]['isDead']
    assert all(r['hp'] <= 0 for r in state(118)['records'])
    assert state(118)['partyRecord']['etc'][5] == 1
    loaded = bytearray.fromhex(saved['files']['PARTY1.DAT']['hex'])
    loaded[8 + 5] = 255  # GameOver returns the Load sentinel.
    assert state(121)['party'] == loaded.hex()
    assert state(121)['players'] == saved['files']['PLAYER1.DAT']['hex']
    assert state(121)['seed'] == state(118)['seed']
    assert (state(121)['live']['x'], state(121)['live']['y']) == (25, 44)
    print('Original PYRAMID failed battle, raw records and reload: verified')


if __name__ == '__main__':
    check()

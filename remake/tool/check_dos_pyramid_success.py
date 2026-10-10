#!/usr/bin/env python3
"""Verify preserved native PYRAMID/LASTDITCH observations, not replay DOS."""
import hashlib
import json
from pathlib import Path

from check_dos_menace_return import check_save, check_state, next_seed

ROOT = Path(__file__).resolve().parents[1]


def check():
    f = json.loads((ROOT / 'test/fixtures/dos_pyramid_success.json').read_text())
    assert f['executableSha256'] == hashlib.sha256(
        (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()).hexdigest()
    previous = None
    by_capture = {}
    for input_ in f['inputs']:
        for phase in ('before', 'after'):
            check_state(input_[phase])
        if previous is not None:
            assert input_['before'] == previous
        previous = input_['after']
        if input_['capture'] is not None:
            assert input_['capture'] not in by_capture
            by_capture[input_['capture']] = input_

    def state(n):
        return by_capture[f'lore_{n:03}.png']['after']

    spear = json.loads((ROOT / 'test/fixtures/dos_lastditch_arrival.json').read_text())['pyramid']['spearSave']
    assert state(329)['players'] == spear['files']['PLAYER1.DAT']['hex']
    loaded = bytearray.fromhex(spear['files']['PARTY1.DAT']['hex'])
    loaded[8 + 5] = 255  # Actual GameOver reload sentinel.
    assert state(329)['party'] == loaded.hex()
    seed = state(329)['seed']
    for _ in range(19):
        seed = next_seed(seed)
    assert state(330)['seed'] == seed
    assert (state(330)['live']['x'], state(330)['live']['y']) == (25, 24)
    assert state(339)['records'][0]['unconscious'] == 1
    assert state(335)['records'][0]['unconscious'] == 0  # Internal text wait.
    assert state(351)['commands'][2] == [2, 2, 3]
    mummy = state(367)['enemyRecords'][2]
    assert mummy['hp'] == 0 and mummy['isUnconscious'] and not mummy['isDead']
    assert state(377)['partyRecord']['etc'][5] == 1  # Failed escape.
    assert state(383)['partyRecord']['etc'][5] == 2  # Successful escape.
    assert state(383)['partyRecord']['etc'][12] == 1
    assert state(384)['partyRecord']['etc'][12] == 1  # Quest's PressAnyKey.
    assert state(385)['partyRecord']['etc'][12] == 2
    assert state(383)['seed'] == state(385)['seed']
    saved = check_save(f['successSave'], 1)
    assert saved['PARTY1.DAT']['hex'] == state(388)['party']
    assert saved['PLAYER1.DAT']['hex'] == state(388)['players']
    assert state(389)['partyRecord']['etc'][5] == 0  # Save Space -> SelectMode.
    assert state(389)['live']['menu'][0] != state(388)['live']['menu'][0]
    assert [state(n)['partyRecord']['food'] for n in (392, 396, 399, 401)] == [34, 28, 22, 18]
    assert [p['hp'] for p in state(392)['records'][:5]] == [1] * 5
    assert [p['hp'] for p in state(402)['records']] == [9, 17, 30, 11, 17, 95]
    assert state(413)['partyRecord']['etc'][12] == 2
    assert state(414)['partyRecord']['etc'][12] == 3
    for before, after in zip(state(413)['records'], state(414)['records']):
        expected = dict(before, experience=before['experience'] + 10000)
        assert after == expected
    assert state(414)['records'] == state(418)['records']  # No repeat reward.
    assert state(413)['seed'] == state(418)['seed']
    final = check_save(f['lordSave'], 1)
    assert final['PARTY1.DAT']['hex'] == state(421)['party']
    assert final['PLAYER1.DAT']['hex'] == state(421)['players']
    final_map = bytes.fromhex(final['SAVE1.MAP']['hex'])[2:]
    assert state(413)['live']['mapSha256'] == hashlib.sha256(final_map).hexdigest()
    assert state(422)['seed'] == next_seed(state(421)['seed'])
    print('Original PYRAMID success, Space waits, recovery and LASTDITCH reward: verified')


if __name__ == '__main__':
    check()

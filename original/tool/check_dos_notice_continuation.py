#!/usr/bin/env python3
"""Check native NOTICE observation integrity; bounded Dart replay is separate.

The mage preparation includes an unchanged observed RAM checkpoint. This is
not evidence of a continuous new-game campaign or equal DOS pagination keys.
"""
import hashlib
import json
from pathlib import Path
from check_dos_menace_return import check_save, check_state, next_seed

ROOT = Path(__file__).resolve().parents[1]


def check():
    f = json.loads((ROOT / 'test/fixtures/dos_notice_continuation.json').read_text())
    assert f['executableSha256'] == hashlib.sha256(
        (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()).hexdigest()
    captures = {}
    previous = None
    for block in f['trace']:
        value = next(iter(block.values()))
        before, after = value['before'], value['after']
        check_state(before); check_state(after)
        if previous is not None:
            assert previous == before
        previous = after
        if 'walk' in block:
            seed = before['seed']; x, y = before['live']['x'], before['live']['y']
            for step in value['steps']:
                dx, dy = {'Up': (0, -1), 'Down': (0, 1),
                          'Left': (-1, 0), 'Right': (1, 0)}[step['key']]
                x += dx; y += dy; seed = next_seed(seed)
                assert (x, y, seed) == (step['x'], step['y'], step['seedAfter'])
            assert (x, y, seed) == (after['live']['x'], after['live']['y'], after['seed'])
            for key in ('party', 'players', 'enemies', 'commandsHex', 'enemyCount'):
                assert before[key] == after[key]
            assert before['live']['mapSha256'] == after['live']['mapSha256']
        elif value['capture'] is not None:
            assert value['capture'] not in captures
            captures[value['capture']] = value

    def row(n): return captures[f'lore_{n}.png']
    def state(n): return row(n)['after']
    for tag, n in [('noticeEntry', 6729), ('noticeGate', None),
                   ('antaresJoined', 7215)]:
        saved = check_save(f['saves'][tag], 1)
        # Gate anchor is located by exact actual party/player/map bytes below.
        if tag == 'noticeGate':
            assert any(s['after']['party'] == saved['PARTY1.DAT']['hex'] and
                       s['after']['players'] == saved['PLAYER1.DAT']['hex'] and
                       s['after']['live']['mapSha256'] == hashlib.sha256(
                           bytes.fromhex(saved['SAVE1.MAP']['hex'])[2:]).hexdigest()
                       for s in captures.values())
        else:
            assert saved['PARTY1.DAT']['hex'] == state(n)['party']
            assert saved['PLAYER1.DAT']['hex'] == state(n)['players']
            assert hashlib.sha256(bytes.fromhex(saved['SAVE1.MAP']['hex'])[2:]).hexdigest() == state(n)['live']['mapSha256']
    for tag in ('antaresReady', 'hidraReady', 'hidraSuccess', 'hidraReturn'):
        saved = check_save(f['saves'][tag], 1)
        observation = f['saves'][tag]['observation']
        before = observation['beforeAcknowledgement']
        assert before == captures[observation['capture']]['after']
        assert saved['PARTY1.DAT']['hex'] == before['party']
        assert saved['PLAYER1.DAT']['hex'] == before['players']
        assert hashlib.sha256(bytes.fromhex(saved['SAVE1.MAP']['hex'])[2:]).hexdigest() == before['live']['mapSha256']
        check_state(observation['afterAcknowledgement'])
    m = f['ramMaps']['beforeAntares']
    assert hashlib.sha256(bytes.fromhex(m['hex'])[2:]).hexdigest() == m['sha256']
    assert m['sha256'] == row(7193)['before']['live']['mapSha256']
    for n, flag in [(7193, 0), (7206, 1), (7211, 3)]:
        assert state(n)['partyRecord']['etc'][37] == flag
    assert state(7209)['partyRecord']['etc'][4] == 3
    assert state(7209)['records'][2]['esp'] == row(7209)['before']['records'][2]['esp']
    ghost = state(7211)['records'][3]
    assert (ghost['name'], ghost['classId'], ghost['hp'], ghost['unconscious'],
            ghost['sp'], ghost['esp'], ghost['strength'], ghost['concentration'],
            ghost['battleLevel'], ghost['magicLevel'], ghost['experience']) == (
                'Red Antares', 9, 0, 1, 300, 0, 0, 0, 15, 15, 2700000)
    food = row(7636)
    assert food['after']['partyRecord']['food'] == food['before']['partyRecord']['food'] + 6
    assert food['after']['records'][3]['sp'] == food['before']['records'][3]['sp'] - 30
    assert food['after']['seed'] == next_seed(food['before']['seed'])
    assert food['after']['partyRecord']['etc'][4] == 0
    assert state(9103)['partyRecord']['etc'][14] == 1
    assert state(9103)['partyRecord']['etc'][5] == 0
    assert all(e['isDead'] or e['isUnconscious'] for e in state(9103)['enemyRecords'])
    assert state(9103)['partyRecord']['gold'] == 3581 + 5916
    assert state(9104)['partyRecord']['etc'][14] == 2
    assert (state(9104)['live']['x'], state(9104)['live']['y']) == (56, 93)
    assert state(9104)['seed'] == state(9103)['seed']
    reward = row(9310)
    assert [p['experience'] - q['experience'] for p, q in zip(
        reward['after']['records'], reward['before']['records'])] == [150000] * 6
    assert state(9310)['partyRecord']['etc'][14] == 2
    assert state(9311)['partyRecord']['etc'][14] == 3
    assert state(9311)['seed'] == state(9310)['seed']
    assert state(9315)['seed'] == next_seed(state(9314)['seed'])
    print('Native NOTICE observations, Antares/MindRead/food, HIDRA result, 150k reward and actual saves: verified')


if __name__ == '__main__':
    check()

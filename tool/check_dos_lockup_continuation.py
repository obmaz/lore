#!/usr/bin/env python3
"""Check actual LOCKUP records with explicit animation/restart sampling gaps."""
import hashlib
import json
from pathlib import Path
from check_dos_menace_return import check_save, check_state, next_seed

ROOT = Path(__file__).resolve().parents[1]


def check():
    f = json.loads((ROOT / 'test/fixtures/dos_lockup_continuation.json').read_text())
    assert f['executableSha256'] == hashlib.sha256(
        (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()).hexdigest()
    old = json.loads((ROOT / 'test/fixtures/dos_notice_continuation.json').read_text())
    previous = next(iter(old['trace'][-1].values()))['after']
    captures = {}
    for segment in f['segments']:
        if 'gap' in segment:
            gap = segment['gap']; before, after = gap['before'], gap['after']
            assert previous == before
            check_state(before); check_state(after)
            if gap['kind'] == 'actualSaveProcessRestart':
                saved = f['saves'][gap['sourceCheckpoint']]['files']
                assert after['party'] == saved['PARTY1.DAT']['hex']
                assert after['players'] == saved['PLAYER1.DAT']['hex']
                assert after['live']['mapSha256'] == hashlib.sha256(
                    bytes.fromhex(saved['SAVE1.MAP']['hex'])[2:]).hexdigest()
                assert after['seed'] != before['seed']
            else:
                assert gap['kind'] == 'hugeDragonAnimation'
                assert (before['live']['x'], before['live']['y']) == (35, 12)
                assert (after['live']['x'], after['live']['y']) == (37, 13)
                for key in ('seed', 'party', 'players', 'enemies', 'enemyCount', 'commandsHex'):
                    assert before[key] == after[key]
                assert before['live']['mapSha256'] == after['live']['mapSha256']
            previous = after
            continue
        for block in segment['trace']:
            value = next(iter(block.values())); before, after = value['before'], value['after']
            check_state(before); check_state(after)
            assert previous == before
            previous = after
            if 'walk' in block:
                seed = before['seed']; x, y = before['live']['x'], before['live']['y']
                for step in value['steps']:
                    dx, dy = {'Up': (0, -1), 'Down': (0, 1), 'Left': (-1, 0), 'Right': (1, 0)}[step['key']]
                    x += dx; y += dy; seed = next_seed(seed)
                    assert (x, y, seed) == (step['x'], step['y'], step['seedAfter'])
                assert (x, y, seed) == (after['live']['x'], after['live']['y'], after['seed'])
                for key in ('party', 'players', 'enemies', 'commandsHex', 'enemyCount'):
                    assert before[key] == after[key]
                assert before['live']['mapSha256'] == after['live']['mapSha256']
            elif value['capture'] is not None:
                assert value['capture'] not in captures
                captures[value['capture']] = value
    for saved in f['saves'].values():
        files = check_save(saved, 1); obs = saved['observation']
        before = obs['beforeAcknowledgement']
        assert captures[obs['capture']]['after'] == before
        check_state(obs['afterAcknowledgement'])
        assert files['PARTY1.DAT']['hex'] == before['party']
        assert files['PLAYER1.DAT']['hex'] == before['players']
        assert hashlib.sha256(bytes.fromhex(files['SAVE1.MAP']['hex'])[2:]).hexdigest() == before['live']['mapSha256']
    def row(n): return captures[f'lore_{n}.png']
    def state(n): return row(n)['after']
    assert state(9416)['partyRecord']['etc'][38] == 0
    assert state(9546)['partyRecord']['etc'][38] == 4
    assert state(9546)['partyRecord']['gold'] == state(9416)['partyRecord']['gold'] + 33750
    assert state(9578)['partyRecord']['etc'][38] == 5
    assert state(9581)['partyRecord']['etc'][4] == 3
    assert state(9581)['records'][2]['esp'] == row(9581)['before']['records'][2]['esp']
    assert state(9582)['partyRecord']['etc'][38] == 5
    assert max(p['espLevel'] for p in state(9582)['records']) == 4
    assert state(11260)['partyRecord']['etc'][14] == 4
    assert row(11260)['before']['partyRecord']['etc'][14] == 3
    assert state(11260)['seed'] == row(11260)['before']['seed']
    assert state(11260)['partyRecord']['gold'] == 22 + 41567
    assert all(e['isUnconscious'] or e['isDead'] for e in state(11260)['enemyRecords'])
    reward = row(11511)
    assert [p['experience'] - q['experience'] for p, q in zip(
        reward['after']['records'], reward['before']['records'])] == [300000] * 6
    assert state(11511)['partyRecord']['etc'][14] == 4
    assert state(11512)['partyRecord']['etc'][14] == 5
    assert state(11512)['seed'] == state(11511)['seed']
    assert state(11516)['seed'] == next_seed(state(11515)['seed'])
    print('Native LOCKUP/Minotaur/Spica, explicit restart and animation gaps, Huge Dragon victory and300k reward/saves: verified')


if __name__ == '__main__':
    check()

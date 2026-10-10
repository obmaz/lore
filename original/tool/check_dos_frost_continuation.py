#!/usr/bin/env python3
"""Check native LAVA gateway, Death Knight victory, guards restart and Last Shelter save."""
import hashlib
import json
from pathlib import Path
from check_dos_menace_return import check_save, check_state, next_seed

ROOT = Path(__file__).resolve().parents[1]


def check():
    f = json.loads((ROOT / 'test/fixtures/dos_frost_continuation.json').read_text())
    assert f['executableSha256'] == hashlib.sha256(
        (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()).hexdigest()
    old = json.loads((ROOT / 'test/fixtures/dos_keep2_completion.json').read_text())
    previous = next(iter(old['segments'][-1]['trace'][-1].values()))['after']
    captures = {}
    for segment in f['segments']:
        if 'gap' in segment:
            gap = segment['gap']; assert previous == gap['before']
            check_state(gap['before']); check_state(gap['after'])
            assert gap['before']['players'] == gap['after']['players']
            assert gap['before']['party'] == gap['after']['party']
            assert gap['after']['seed'] == next_seed(gap['before']['seed'])
            previous = gap['after']; continue
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
    saves = f['saves']
    assert saves['firstReady']['partyRecord']['etc'][43] == 0
    assert saves['arrival']['partyRecord']['mapId'] == 23
    assert saves['arrival']['partyRecord']['etc'][43] == 1
    assert saves['arrival']['partyRecord']['gold'] - saves['thirdReady']['partyRecord']['gold'] == 306666
    assert captures['lore_17820.png']['after']['seed'] == 712085203
    assert [e['eNumber'] for e in captures['lore_17820.png']['after']['enemyRecords']] == [54,69,54,54,54,54,54]
    phase = json.loads((ROOT / 'test/fixtures/dos_frost_battle_phase.json').read_text())
    assert phase['initial'] == captures['lore_17820.png']['after']
    assert phase['closed'] == captures['lore_17836.png']['before']
    check_state(phase['initial']); check_state(phase['closed'])
    assert phase['executableSha256'] == f['executableSha256']
    print('Native lava WallBreak/Hospital, Frost two defeats and actual-save restart, complete gate victory/reward/save: verified')


if __name__ == '__main__':
    check()

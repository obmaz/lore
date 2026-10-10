#!/usr/bin/env python3
"""Check actual SWAMP Gate observations with explicit original sampling gaps."""
import hashlib
import json
from pathlib import Path
from check_dos_menace_return import check_save, check_state, next_seed

ROOT = Path(__file__).resolve().parents[1]


def check():
    f = json.loads((ROOT / 'test/fixtures/dos_swamp_gate_continuation.json').read_text())
    assert f['executableSha256'] == hashlib.sha256(
        (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()).hexdigest()
    old = json.loads((ROOT / 'test/fixtures/dos_lockup_continuation.json').read_text())
    previous = next(iter(old['segments'][-1]['trace'][-1].values()))['after']
    captures = {}
    for segment in f['segments']:
        if 'gap' in segment:
            gap = segment['gap']; before, after = gap['before'], gap['after']
            assert previous == before
            check_state(before); check_state(after)
            if before['live']['y'] == 80:
                assert after['live']['y'] == 78
                for key in ('seed', 'party', 'players', 'enemies', 'enemyCount', 'commandsHex'):
                    assert before[key] == after[key]
                assert before['live']['mapSha256'] == after['live']['mapSha256']
            else:
                # Original actor damage/knockout writes finish between Print snapshots.
                assert (before['live']['x'], before['live']['y']) == (81, 68)
                for key in ('seed', 'party', 'enemyCount', 'commandsHex', 'live'):
                    assert before[key] == after[key]
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
    assert state(11764)['partyRecord']['etc'][38] == 7
    spica = state(11764)['records'][2]
    assert spica['name'] == 'Spica' and spica['battleLevel'] == 11
    assert spica['espLevel'] == 11 and spica['experience'] == 1320000
    golden = f['saves']['goldenGeared']['records'][3]
    assert (golden['shield'], golden['armor'], golden['ac']) == (5, 5, 10)
    gate = f['saves']['gateEntry']['partyRecord']
    assert (gate['mapId'], gate['x'], gate['y']) == (13, 81, 95)
    assert gate['etc'][34] & 32
    assert state(12569)['enemyCount'] == 3
    assert [e['eNumber'] for e in state(12569)['enemyRecords']] == [1, 1, 1]
    assert state(12615)['partyRecord']['etc'][5] == 2
    assert state(12615)['enemyRecords'][2]['isDead']
    assert not state(12615)['enemyRecords'][0]['isDead']
    assert not state(12615)['enemyRecords'][1]['isDead']
    assert state(12616)['partyRecord']['etc'][37] & 16 == 0
    assert state(12619)['partyRecord']['mapId'] == 21
    assert (state(12619)['live']['x'], state(12619)['live']['y']) == (25, 6)
    print('Native Spica/golden equipment, SWAMP Gate/pyramid, Medusa death and escape to KEEP: verified')


if __name__ == '__main__':
    check()

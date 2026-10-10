#!/usr/bin/env python3
"""Check native EVIL GOD victory, original retry, ordered completion and disk save."""
import hashlib
import json
from pathlib import Path
from check_dos_menace_return import check_save, check_state, next_seed

ROOT = Path(__file__).resolve().parents[1]


def check():
    f = json.loads((ROOT / 'test/fixtures/dos_evil_god_success.json').read_text())
    assert f['executableSha256'] == hashlib.sha256(
        (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()).hexdigest()
    old = json.loads((ROOT / 'test/fixtures/dos_draconian_continuation.json').read_text())
    previous = next(iter(old['segments'][-1]['trace'][-1].values()))['after']
    captures = {}
    for segment in f['segments']:
        assert 'gap' not in segment, 'This native observation has no sampling gap'
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
    transitions = [next(iter(b.values())) for seg in f['segments'] for b in seg.get('trace', [])]
    won = next(v for v in transitions if v['before']['partyRecord']['etc'][39] == 14 and v['after']['partyRecord']['etc'][39] == 15)
    assert won['keys'] == ['space']
    assert all(e['hp'] <= 0 for e in won['before']['enemyRecords'])
    assert [e['eNumber'] for e in won['before']['enemyRecords']] == [59]*3 + [25]*4
    assert won['after']['partyRecord']['gold'] - won['before']['partyRecord']['gold'] == 105917
    # The next g only acknowledges completion; it does not open the Save menu.
    completion = captures['lore_14607.png']
    assert completion['keys'] == ['g']
    assert completion['before']['partyRecord']['etc'][39] == 15
    assert completion['after']['partyRecord']['etc'][39] == 15
    sealed = f['saves']['sealed']
    assert sealed['partyRecord']['etc'][39] == 15
    assert sealed['partyRecord']['mapId'] == 19
    print('Native EVIL GOD normal saved-checkpoint retry, victory, completion before acknowledgement and actual save: verified')


if __name__ == '__main__':
    check()

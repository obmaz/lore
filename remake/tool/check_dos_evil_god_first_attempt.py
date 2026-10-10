#!/usr/bin/env python3
"""Check native EVIL GOD first attempt, waits, seven enemies and archived reload."""
import hashlib
import json
from pathlib import Path
from check_dos_menace_return import check_save, check_state, next_seed

ROOT = Path(__file__).resolve().parents[1]


def check():
    f = json.loads((ROOT / 'test/fixtures/dos_evil_god_first_attempt.json').read_text())
    assert f['executableSha256'] == hashlib.sha256(
        (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()).hexdigest()
    old = json.loads((ROOT / 'test/fixtures/dos_swamp_gate_continuation.json').read_text())
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
    entry = f['saves']['entry']['files']['SAVE1.MAP']['hex']
    m = bytearray.fromhex(entry)
    assert hashlib.sha256(m[2:]).hexdigest() == row(12807)['before']['live']['mapSha256']
    assert row(12807)['before']['live']['mapSha256'] == state(12807)['live']['mapSha256']
    m[2+39*m[0]+10]=49; m[2+38*m[0]+40]=0
    assert hashlib.sha256(m[2:]).hexdigest() == state(12808)['live']['mapSha256']
    done=f['saves']['leversDone']['partyRecord']
    assert done['etc'][39]==2
    assert state(13309)['enemyCount']==7
    assert [e['eNumber'] for e in state(13309)['enemyRecords']]==[59]*3+[25]*4
    assert [e['hp'] for e in row(13309)['before']['enemyRecords']]==[510]*3+[210]*4
    oldSave=old['saves']['goldenGeared']['files']
    loaded=state(13383)
    assert loaded['players']==oldSave['PLAYER1.DAT']['hex']
    raw=bytearray.fromhex(oldSave['PARTY1.DAT']['hex']);raw[13]=255
    assert loaded['party']==raw.hex()
    assert loaded['live']['mapSha256']==hashlib.sha256(bytes.fromhex(oldSave['SAVE1.MAP']['hex'])[2:]).hexdigest()
    assert f['archivedReload']['slot']==2
    print('Native EVIL GOD levers/guard escapes/failed king fight and unchanged archived slot2 restore: verified')


if __name__=='__main__':
    check()

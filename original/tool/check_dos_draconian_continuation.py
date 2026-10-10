#!/usr/bin/env python3
"""Check actual SWAMP Gate observations with explicit original sampling gaps."""
import hashlib
import json
from pathlib import Path
from check_dos_menace_return import check_save, check_state, next_seed

ROOT = Path(__file__).resolve().parents[1]


def check():
    f = json.loads((ROOT / 'test/fixtures/dos_draconian_continuation.json').read_text())
    assert f['executableSha256'] == hashlib.sha256(
        (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()).hexdigest()
    old = json.loads((ROOT / 'test/fixtures/dos_evil_god_first_attempt.json').read_text())
    previous = next(iter(old['segments'][-1]['trace'][-1].values()))['after']
    captures = {}
    for segment in f['segments']:
        if 'gap' in segment:
            gap = segment['gap']; before, after = gap['before'], gap['after']
            assert previous == before
            check_state(before); check_state(after)
            if before['live']['y'] == 80:
                assert after['live']['y'] == 77
                for key in ('seed', 'party', 'players', 'enemies', 'enemyCount', 'commandsHex'):
                    assert before[key] == after[key]
                m=bytearray((ROOT/'repo_source/LORE_1993_runtime/DEN4.MAP').read_bytes())
                for y in range(71,82):
                    for x in range(76,87):
                        at=2+(y-1)*m[0]+x-1
                        if m[at]==52:m[at]=44
                        if m[at] in (40,51):m[at]=42
                assert hashlib.sha256(m[2:]).hexdigest()==before['live']['mapSha256']
                for y in range(71,82):
                    for x in range(76,87):
                        at=2+(y-1)*m[0]+x-1
                        if m[at]==42:m[at]=51
                assert hashlib.sha256(m[2:]).hexdigest()==after['live']['mapSha256']
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
    assert state(13960)['partyRecord']['etc'][4]==2
    assert row(13960)['before']['records'][2]['esp']==state(13960)['records'][2]['esp']
    assert state(13962)['partyRecord']['etc'][15]==0
    assert state(13963)['partyRecord']['etc'][15]==2
    d=state(13963)['records'][5]
    assert (d['name'],d['battleLevel'],d['hp'],d['weaPower'])==('Draconian',17,510,44)
    assert (d['classId'],d['resistance'],d['magicLevel'],d['sp'],d['experience'])==(0,30,15,300,3570000)
    assert state(13963)['records'][:5]==row(13963)['before']['records'][:5]
    assert f['saves']['joined']['records']==state(13966)['records']
    print('Native archived-save continuation, repeat Gate/Gorgon, legal wall-break and forced slot6 Draconian join: verified')


if __name__=='__main__':
    check()

#!/usr/bin/env python3
"""Check native MUDDY quiz, maze, dead-slot7 escape, ordered completion and disk save."""
import hashlib
import json
from pathlib import Path
from check_dos_menace_return import check_save, check_state, next_seed

ROOT = Path(__file__).resolve().parents[1]


def check():
    f = json.loads((ROOT / 'test/fixtures/dos_muddy_continuation.json').read_text())
    assert f['executableSha256'] == hashlib.sha256(
        (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()).hexdigest()
    old = json.loads((ROOT / 'test/fixtures/dos_evil_god_success.json').read_text())
    previous = next(iter(old['segments'][-1]['trace'][-1].values()))['after']
    captures = {}
    for segment in f['segments']:
        if 'gap' in segment:
            before, after = segment['gap']['before'], segment['gap']['after']
            assert previous == before
            check_state(before); check_state(after)
            for key in ('players', 'enemies', 'enemyCount', 'commandsHex'):
                assert before[key] == after[key]
            if before['partyRecord']['mapId'] == 9:
                assert after['partyRecord']['mapId'] == 13
                assert before['seed'] != after['seed'] == next_seed(before['seed'])
                raw = bytearray.fromhex(before['party']); raw[:3] = bytes([13,81,95])
                assert raw.hex() == after['party']
                original = ROOT/'repo_source/LORE_1993_runtime/DEN4.MAP'
                assert hashlib.sha256(original.read_bytes()[2:]).hexdigest() == after['live']['mapSha256']
            elif before['partyRecord']['mapId'] == 13:
                assert before['seed'] == after['seed']
                assert before['party'] == after['party']
                assert before['live']['x'] == after['live']['x'] == 81
                assert before['live']['y'] in (72,80) and after['live']['y'] == 77
                m = bytearray((ROOT/'repo_source/LORE_1993_runtime/DEN4.MAP').read_bytes())
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
                # Native party print/attack continuation between observations;
                # not a claimed closed-phase replay across this sampling gap.
                assert before['partyRecord']['mapId'] == 20
                assert before['party'] == after['party']
                assert (before['live']['x'],before['live']['y']) == (25,13)
                assert {k:v for k,v in before['live'].items() if k!='person'} == {k:v for k,v in after['live'].items() if k!='person'}
                assert (before['live']['person'],after['live']['person']) == (4,6)
                seed=before['seed']
                for _ in range(10):seed=next_seed(seed)
                assert seed==after['seed']
            previous=after
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
    completion = captures['lore_15994.png']
    assert completion['before']['enemyRecords'][6]['isDead']
    assert completion['before']['partyRecord']['etc'][40] == 14
    assert completion['after']['partyRecord']['etc'][40] == 15
    assert completion['after']['partyRecord']['mapId'] == 4
    assert completion['after']['partyRecord']['etc'][5] == 2
    assert (completion['after']['live']['x'],completion['after']['live']['y']) == (82,17)
    assert f['saves']['sealed']['partyRecord']['etc'][39:41] == [15,15]
    assert f['saves']['mazeReady']['partyRecord']['etc'][40] == 8
    assert f['saves']['dragonsReady']['partyRecord']['etc'][40] == 8
    assert f['saves']['dragonsReady']['partyRecord']['etc'][0] == 1
    assert all(not r['dead'] and not r['unconscious'] and not r['poison'] for r in f['saves']['hospital']['records'])
    print('Native original Hospital, MUDDY quizzes/maze/three fights, dead-slot7 escape and both completed actual seal saves: verified')


if __name__ == '__main__':
    check()

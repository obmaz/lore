#!/usr/bin/env python3
"""Check native LAVA gateway, Death Knight victory, guards restart and Last Shelter save."""
import hashlib
import json
from pathlib import Path
from check_dos_menace_return import check_save, check_state, next_seed

ROOT = Path(__file__).resolve().parents[1]


def check():
    f = json.loads((ROOT / 'test/fixtures/dos_keep2_continuation.json').read_text())
    assert f['executableSha256'] == hashlib.sha256(
        (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()).hexdigest()
    old = json.loads((ROOT / 'test/fixtures/dos_muddy_continuation.json').read_text())
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
    assert f['saves']['lavaArrival']['partyRecord']['mapId'] == 22
    assert f['saves']['lavaArrival']['partyRecord']['etc'][41] == 64
    assert f['saves']['deathKnightWon']['partyRecord']['etc'][42] == 2
    assert f['saves']['guardsReady']['partyRecord']['etc'][42] == 2
    assert f['saves']['lastShelter']['partyRecord']['etc'][42] == 2
    assert f['saves']['lastShelter']['partyRecord']['mapId'] == 24
    entry = captures['lore_16380.png']
    assert [e['eNumber'] for e in entry['after']['enemyRecords']] == [60,63,60,60,60]
    guards = captures['lore_16595.png']
    assert guards['before']['seed'] == guards['after']['seed']
    assert guards['before']['players'] == guards['after']['players']
    assert [e['eNumber'] for e in guards['after']['enemyRecords']] == [61,58,56,55,60]
    reload = captures['lore_16739.png']['after']
    loaded = bytearray.fromhex(f['saves']['guardsReady']['files']['PARTY1.DAT']['hex'])
    loaded[8+5] = 255
    assert reload['party'] == loaded.hex()
    assert reload['players'] == f['saves']['guardsReady']['files']['PLAYER1.DAT']['hex']
    print('Native LAVA/story/load/save, Death Knight victory, guards failure/actual-save restart and Last Shelter arrival: verified')


if __name__ == '__main__':
    check()

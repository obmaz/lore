"""Verify native final observations, eight closed turns and actual ending captures.

Observation gaps and busy Thunder are explicitly outside continuous replay claims.
Flutter replays the independently closed complete fight from original records/RNG.
"""
import hashlib
import json
from pathlib import Path
from check_dos_menace_return import check_state, check_save, next_seed

ROOT = Path(__file__).resolve().parents[1]


def load(name):
    return json.loads((ROOT / 'test/fixtures' / name).read_text())


def check():
    f = load('dos_final_continuation.json')
    old = load('dos_chamber_continuation.json')
    previous = next(iter(old['segments'][-1]['trace'][-1].values()))['after']
    digest = hashlib.sha256((ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()).hexdigest()
    assert f['executableSha256'] == digest
    captures = {}
    gaps = 0
    for seg in f['segments']:
        if 'gap' in seg:
            gap = seg['gap']
            assert previous == gap['before']
            check_state(gap['before']); check_state(gap['after'])
            assert 'chronology/replay is not asserted' in gap['scope']
            previous = gap['after']; gaps += 1
            continue
        for block in seg['trace']:
            r = next(iter(block.values()))
            before, after = r['before'], r['after']
            check_state(before); check_state(after)
            assert previous == before
            previous = after
            if 'idle' in block:
                assert before == after
                for item in r['inputs']:
                    if item['capture']:
                        captures[item['capture']] = dict(item, before=before, after=after)
            elif 'walk' in block:
                seed = before['seed']; x, y = before['live']['x'], before['live']['y']
                for item in r['steps']:
                    dx, dy = {'Up':(0,-1), 'Down':(0,1), 'Left':(-1,0), 'Right':(1,0)}[item['key']]
                    x += dx; y += dy; seed = next_seed(seed)
                    assert (x,y,seed) == (item['x'],item['y'],item['seedAfter'])
                assert (x,y,seed) == (after['live']['x'],after['live']['y'],after['seed'])
                for k in ('party','players','enemies','commandsHex','enemyCount'):
                    assert before[k] == after[k]
            else:
                if 'nativeMovementCalls' in r:
                    calls = r['nativeMovementCalls']; assert 0 < calls <= len(r['keys'])
                    assert set(r['keys']) <= {'Left','Right'}
                    seed = before['seed']
                    for _ in range(calls): seed = next_seed(seed)
                    assert seed == after['seed']
                    assert before['players'] == after['players']
                    assert before['party'] == after['party']
                    assert before['live']['mapSha256'] == after['live']['mapSha256']
                    assert after['partyRecord']['mapId'] == 26
                    assert after['live']['x'] in (24,25,26) and after['live']['y'] == 15
                if r['capture']: captures[r['capture']] = r
    assert gaps == 24
    for saved in f['saves'].values():
        files = check_save(saved,1); obs = saved['observation']; s = obs['beforeAcknowledgement']
        assert captures[obs['capture']]['after'] == s
        assert files['PARTY1.DAT']['hex'] == s['party']
        assert files['PLAYER1.DAT']['hex'] == s['players']
        assert hashlib.sha256(bytes.fromhex(files['SAVE1.MAP']['hex'])[2:]).hexdigest() == s['live']['mapSha256']
    order = load('dos_final_party_order.json'); swap = captures['lore_23061.png']
    assert order['initial'] == swap['before'] and order['closed'] == swap['after']
    assert order['slot7']['hex'] == swap['before']['players'][4*110:5*110]
    assert order['slot7']['record'] == swap['before']['records'][4]
    phase = load('dos_final_battle_phase.json')
    assert phase['initial'] == f['saves']['finalReady']['observation']['beforeAcknowledgement']
    assert phase['closed'] == captures['lore_21605.png']['before']
    fight = load('dos_final_complete_battle.json')
    assert fight['initial'] == f['saves']['orderReady']['observation']['beforeAcknowledgement']
    assert fight['firstClosed'] == captures['lore_23450.png']['before']
    turns = 0; cures = 0
    for step in fight['steps']:
        if 'cure' in step:
            c = step['cure']; r = captures[c['capture']]
            assert c['before'] == r['before'] and c['after'] == r['after']
            assert c['caster'] == 4 and c['target'] == 2 and c['spell'] == 6
            assert c['before']['seed'] == c['after']['seed']; cures += 1
        else:
            t = step['turn']; r = captures[t['capture']]
            assert t['before'] == r['before'] and t['commands'] == r['after']['commands']
            assert t['closed'] == captures[t['closedCapture']][t['closedSide']]
            check_state(t['closed']); turns += 1
    assert (turns,cures) == (8,3)
    last = fight['steps'][-1]['turn']['closed']
    assert last == captures['lore_23607.png']['after']
    assert last['partyRecord']['etc'][5] == 2 and last['seed'] == 1962890209
    assert last['records'][5]['hp'] == 15
    assert last['enemyRecords'][6]['isDead'] and last['enemyRecords'][6]['hp'] == 0
    assert all(not e['isDead'] and not e['isUnconscious'] for e in last['enemyRecords'][:6])
    ending = load('dos_final_ending_completion.json'); assert ending['executableSha256'] == digest
    for image in ending['images'].values():
        assert hashlib.sha256((ROOT / image['file']).read_bytes()).hexdigest() == image['sha256']
    for snap in [ending['staff']['before'],ending['staff']['after'],ending['halt']['before']]:
        check_state(snap['state']); assert snap['state']['players'] == last['players']
    assert ending['staff']['after']['sharedC'] == 255
    assert ending['staff']['keys'] == ending['halt']['keys'] == ['Escape']
    assert ending['halt']['imageSha256'] == ending['images']['theEnd']['sha256']
    print('Native final preparation/order, bounded input observations, eight full turns, dead-Neo escape, farewell/staff/The End/Halt: verified')


if __name__ == '__main__':
    check()

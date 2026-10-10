#!/usr/bin/env python3
"""Integrity of native WIVERN observations; battle replay is in Dart tests."""
import hashlib
import json
from pathlib import Path
from check_dos_menace_return import check_save, check_state, next_seed
ROOT=Path(__file__).resolve().parents[1]
def check():
    f=json.loads((ROOT/'test/fixtures/dos_wivern_continuation.json').read_text())
    assert f['executableSha256']==hashlib.sha256((ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()).hexdigest()
    captures={}
    for epoch in [dict(trace=f['trace'])]:
        previous=None
        for block in epoch['trace']:
            value=next(iter(block.values()))
            before,after=value['before'],value['after']
            check_state(before);check_state(after)
            if previous is not None:assert previous==before
            previous=after
            if 'walk' in block:
                seed=before['seed'];x,y=before['live']['x'],before['live']['y']
                for step in value['steps']:
                    dx,dy={'Up':(0,-1),'Down':(0,1),'Left':(-1,0),'Right':(1,0)}[step['key']]
                    x+=dx;y+=dy;seed=next_seed(seed)
                    assert (x,y,seed)==(step['x'],step['y'],step['seedAfter'])
                assert (x,y,seed)==(after['live']['x'],after['live']['y'],after['seed'])
                for key in ('party','players','enemies','commandsHex','enemyCount'):assert before[key]==after[key]
                assert before['live']['mapSha256']==after['live']['mapSha256']
            elif value['capture'] is not None:
                assert value['capture'] not in captures
                captures[value['capture']]=value
    def state(n):return captures[f'lore_{n}.png']['after']
    first=next(iter(f['trace'][0].values()))['before']
    previous=json.loads((ROOT/'test/fixtures/dos_quake_continuation.json').read_text())['saves']['quakeReturn']
    assert first['party']==previous['files']['PARTY1.DAT']['hex']
    assert first['players']==previous['files']['PLAYER1.DAT']['hex']
    for tag,n in [('wivernEntry',1640),('wivernBoss',1660),('wivernProgress1',1832),('wivernProgress2',1915),('wivernSuccess',2058),('waterArrival',2092)]:
        saved=check_save(f['saves'][tag],1)
        assert saved['PARTY1.DAT']['hex']==state(n)['party']
        assert saved['PLAYER1.DAT']['hex']==state(n)['players']
        assert hashlib.sha256(bytes.fromhex(saved['SAVE1.MAP']['hex'])[2:]).hexdigest()==state(n)['live']['mapSha256']
    assert state(1748)['partyRecord']['etc'][5]==255
    assert state(1748)['records']==f['saves']['wivernBoss']['records']
    for n,count in [(1812,0),(1813,1),(1895,1),(1896,2),(2052,2),(2054,3)]:
        assert state(n)['partyRecord']['etc'][36]==count
    for n,count in [(1750,3),(1835,2),(1918,1)]:assert state(n)['enemyCount']==count
    assert state(1812)['enemyRecords'][2]['isDead']
    assert state(1895)['enemyRecords'][1]['isDead']
    assert state(2054)['partyRecord']['etc'][5]==0
    assert state(2054)['partyRecord']['gold']==4547
    assert state(2058)['seed']==state(2059)['seed']
    assert state(2073)['partyRecord']['mapId']==10
    assert state(2072)['seed']==state(2073)['seed']
    assert state(2074)['partyRecord']['etc'][14]==0
    assert state(2086)['partyRecord']['etc'][14]==0
    assert state(2087)['partyRecord']['etc'][14]==1
    assert state(2093)['seed']==next_seed(state(2092)['seed'])
    print('Actual WIVERN killed-count escapes, victory, saves and WATER FIELD request: verified')
if __name__=='__main__':check()

#!/usr/bin/env python3
"""Integrity of preserved actual QUAKE observations; not a DOS auto replay."""
import hashlib
import json
from pathlib import Path
from check_dos_menace_return import check_save, check_state, next_seed
ROOT = Path(__file__).resolve().parents[1]

def check():
    f=json.loads((ROOT/'test/fixtures/dos_quake_continuation.json').read_text())
    assert f['executableSha256']==hashlib.sha256((ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()).hexdigest()
    captures={}
    for epoch in f['epochs']:
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
    first=next(iter(f['epochs'][0]['trace'][0].values()))['before']
    previous=json.loads((ROOT/'test/fixtures/dos_gaia_continuation.json').read_text())['saves']['evilReturn']
    assert first['party']==previous['files']['PARTY1.DAT']['hex']
    assert first['players']==previous['files']['PLAYER1.DAT']['hex']
    restart=next(iter(f['epochs'][1]['trace'][0].values()))['before']
    assert restart['party']==f['saves']['quakeBoss']['files']['PARTY1.DAT']['hex']
    assert restart['players']==f['saves']['quakeBoss']['files']['PLAYER1.DAT']['hex']
    for tag,n in [('quakeReady',948),('quakeEntry',1008),('quakeBoss',1025),('quakeSuccess',1414),('quakeReturn',1484)]:
        saved=check_save(f['saves'][tag],1)
        assert saved['PARTY1.DAT']['hex']==state(n)['party']
        assert saved['PLAYER1.DAT']['hex']==state(n)['players']
        assert hashlib.sha256(bytes.fromhex(saved['SAVE1.MAP']['hex'])[2:]).hexdigest()==state(n)['live']['mapSha256']
    assert state(1409)['enemyRecords'][2]['hp']==0
    assert state(1409)['partyRecord']['etc'][5]==2
    assert state(1410)['partyRecord']['etc'][13]==4
    assert state(1411)['partyRecord']['etc'][13]==5
    assert state(1480)['partyRecord']['etc'][13]==5
    assert state(1481)['partyRecord']['etc'][13]==6
    for b,a in zip(captures['lore_1480.png']['before']['records'],state(1480)['records']):
        assert a==dict(b,experience=b['experience']+40000)
    assert state(1485)['seed']==next_seed(state(1484)['seed'])
    assert state(1486)['records']==state(1487)['records']==state(1485)['records']
    print('Actual QUAKE knockout, escape, final quest key, GAIA reward and saves: verified')
if __name__=='__main__':check()

#!/usr/bin/env python3
"""Check preserved original mirror/duel and sign/lever actual saves."""
import hashlib
import json
from pathlib import Path
from check_dos_menace_return import check_state, check_save, next_seed
ROOT=Path(__file__).resolve().parents[1]
def check():
 f=json.loads((ROOT/'test/fixtures/dos_metal_continuation.json').read_text())
 old=json.loads((ROOT/'test/fixtures/dos_archi_continuation.json').read_text())
 previous=next(iter(old['segments'][-1]['trace'][-1].values()))['after']
 assert f['executableSha256']==hashlib.sha256((ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()).hexdigest()
 captures={}
 for seg in f['segments']:
  assert 'gap' not in seg
  for b in seg['trace']:
   r=next(iter(b.values()));before,after=r['before'],r['after']
   check_state(before);check_state(after);assert previous==before;previous=after
   if 'walk'in b:
    seed=before['seed'];x,y=before['live']['x'],before['live']['y']
    for step in r['steps']:
     dx,dy={'Up':(0,-1),'Down':(0,1),'Left':(-1,0),'Right':(1,0)}[step['key']];x+=dx;y+=dy;seed=next_seed(seed)
     assert(x,y,seed)==(step['x'],step['y'],step['seedAfter'])
    assert(x,y,seed)==(after['live']['x'],after['live']['y'],after['seed'])
    for k in ('party','players','enemies','commandsHex','enemyCount'):assert before[k]==after[k]
    assert before['live']['mapSha256']==after['live']['mapSha256']
   elif r['capture']:captures[r['capture']]=r
 for saved in f['saves'].values():
  files=check_save(saved,1);obs=saved['observation'];s=obs['beforeAcknowledgement'];assert captures[obs['capture']]['after']==s
  assert files['PARTY1.DAT']['hex']==s['party'];assert files['PLAYER1.DAT']['hex']==s['players']
  assert hashlib.sha256(bytes.fromhex(files['SAVE1.MAP']['hex'])[2:]).hexdigest()==s['live']['mapSha256']
 saves=f['saves']
 assert saves['metalReady']['partyRecord']['mapId']==25
 assert saves['metalWon']['partyRecord']['gold']-saves['metalReady']['partyRecord']['gold']==528624
 assert all(p['classId']==10 for p in saves['metalWon']['records'])
 change=captures['lore_20531.png']
 for a,b in zip(change['before']['records'],change['after']['records']):
  expected=dict(a,classId=10);assert expected==b
 assert change['before']['seed']==change['after']['seed']
 # The actual slot2 restoration is a byte-identical copy of the earlier native save.
 old_ready=old['saves']['archiReady']
 restored=captures['lore_19474.png']['after']
 assert restored['players']==old_ready['files']['PLAYER1.DAT']['hex']
 raw=bytes.fromhex(saves['metalWon']['files']['SAVE1.MAP']['hex']);w=raw[0]
 assert all(raw[2+42*w+x-1]==41 for x in range(24,28))
 print('Native slot2 restore, signed16 preparation, metal victory528624, corridor and exact class10-only records: verified')
if __name__=='__main__':check()

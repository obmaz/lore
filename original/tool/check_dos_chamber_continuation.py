#!/usr/bin/env python3
"""Check preserved original mirror/duel and sign/lever actual saves."""
import hashlib
import json
from pathlib import Path
from check_dos_menace_return import check_state, check_save, next_seed
ROOT=Path(__file__).resolve().parents[1]
def check():
 f=json.loads((ROOT/'test/fixtures/dos_chamber_continuation.json').read_text())
 old=json.loads((ROOT/'test/fixtures/dos_hidden_levers_continuation.json').read_text())
 previous=next(iter(old['segments'][-1]['trace'][-1].values()))['after']
 assert f['executableSha256']==hashlib.sha256((ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()).hexdigest()
 captures={}
 for seg in f['segments']:
  if 'gap' in seg:
   a,b=seg['gap']['before'],seg['gap']['after'];assert previous==a
   check_state(a);check_state(b)
   assert all(a[k]==b[k] for k in a if k!='seed')
   seed=a['seed'];steps=0
   while seed!=b['seed'] and steps<=20:seed=next_seed(seed);steps+=1
   assert steps in (6,8);previous=b;continue
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
 assert saves['chamberReady']['partyRecord']['mapId']==25
 assert saves['chamberWon']['partyRecord']['mapId']==26
 assert(saves['chamberWon']['partyRecord']['x'],saves['chamberWon']['partyRecord']['y'])==(25,15)
 assert saves['chamberWon']['partyRecord']['gold']-saves['chamberReady']['partyRecord']['gold']==323868
 raw=bytes.fromhex(saves['chamberWon']['files']['SAVE1.MAP']['hex']);w=raw[0]
 assert all(raw[2+(y-1)*w+x-1]==16 for y in range(16,20)for x in range(24,27))
 phase=json.loads((ROOT/'test/fixtures/dos_chamber_battle_phase.json').read_text())
 assert phase['initial']==captures['lore_21107.png']['after']
 assert phase['closed']==captures['lore_21148.png']['before']
 assert phase['commands']==captures['lore_21109.png']['after']['commands']
 print('Native lava healing/paging, chamber failure/restart, closed turn, victory323868 and actual map26 load/save: verified')
if __name__=='__main__':check()

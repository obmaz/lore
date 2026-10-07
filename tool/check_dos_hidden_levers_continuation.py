#!/usr/bin/env python3
"""Check preserved original mirror/duel and sign/lever actual saves."""
import hashlib
import json
from pathlib import Path
from check_dos_menace_return import check_state, check_save, next_seed
ROOT=Path(__file__).resolve().parents[1]
def check():
 f=json.loads((ROOT/'test/fixtures/dos_hidden_levers_continuation.json').read_text())
 old=json.loads((ROOT/'test/fixtures/dos_metal_continuation.json').read_text())
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
 assert saves['leftLever']['partyRecord']['etc'][44]==64
 assert saves['leversOpen']['partyRecord']['etc'][44]==192
 assert all(s['partyRecord']['mapId']==25 for s in saves.values())
 raw=bytes.fromhex(saves['leversOpen']['files']['SAVE1.MAP']['hex']);w=raw[0]
 def tile(x,y):return raw[2+(y-1)*w+x-1]
 assert tile(25,27)==tile(26,27)==54
 assert tile(15,34)==tile(36,34)==41
 assert all(tile(x,34)==42 for x in list(range(11,15))+list(range(37,41)))
 assert tile(5,34)==tile(46,34)==0
 print('Native both corridors, lever64/192 before ACK and full final portal save: verified')
if __name__=='__main__':check()

#!/usr/bin/env python3
"""Check preserved original mirror/duel and sign/lever actual saves."""
import hashlib
import json
from pathlib import Path
from check_dos_menace_return import check_state, check_save, next_seed
ROOT=Path(__file__).resolve().parents[1]
def check():
 f=json.loads((ROOT/'test/fixtures/dos_keep3_continuation.json').read_text())
 old=json.loads((ROOT/'test/fixtures/dos_frost_continuation.json').read_text())
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
 def raw(tag):return bytearray.fromhex(f['saves'][tag]['files']['SAVE1.MAP']['hex'])
 expected=raw('mirrorReady');w=expected[0]
 expected[2+42*w+28]=53
 for y in range(25,28):
  for x in range(24,28):expected[2+(y-1)*w+x-1]=46
 assert raw('impostorWon')==expected==raw('beforeSign')
 expected[2+42*w+28]=44;expected[2+26*w+24]=46
 for y in range(7,35):
  for x in range(12,40):
   i=2+(y-1)*w+x-1
   if expected[i]==0:expected[i]=39
 expected[2+11*w+24]=54;expected[2+11*w+25]=54
 assert raw('leverOpen')==expected
 assert all(e['eNumber']==1 for e in captures['lore_18287.png']['after']['enemyRecords'])
 assert captures['lore_18287.png']['before']['seed']==captures['lore_18287.png']['after']['seed']
 print('Native six mirror enemies, mirror and impostor victories, sign-created lever and full saved map: verified')
if __name__=='__main__':check()

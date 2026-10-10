#!/usr/bin/env python3
"""Check preserved original mirror/duel and sign/lever actual saves."""
import hashlib
import json
from pathlib import Path
from check_dos_menace_return import check_state, check_save, next_seed
ROOT=Path(__file__).resolve().parents[1]
def check():
 f=json.loads((ROOT/'test/fixtures/dos_archi_continuation.json').read_text())
 old=json.loads((ROOT/'test/fixtures/dos_keep3_continuation.json').read_text())
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
 assert saves['archiReady']['partyRecord']['mapId']==23
 assert saves['archiReady']['partyRecord']['etc'][43]==1
 assert saves['hiddenArrival']['partyRecord']['mapId']==25
 assert saves['hiddenArrival']['partyRecord']['etc'][43]==3
 assert saves['hiddenArrival']['partyRecord']['etc'][5]==255
 assert saves['hiddenArrival']['files']['PLAYER1.DAT']==saves['archiReady']['files']['PLAYER1.DAT']
 strike=captures['lore_18582.png'];assert strike['after']['records'][5]['dead']==30000
 assert strike['before']['seed']==strike['after']['seed']
 cure=captures['lore_18602.png'];assert cure['before']['records'][3]['sp']==320
 assert cure['after']['records'][3]['sp']==17782 and cure['after']['records'][5]['hp']==49
 assert cure['before']['seed']==cure['after']['seed']
 admission=captures['lore_18901.png']['after']
 assert admission['enemyRecords'][2]['isDead'] and admission['partyRecord']['mapId']==25
 assert all(not e['isDead'] for i,e in enumerate(admission['enemyRecords']) if i!=2)
 print('Native Archi strike30000, signed16 whole cure, retries, key slot3 dead and unchecked GameOver admission/save: verified')
if __name__=='__main__':check()

#!/usr/bin/env python3
"""Execute unchanged original condition/HP/revival/encounter/boss instructions.
Synthetic frame/records and supplied damage; not a full DOS game replay.
"""
import argparse,hashlib,json,struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'test/fixtures/dos_condition_storage.json'
FRAGMENTS=[('condition',0x2ad98,0x2ade7),('swamp-poison',0x7a1e,0x7a90),
 ('move-poison',0x7f09,0x7f7b),('lava-unconscious',0x7e05,0x7e8c),
 ('revival-cap',0x25fb1,0x26000),('attack-hp',0x2106b,0x2107d),
 ('cast-hp',0x21510,0x21522),('enemy-poison',0x2543c,0x25455),
 ('xp-store',0x208ca,0x208e6),('hospital-gold',0x2e5e5,0x2e5ff),('party-luck',0x257ad,0x2580e),
 ('party-agility',0x2588e,0x258ef),('enemy-average',0x25700,0x25715),
 ('joinenemy-stats',0x2c88e,0x2c9a7),('sphinx-fields',0x19681,0x19698),
 ('hidra-fields',0x1cc29,0x1cc42),('long-divisor-check',0x36a6d,0x36a74),
 ('long-divide-zero',0x36ad4,0x36adb)]
def build():
 from unicorn import Uc,UC_ARCH_X86,UC_MODE_16,UC_HOOK_CODE
 from unicorn.x86_const import UC_X86_REG_AX,UC_X86_REG_CS,UC_X86_REG_DS,UC_X86_REG_SS,UC_X86_REG_SP,UC_X86_REG_BP,UC_X86_REG_IP
 exe=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes();header=struct.unpack_from('<H',exe,8)[0]*16
 def machine(a,ptr=-4):
  cs=0 if a<0x15370 else 0x1000 if a<0x25370 else 0x2000
  u=Uc(UC_ARCH_X86,UC_MODE_16);u.mem_map(0,0x80000);u.mem_write(0,exe[header:])
  for r,v in [(UC_X86_REG_CS,cs),(UC_X86_REG_DS,0x5000),(UC_X86_REG_SS,0x6000),(UC_X86_REG_SP,0xff00),(UC_X86_REG_BP,0x8000)]:u.reg_write(r,v)
  u.mem_write(0x68000+ptr,struct.pack('<HH',0x100,0x5000));return u
 def run(u,a,z):
  cs=0 if a<0x15370 else 0x1000 if a<0x25370 else 0x2000;u.reg_write(UC_X86_REG_CS,cs)
  hit=[]
  def hook(v,address,size,data):
   if address==z-header:hit.append(True);v.emu_stop()
  h=u.hook_add(UC_HOOK_CODE,hook)
  try:u.emu_start(a-header,0x7ffff,count=100000)
  finally:u.hook_del(h)
  assert hit,hex(a)
 def player(end,level,hp,uncon,dead):
  p=bytearray(55);p[:5]=b'\x04Hero';p[23]=end;p[41]=level;struct.pack_into('<hhh',p,31,uncon,dead,hp);return bytes(p)
 def states(u):
  uncon,dead,hp=struct.unpack('<hhh',u.mem_read(0x5011f,6));return dict(hp=hp,unconscious=uncon,dead=dead)
 conditions=[];poisons=[];lava=[];revivals=[]
 inputs=[(20,5,10,0,0),(20,5,0,0,0),(20,5,0,101,0),(255,255,10,0,0),
  (255,255,0,1,0),(200,200,0,1,0),(255,128,0,32767,0),(20,5,0,1,100)]
 for end,level,hp,uncon,dead in inputs:
  base=dict(endurance=end,level=level,hp=hp,unconscious=uncon,dead=dead)
  u=machine(0x2ad98);u.mem_write(0x50100,player(end,level,hp,uncon,dead));run(u,0x2ad98,0x2ade7);conditions.append(dict(base,after=states(u)))
  observed=[]
  for a,z in [(0x7a1e,0x7a90),(0x7f09,0x7f7b)]:
   u=machine(a);u.mem_write(0x50100,player(end,level,hp,uncon,dead));run(u,a,z);observed.append(states(u))
  assert observed[0]==observed[1];poisons.append(dict(base,after=observed[0]))
  if hp<=0 and uncon>0 and dead==0:
   for damage in [1,70,-400]:
    u=machine(0x7e05);u.mem_write(0x50100,player(end,level,hp,uncon,dead));u.mem_write(0x53660,struct.pack('<h',damage));run(u,0x7e05,0x7e8c);lava.append(dict(base,damage=damage,after=states(u)))
  for unconscious in [0,1,30000]:
   u=machine(0x25fb1);u.mem_write(0x50100,player(end,level,hp,unconscious,0));run(u,0x25fb1,0x26000);revivals.append(dict(endurance=end,level=level,unconscious=unconscious,afterUnconscious=states(u)['unconscious']))
 hpstores=[];enemy_poison=[];gold=[];experience=[]
 for routine,a,z in [('attack',0x2106b,0x2107d),('cast',0x21510,0x21522)]:
  for hp,damage in [(100,30),(-32760,1000),(-32641,360),(10,360)]:
   u=machine(a);e=bytearray(35);struct.pack_into('<h',e,30,hp);u.mem_write(0x50100,bytes(e));u.mem_write(0x5702e,struct.pack('<h',damage));run(u,a,z);hpstores.append(dict(routine=routine,hp=hp,damage=damage,afterHp=struct.unpack('<h',u.mem_read(0x5011e,2))[0]))
 for hp in [100,1,0,-32768]:
  u=machine(0x2543c,-6);e=bytearray(35);struct.pack_into('<h',e,30,hp);u.mem_write(0x50100,bytes(e));run(u,0x2543c,0x25455);enemy_poison.append(dict(hp=hp,afterHp=struct.unpack('<h',u.mem_read(0x5011e,2))[0],afterUnconscious=bool(u.mem_read(0x50121,1)[0])))
 for before,cost in [(1000,200),(2147483647,-32768),(-2147483648,1)]:
  u=machine(0x2e5e5);u.mem_write(0x564ce,struct.pack('<i',before));u.mem_write(0x67ffe,struct.pack('<h',cost));run(u,0x2e5e5,0x2e5ff);gold.append(dict(before=before,cost=cost,after=struct.unpack('<i',u.mem_read(0x564ce,4))[0]))
 for before,amount in [(1200,1000),(2147483647,1000),(-2147483648,-1)]:
  u=machine(0x208ca,-10);p=bytearray(55);struct.pack_into('<i',p,45,before);u.mem_write(0x50100,bytes(p));u.mem_write(0x67ffa,struct.pack('<i',amount));run(u,0x208ca,0x208e6);experience.append(dict(before=before,amount=amount,after=struct.unpack('<i',u.mem_read(0x5012d,4))[0]))
 averages=[]
 for kind,a,z,offset in [('luck',0x257ad,0x2580e,29),('agility',0x2588e,0x258ef,25)]:
  for values in [[10]*6+[255],[1,2,3,4,5,6,255],[0]*7]:
   u=machine(a)
   for i,v in enumerate(values):
    p=bytearray(55);p[:2]=b'\x01H';p[offset]=v;u.mem_write(0x564ff+55*(i+1),bytes(p))
   run(u,a,z);averages.append(dict(kind=kind,values=values,average=struct.unpack('<h',u.mem_read(0x53662,2))[0]))
 faults=[]
 for name,a,z in [('party',0x2588e,0x258ef),('enemy',0x25700,0x25715)]:
  u=machine(a);u.mem_write(0x53660,bytes(2));u.mem_write(0x53664,bytes(2));errors=[]
  def runtime_error(vm,address,size,data):
   if address==0x36122-header:errors.append(vm.reg_read(UC_X86_REG_AX));vm.emu_stop()
  u.hook_add(UC_HOOK_CODE,runtime_error);u.emu_start(a-header,0x7ffff,count=100000)
  assert errors==[200];faults.append(name)
 bosses=[];foe=(ROOT/'repo_source/LORE_1993_runtime/FOEDATA.DAT').read_bytes()
 for name,num,a,z in [('Sphinx',35,0x19681,0x19698),('Hidra',49,0x1cc29,0x1cc42)]:
  u=machine(0x2c88e);u.mem_write(0x566b8,foe[(num-1)*29:num*29]);u.mem_write(0x68006,b'\x01');run(u,0x2c88e,0x2c9a7);before=bytes(u.mem_read(0x50100,35));run(u,a,z);after=bytes(u.mem_read(0x50100,35));assert before[30:32]==after[30:32];bosses.append(dict(name=name,template=num,before=list(before),after=list(after)))
 return dict(scope='Unmodified native instructions, synthetic frames; no whole-game replay',exeSha256=hashlib.sha256(exe).hexdigest(),foedataSha256=hashlib.sha256(foe).hexdigest(),fragments=[dict(name=n,start=a,end=z,sha256=hashlib.sha256(exe[a:z]).hexdigest()) for n,a,z in FRAGMENTS],conditions=conditions,poisons=poisons,lava=lava,revivals=revivals,hpStores=hpstores,enemyPoison=enemy_poison,gold=gold,experience=experience,averages=averages,divisionFaults=faults,divisionErrorCode=200,bosses=bosses)
def check():
 d=json.loads(OUT.read_text());exe=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes();assert d['exeSha256']==hashlib.sha256(exe).hexdigest();assert d['foedataSha256']==hashlib.sha256((ROOT/'repo_source/LORE_1993_runtime/FOEDATA.DAT').read_bytes()).hexdigest()
 for r,(n,a,z) in zip(d['fragments'],FRAGMENTS,strict=True):assert r==dict(name=n,start=a,end=z,sha256=hashlib.sha256(exe[a:z]).hexdigest())
 print('Original condition/HP/encounter/boss evidence checked')
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args()
 if a.check:check()
 else:OUT.write_text(json.dumps(build(),indent=2)+'\n');check()

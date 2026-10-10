#!/usr/bin/env python3
"""Independent original EXE fragments, synthetic records; not full DOS playthrough."""
import argparse, hashlib, json, struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'test/fixtures/dos_recruit_storage.json'
FRAGMENTS=[('join',0x2c4c4,0x2c843),('enemy-hp',0x2c972,0x2c98f),
 ('mind-call',0x2469d,0x246a8),('mind',0x2c9f0,0x2cb11),('gold',0x2c405,0x2c419),
 ('heal-check',0x25abe,0x25add),('heal-cap',0x25b8a,0x25bc6),
 ('rest-refund',0x28e25,0x28e4f),('rest-heal',0x28e4f,0x28e9d),
 ('hospital-check',0x2e56c,0x2e58b),('hospital-store',0x2e5ff,0x2e61c),
 ('weapon',0x2d319,0x2d368),('armor',0x2d77d,0x2d7bd),
 ('rigel',0x19a78,0x19aa2),('average',0x23ba7,0x23bb1)]
def build():
 from unicorn import Uc,UcError,UC_ARCH_X86,UC_MODE_16,UC_HOOK_CODE
 from unicorn.x86_const import UC_X86_REG_CS,UC_X86_REG_DS,UC_X86_REG_SS,UC_X86_REG_BP,UC_X86_REG_SP,UC_X86_REG_IP
 exe=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes();header=struct.unpack_from('<H',exe,8)[0]*16
 def machine(cs=0x2000,ptr=-4):
  u=Uc(UC_ARCH_X86,UC_MODE_16);u.mem_map(0,0x80000);u.mem_write(0,exe[header:])
  for r,v in [(UC_X86_REG_CS,cs),(UC_X86_REG_DS,0x5000),(UC_X86_REG_SS,0x6000),(UC_X86_REG_BP,0x8000),(UC_X86_REG_SP,0xff00)]:u.reg_write(r,v)
  u.mem_write(0x68000+ptr,struct.pack('<HH',0x100,0x5000));return u
 def run(u,a,z,alternate=None):
  stops=[z-header]+([] if alternate is None else [alternate-header]);hit=[]
  def hook(vm,address,size,data):
   if address in stops:hit.append(address+header);vm.emu_stop()
  h=u.hook_add(UC_HOOK_CODE,hook)
  u.emu_start(a-header,0x7ffff,count=100000);u.hook_del(h)
  assert hit,hex(a);return hit[0]
 def record(endurance,level,hp=0):
  p=bytearray(55);p[:5]=b'\x04Hero';p[23]=endurance;p[41]=level;struct.pack_into('<h',p,35,hp);return p
 def hp(u):return struct.unpack('<h',u.mem_read(0x50123,2))[0]
 joins=[]
 for level,cast,end,mental,previous in [(n,5,35,20,123456) for n in range(0,32)]+[(255,255,255,255,-123),(128,128,255,255,139),(20,86,200,255,0),(30,0,60,20,0)]:
  t=bytearray(29);t[:9]=b'\x08Template';t[17:]=bytes([30,mental,end,80,18,19,20,7,2,cast,1,level]);u=machine();u.mem_write(0x566b8,bytes(t));u.mem_write(0x68008,b'\x01');p=record(1,1);struct.pack_into('<i',p,45,previous);u.mem_write(0x50100,bytes(p));run(u,0x2c4c4,0x2c843);r=bytes(u.mem_read(0x50100,55))
  joins.append(dict(level=level,cast=cast,endurance=end,mentality=mental,previousExperience=previous,record=list(r)))
 enemies=[]
 for end,level in [(8,1),(0,255),(255,0),(255,128),(255,255),(60,30)]:
  t=bytearray(29);t[19]=end;t[28]=level;u=machine();u.mem_write(0x566b8,bytes(t));u.mem_write(0x68006,b'\x01');e=bytearray(35);e[20]=end;e[29]=level;u.mem_write(0x50100,bytes(e));run(u,0x2c972,0x2c98f);result=struct.unpack('<h',u.mem_read(0x5011e,2))[0]
  enemies.append(dict(endurance=end,level=level,hp=result))
 mind_calls=[]
 for k in range(1,8):
  u=machine(cs=0x1000);u.mem_write(0x53662,struct.pack('<H',k))
  run(u,0x2469d,0x246a3)
  sp=u.reg_read(UC_X86_REG_SP)
  enemy_num,player_num=struct.unpack('<HH',u.mem_read(0x60000+sp,4))
  mind_calls.append(dict(k=k,player=player_num,enemy=enemy_num))
 minds=[]
 for end,level in [(20,5),(255,0),(255,128),(255,255)]:
  u=machine();p=record(end,level);p[42]=20;u.mem_write(0x56536,bytes(p));u.mem_write(0x68008,b'\x01');run(u,0x2c9f0,0x2cb11);minds.append(dict(endurance=end,level=level,hp=struct.unpack('<h',u.mem_read(0x5011e,2))[0]))
 gold=[]
 for before,amount in [(1200,5000),(2147483647,1),(-2147483648,-1),(2147480000,5000)]:
  u=machine();u.mem_write(0x564ce,struct.pack('<i',before));u.mem_write(0x68006,struct.pack('<i',amount));run(u,0x2c405,0x2c419);gold.append(dict(before=before,amount=amount,after=struct.unpack('<i',u.mem_read(0x564ce,4))[0]))
 health=[]
 for end,level,before in [(20,5,80),(20,5,100),(255,255,0),(255,255,-1000),(255,128,32635),(255,128,32640),(200,200,-30000)]:
  u=machine();u.mem_write(0x50100,bytes(record(end,level,before)));branch=run(u,0x25abe,0x25add,0x25b08)
  v=machine(ptr=-10);v.mem_write(0x50100,bytes(record(end,level,before)));hospital=run(v,0x2e56c,0x2e58b,0x2e592);run(v,0x2e5ff,0x2e61c)
  u=machine();u.mem_write(0x50100,bytes(record(end,level,before)));run(u,0x25b8a,0x25bc6)
  hospital_hp=hp(v)
  v=machine();v.mem_write(0x50100,bytes(record(end,level,((before+765+32768)%65536)-32768)));run(v,0x25b8a,0x25bc6)
  health.append(dict(healedHp=hp(v),endurance=end,level=level,hp=before,needsHealing=branch==0x25b08,hospitalNeedsHealing=hospital==0x2e592,capHp=hp(u),hospitalHp=hospital_hp))
 rests=[]
 for end,level,before,food in [(20,5,80,10),(20,5,100,10),(255,255,0,10),(255,255,-1000,10),(255,128,32640,255),(255,128,32635,10),(200,200,-30000,10)]:
  u=machine();u.mem_write(0x50100,bytes(record(end,level,before)));u.mem_write(0x564cd,bytes([food]));u.mem_write(0x5365e,struct.pack('<h',(level+2)*2));run(u,0x28e25,0x28e4f);branch=run(u,0x28e4f,0x28e9d,0x28ec0)
  rests.append(dict(endurance=end,level=level,hp=before,food=food,afterHp=hp(u),afterFood=u.mem_read(0x564cd,1)[0]-1,full=branch==0x28e9d))
 weapons=[];armors=[];rigel=[]
 for cls in [1,4]:
  for power in [0,1,3,12,50,170,171,255]:
   u=machine(ptr=-12);p=record(20,1);p[19]=cls;u.mem_write(0x50100,bytes(p));u.mem_write(0x67ffe,bytes([power]));run(u,0x2d319,0x2d368);weapons.append(dict(classId=cls,power=power,after=u.mem_read(0x50134,1)[0]))
  for shield,armor in [(0,0),(3,6),(5,5),(255,0),(255,1),(255,255)]:
   u=machine(ptr=-12);p=record(20,1);p[19]=cls;p[53]=shield;p[54]=armor;u.mem_write(0x50100,bytes(p));run(u,0x2d77d,0x2d7bd);armors.append(dict(classId=cls,shield=shield,armor=armor,after=u.mem_read(0x5012c,1)[0]))
 for power in range(256):
  u=machine(0x1000);p=record(20,1);p[52]=power;u.mem_write(0x50100,bytes(p));run(u,0x19a78,0x19aa2);rigel.append(dict(power=power,after=u.mem_read(0x50134,1)[0]))
 u=machine(0x1000);u.mem_write(0x67ffa,bytes(6));fault=False
 try:run(u,0x23ba7,0x23bb1)
 except UcError:fault=True;assert 0x10000+u.reg_read(UC_X86_REG_IP)==0x23bab-header
 return dict(scope='Unmodified DOS instruction fragments; synthetic state, no full game replay',exeSha256=hashlib.sha256(exe).hexdigest(),fragments=[dict(name=n,start=a,end=z,sha256=hashlib.sha256(exe[a:z]).hexdigest()) for n,a,z in FRAGMENTS],joins=joins,enemies=enemies,mindCalls=mind_calls,minds=minds,gold=gold,health=health,rests=rests,weapons=weapons,armors=armors,rigel=rigel,emptyAverageFault=fault)
def check():
 data=json.loads(OUT.read_text());exe=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes();assert data['exeSha256']==hashlib.sha256(exe).hexdigest()
 for r,(n,a,z) in zip(data['fragments'],FRAGMENTS,strict=True):assert r==dict(name=n,start=a,end=z,sha256=hashlib.sha256(exe[a:z]).hexdigest())
 print('Recruit/storage native evidence checked')
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args()
 if a.check:check()
 else:OUT.write_text(json.dumps(build(),indent=2)+'\n');check()

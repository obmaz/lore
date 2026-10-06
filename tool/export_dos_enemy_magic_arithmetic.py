#!/usr/bin/env python3
"""Run original enemy magic/cure/AI instruction fragments in Unicorn x86-16.
Synthetic memory and supplied random results; not a complete DOS RNG/battle replay.
--check verifies immutable EXE and fragment bytes without Unicorn.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUTPUT=ROOT/'test/fixtures/dos_enemy_magic_arithmetic.json'
FRAGMENTS=[('variance',0x22fff,0x23010),('defence',0x23023,0x23058),
 ('magic-stores',0x23091,0x230f6),('cure',0x234f8,0x2358f),
 ('threshold4',0x237e4,0x23800),('threshold5',0x2392e,0x2394a),
 ('threshold6',0x23b1a,0x23b36),('self-heal',0x23818,0x23831),
 ('group-heal5',0x23a6e,0x23a8a),('group-heal6',0x23d67,0x23d83),
 ('aggregate5',0x239b7,0x23a39),('decision5',0x23a39,0x23a48),
 ('aggregate6',0x23cb0,0x23d32),('decision6',0x23d32,0x23d41)]


def build():
 from unicorn import Uc,UcError,UC_ARCH_X86,UC_MODE_16,UC_HOOK_CODE
 from unicorn.x86_const import (UC_X86_REG_AX,UC_X86_REG_CS,UC_X86_REG_DS,
  UC_X86_REG_SS,UC_X86_REG_SP,UC_X86_REG_BP,UC_X86_REG_IP)
 exe=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
 header=struct.unpack_from('<H',exe,8)[0]*16
 def machine():
  u=Uc(UC_ARCH_X86,UC_MODE_16);u.mem_map(0,0x80000);u.mem_write(0,exe[header:])
  for r,v in [(UC_X86_REG_CS,0x1000),(UC_X86_REG_DS,0x5000),(UC_X86_REG_SS,0x6000),
   (UC_X86_REG_SP,0xff00),(UC_X86_REG_BP,0x8000)]:u.reg_write(r,v)
  return u
 def run(u,a,b):
  u.emu_start(a-header,b-header,count=10000)
  assert u.reg_read(UC_X86_REG_CS)==0x1000 and 0x10000+u.reg_read(UC_X86_REG_IP)==b-header
 def short(u,a):return struct.unpack('<h',u.mem_read(a,2))[0]
 def word(u,a,v):u.mem_write(a,struct.pack('<h',v))
 magic=[]
 scenarios=[('active-zero',0,1,0,30000,0,0),('active-wrap-zero',128,128,3,30000,0,0),
  ('active-wrap-small',255,26,9,30000,0,0),('active-large',255,255,9,30000,0,0),
  ('dead-store',0,1,0,0,32760,0),('unconscious-store',0,1,0,0,0,32760)]
 for power in [0,40,2550,32767]:
  for variance in sorted(set([0,max(0,power//2-1)])):
   for name,ac,level,roll,hp,dead,unconscious in scenarios:
    u=machine();word(u,0x68006,1);word(u,0x68008,power)
    player=bytearray(55);player[0:5]=b'\x04Hero';player[41],player[44]=level,ac
    struct.pack_into('<hhh',player,31,unconscious,dead,hp);u.mem_write(0x56536,bytes(player))
    u.reg_write(UC_X86_REG_AX,variance);run(u,0x22fff,0x23010)
    active=hp>0 and dead==0 and unconscious==0
    if active:u.reg_write(UC_X86_REG_AX,roll);run(u,0x23023,0x23058)
    net=short(u,0x68008)
    if net>0:run(u,0x23091,0x230f6)
    au,ad,ah=struct.unpack('<hhh',u.mem_read(0x56555,6))
    magic.append(dict(scenario=name,power=power,variance=variance,ac=ac,level=level,
     defenceRoll=roll,hp=hp,dead=dead,unconscious=unconscious,active=active,
     netDamage=net,afterHp=ah,afterDead=ad,afterUnconscious=au))
 cures=[]
 inputs=[(100,20,20,20,False,False),(390,20,20,20,False,False),
  (32760,20,255,128,False,False),(100,20,255,255,False,False),
  (-10,5,20,20,False,False),(100,-200,20,20,False,False),
  (0,20,20,20,True,False),(-10,20,20,20,False,True),
  (100,20,20,20,False,True),(100,20,20,20,True,True)]
 for hp,plus,endurance,level,dead,unconscious in inputs:
  u=machine();word(u,0x68008,1);word(u,0x68006,plus)
  enemy=bytearray(35);enemy[20],enemy[29]=endurance,level
  struct.pack_into('<h',enemy,30,hp);enemy[33],enemy[34]=unconscious,dead
  u.mem_write(0x56f38,bytes(enemy));run(u,0x234f8,0x2358f)
  cures.append(dict(hp=hp,plus=plus,endurance=endurance,level=level,dead=dead,unconscious=unconscious,
   afterHp=short(u,0x56f56),afterUnconscious=bool(u.mem_read(0x56f59,1)[0]),
   afterDead=bool(u.mem_read(0x56f5a,1)[0])))
 thresholds=[];heals=[]
 for mode,start,end,fault_ip in [(4,0x237e4,0x23800,0x237fe),(5,0x2392e,0x2394a,0x23948),(6,0x23b1a,0x23b36,0x23b34)]:
  for endurance,level in [(20,20),(128,255),(255,255),(128,128),(255,128),(200,200),(0,255)]:
   u=machine();u.mem_write(0x67ff6,struct.pack('<HH',0x100,0x5000))
   enemy=bytearray(35);enemy[20],enemy[29]=endurance,level;u.mem_write(0x50100,bytes(enemy))
   row=dict(mode=mode,endurance=endurance,level=level)
   try:run(u,start,end);row['threshold']=u.reg_read(UC_X86_REG_AX)
   except UcError:
    assert 0x10000+u.reg_read(UC_X86_REG_IP)==fault_ip-header;row['fault']='division-overflow'
   thresholds.append(row)
 for kind,start,end,divisor,fault_ip in [('self',0x23818,0x23831,4,None),
  ('group5',0x23a6e,0x23a8a,6,0x23a88),('group6',0x23d67,0x23d83,6,0x23d81)]:
  for level,mentality in [(20,20),(255,255),(255,128),(200,200)]:
   u=machine();u.mem_write(0x67ff6,struct.pack('<HH',0x100,0x5000))
   enemy=bytearray(35);enemy[19],enemy[29]=mentality,level;u.mem_write(0x50100,bytes(enemy))
   row=dict(kind=kind,level=level,mentality=mentality,divisor=divisor)
   try:run(u,start,end);row['amount']=u.reg_read(UC_X86_REG_AX)
   except UcError:
    assert 0x10000+u.reg_read(UC_X86_REG_IP)==fault_ip-header;row['fault']='division-overflow'
   heals.append(row)
 groups=[]
 layouts=[[(12000,100,150)]*3,[(100,100,200)]*3,[(100,20,20)]*3,
  [(100,20,20)]*2,[(-1,20,20),(30000,20,20),(100,20,20)],[(9000,100,100)]*7]
 for mode,start,end,trial,fallback in [(5,0x239b7,0x23a39,0x23a48,0x23a99),
  (6,0x23cb0,0x23d32,0x23d41,0x23d93)]:
  for index,layout in enumerate(layouts):
   u=machine();u.mem_write(0x56f37,bytes([len(layout)]))
   for i,(hp,endurance,level) in enumerate(layout,1):
    enemy=bytearray(35);enemy[20],enemy[29]=endurance,level
    struct.pack_into('<h',enemy,30,hp);u.mem_write(0x56f15+35*i,bytes(enemy))
   run(u,start,end)
   hp_sum=short(u,0x67ffc);threshold=short(u,0x67ffa)
   def stop(vm,address,size,data):
    if address in (trial-header,fallback-header):vm.emu_stop()
   hook=u.hook_add(UC_HOOK_CODE,stop)
   u.emu_start(end-header,fallback-header+1,count=40);u.hook_del(hook)
   ip=0x10000+u.reg_read(UC_X86_REG_IP)+header;assert ip in (trial,fallback)
   eligible=ip==trial
   u.mem_write(0x67ff6,struct.pack('<HH',0x6f38,0x5000))
   u.mem_write(0x56f38+19,bytes([20]))
   run(u,0x2392e if mode==5 else 0x23b1a,0x2394a if mode==5 else 0x23b36)
   self_threshold=u.reg_read(UC_X86_REG_AX)
   run(u,0x23a6e if mode==5 else 0x23d67,0x23a8a if mode==5 else 0x23d83)
   amount=u.reg_read(UC_X86_REG_AX)
   if eligible:
    for num in range(1,len(layout)+1):
     word(u,0x68008,num);word(u,0x68006,amount);run(u,0x234f8,0x2358f)
   after=[short(u,0x56f15+35*num+30) for num in range(1,len(layout)+1)]
   groups.append(dict(mode=mode,index=index,enemies=[dict(hp=h,endurance=e,level=l) for h,e,l in layout],
    hpSum=hp_sum,threshold=threshold,healEligible=eligible,selfThreshold=self_threshold,healAmount=amount,afterHp=after))
 return dict(source='Unmodified LORE.EXE enemy magic variance/defence/stores, complete enemycure state branches, castattack threshold/recovery arithmetic and both mode5/6 aggregate loops and eligibility branches executed by Unicorn x86-16. Synthetic records/random results; original executable unchanged.',
  executableSha256=hashlib.sha256(exe).hexdigest(),
  fragments=[dict(name=n,startFileOffset=a,endFileOffset=b,codeHex=exe[a:b].hex()) for n,a,b in FRAGMENTS],
  magic=magic,cures=cures,thresholds=thresholds,heals=heals,groups=groups,
  scope='Instruction arithmetic, stores and specified branch decisions only. UI, source RNG seed/whole stream and complete battle/save/new-game-to-ending parity remain separate gates. power32767 is an integer parameter boundary, not a normal generated spell. Native division faults use engine StateError; DOS error-screen presentation is not reproduced.')


def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--check',action='store_true');a=p.parse_args()
 if a.check:
  f=json.loads(OUTPUT.read_text());exe=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
  assert hashlib.sha256(exe).hexdigest()==f['executableSha256']
  assert [(x['name'],x['startFileOffset'],x['endFileOffset']) for x in f['fragments']]==FRAGMENTS
  for x in f['fragments']:assert exe[x['startFileOffset']:x['endFileOffset']].hex()==x['codeHex']
  print('Original enemy magic/cure/AI fragments are current')
 else:OUTPUT.write_text(json.dumps(build(),ensure_ascii=False,indent=2)+'\n')


if __name__=='__main__':main()

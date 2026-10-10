"""Original LORESUB Scroll control, native map reads and ordered draw/sound calls.

BGI/CRT adapters are supplied. Native map indexing, keyboard flushing, weather
selection, darkness,9x9 iteration and conditional CHARA pairs execute unchanged.
Only declared coordinate/font inputs are used; VGA scanout/PIT timing excluded.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path
from audit_lorespec import decode
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'test/fixtures/dos_scroll.json'

def build():
 from unicorn import Uc,UC_ARCH_X86,UC_MODE_16,UC_HOOK_CODE
 from unicorn.x86_const import UC_X86_REG_CS,UC_X86_REG_DS,UC_X86_REG_SS,UC_X86_REG_SP,UC_X86_REG_BP,UC_X86_REG_IP,UC_X86_REG_AX
 exe=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes();h=struct.unpack_from('<H',exe,8)[0]*16;base=0x24660
 vm=Uc(UC_ARCH_X86,UC_MODE_16);vm.mem_map(0,0x90000);vm.mem_write(0,exe[h:]);trace=[];ctx={}
 calls={(0x2d04,0x131f):('active',1),(0x2d04,0x1305):('visible',1),(0x2d04,0xc79):('fill',2),(0x2d04,0x152c):('bar',4),(0x2d04,0x1620):('color',1),(0x306b,0x2c7):('tone',1),(0x306b,0x29c):('delay',1),(0x306b,0x2f4):('silence',0)}
 def hook(u,address,size,_):
  off=address+h
  if off==ctx['end']:u.emu_stop();return
  raw=exe[off:off+size]
  if raw[:1]!=b'\x9a':return
  target,seg=struct.unpack_from('<HH',raw,1);sp=u.reg_read(UC_X86_REG_SP)
  if(seg,target)==(0x30cd,0x4df):args=0
  elif(seg,target)==(0x306b,0x2fb):
   ready=bool(ctx['queue']);trace.append(['ready',ready]);u.reg_write(UC_X86_REG_AX,int(ready));args=0
  elif(seg,target)==(0x306b,0x30d):
   key=ctx['queue'].pop(0);trace.append(['read',key]);u.reg_write(UC_X86_REG_AX,key);args=0
  elif(seg,target)==(0x2d04,0xe52):
   op,offset,ds,y,x=struct.unpack('<5H',u.mem_read(0x60000+sp,10));assert ds in {0x7000,0x8000} and offset%246==0
   trace.append(['put','font' if ds==0x7000 else 'chara',x,y,offset//246,op]);args=10
  elif(seg,target)==(0x2ab5,0x8fd):
   offset,ds,y,x=struct.unpack('<4H',u.mem_read(0x60000+sp,8));p=ds*16+offset;n=u.mem_read(p,1)[0]
   trace.append(['text',x,y,decode(bytes(u.mem_read(p+1,n)))]);args=8
  elif(seg,target) in calls:
   name,count=calls[(seg,target)];values=list(struct.unpack('<'+'H'*count,u.mem_read(0x60000+sp,count*2)))[::-1] if count else []
   trace.append([name,*values]);args=count*2
  else:raise AssertionError((hex(off),hex(seg),hex(target)))
  u.reg_write(UC_X86_REG_SP,sp+args);u.reg_write(UC_X86_REG_IP,address+5-base)
 vm.hook_add(UC_HOOK_CODE,hook)
 def reset():
  for r,v in [(UC_X86_REG_CS,0x2466),(UC_X86_REG_DS,0x5000),(UC_X86_REG_SS,0x6000),(UC_X86_REG_SP,0x7e00),(UC_X86_REG_BP,0x8000)]:vm.reg_write(r,v)
 for x in range(1,101):
  for y in range(1,101):vm.mem_write(0x53d43+x*100+y,bytes([(x*7+y*13)%55+1]))
 rows=[]
 for position,torch in [(2,0),(2,255),(0,0),(1,0)]:
  for weather in range(6):
   for character in [False,True]:
    for sound in [False,True]:
     for direction in range(4):
      index=len(rows);x,y=[(6,6),(51,31),(95,95)][index%3];page=index%2;queue=[[],[0,72,49],[32,13]][index%3];face=direction+(0 if position==1 else 4)
      reset();ctx.clear();ctx.update(end=0x29cf5,queue=[]);trace.clear()
      vm.mem_write(0x539bb,b'\0');vm.mem_write(0x53d98,b'\1\10\0');vm.mem_write(0x67e00,struct.pack('<3H',0,0,weather))
      vm.emu_start(0x29c63-h,0x29cf5-h,count=10000)
      style=list(vm.mem_read(0x53d98,3));assert vm.mem_read(0x539bb,1)[0]==weather
      reset();ctx.update(end=0x29c3d,queue=list(queue));trace.clear()
      vm.mem_write(0x539ac,struct.pack('<2H',x,y));vm.mem_write(0x539bc,bytes([position]));vm.mem_write(0x564d2,bytes([torch]));vm.mem_write(0x539ba,bytes([sound]));vm.mem_write(0x59c10,bytes([page]));vm.mem_write(0x53d9c,bytes([face]))
      vm.mem_write(0x53da0,struct.pack('<4H',0,0x7000,0,0x8000));vm.mem_write(0x67e00,struct.pack('<3H',0,0,character))
      vm.emu_start(0x29ab5-h,0x29c3d-h,count=100000)
      assert vm.reg_read(UC_X86_REG_SP)==0x7e00 and not ctx['queue']
      rows.append(dict(position=position,torch=torch,weather=weather,character=character,sound=sound,direction=direction,face=face,x=x,y=y,page=page,queue=queue,style=style,afterPage=vm.mem_read(0x59c10,1)[0],trace=list(trace)))
 return dict(scope=__doc__,exeSha256=hashlib.sha256(exe).hexdigest(),fragments=[dict(start=a,end=z,sha256=hashlib.sha256(exe[a:z]).hexdigest()) for a,z in [(0x29c63,0x29cf5),(0x29ab5,0x29c3d)]],cases=rows)
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args();data=build()
 if args.check:assert json.loads(OUT.read_text())==data,'Scroll fixture drift'
 else:OUT.write_text(json.dumps(data,separators=(',',':'))+'\n')

"""LORECRET.Last closed optional map-erase/IOResult/Halt branch."""
import json,struct,hashlib
from pathlib import Path
from audit_lorespec import decode
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'test/fixtures/dos_creation_erase.json'
def build():
 from unicorn import Uc,UC_ARCH_X86,UC_MODE_16,UC_HOOK_CODE,UC_HOOK_INTR
 from unicorn.x86_const import UC_X86_REG_CS,UC_X86_REG_DS,UC_X86_REG_SS,UC_X86_REG_SP,UC_X86_REG_BP,UC_X86_REG_IP,UC_X86_REG_AX,UC_X86_REG_DX,UC_X86_REG_EFLAGS
 b=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes();h=struct.unpack_from('<H',b,8)[0]*16;base=0x3110
 vm=Uc(UC_ARCH_X86,UC_MODE_16);vm.mem_map(0,0x80000);vm.mem_write(0,b[h:]);trace=[];ctx={}
 def string(seg,offset):
  p=seg*16+offset;n=vm.mem_read(p,1)[0];return decode(bytes(vm.mem_read(p+1,n)))
 def hook(u,address,size,_):
  off=address+h;sp=u.reg_read(UC_X86_REG_SP)
  if off==0xb444:u.emu_stop();return
  raw=b[off:off+size]
  if raw[:1]!=b'\x9a':return
  target,seg=struct.unpack_from('<HH',raw,1)
  if(seg,target) in {(0x30cd,0xac2),(0x30cd,0xbf2),(0x30cd,0xb4f)}:return
  if(seg,target)==(0x30cd,0x1399):
   offset,ds,fileoff,fileseg=struct.unpack('<4H',u.mem_read(0x60000+sp,8));ctx['name']=string(ds,offset);trace.append(['assign',ctx['name']]);return
  elif(seg,target)==(0x30cd,0x15d6):return
  elif(seg,target)==(0x30cd,0x4a2):trace.append(['ioResult',struct.unpack('<H',u.mem_read(0x5364a,2))[0]]);return
  elif(seg,target)==(0x2d04,0xa4d):trace.append(['closeGraph']);args=0
  elif(seg,target) in {(0x306b,0x257),(0x306b,0x271)}:
   value=struct.unpack('<H',u.mem_read(0x60000+sp,2))[0];trace.append(['textColor' if target==0x257 else 'background',value]);args=2
  elif(seg,target)==(0x306b,0x1c0):trace.append(['clear']);args=0
  elif(seg,target)==(0x30cd,0x917):
   width,offset,ds,fileoff,fileseg=struct.unpack('<5H',u.mem_read(0x60000+sp,10));trace.append(['writeLine',string(ds,offset)]);args=6
  elif(seg,target) in {(0x30cd,0x848),(0x30cd,0x4a9)}:args=0 if target==0x4a9 else 4
  elif(seg,target)==(0x30cd,0xe9):trace.append(['halt',u.reg_read(UC_X86_REG_AX)]);u.emu_stop();return
  else:raise AssertionError((hex(off),hex(seg),hex(target)))
  u.reg_write(UC_X86_REG_SP,sp+args);u.reg_write(UC_X86_REG_IP,address+5-base)
 def interrupt(u,number,_):
  assert number==0x21 and u.reg_read(UC_X86_REG_AX)>>8==0x41
  pointer=u.reg_read(UC_X86_REG_DS)*16+u.reg_read(UC_X86_REG_DX)
  name=bytes(u.mem_read(pointer,80)).split(b'\0')[0].decode()
  assert name==ctx['name'];trace.append(['erase',name])
  u.reg_write(UC_X86_REG_AX,ctx['error'])
  u.reg_write(UC_X86_REG_EFLAGS,(u.reg_read(UC_X86_REG_EFLAGS)&~1)|bool(ctx['error']))
 vm.hook_add(UC_HOOK_CODE,hook);vm.hook_add(UC_HOOK_INTR,interrupt);rows=[]
 for slot in range(1,5):
  for exists in [False,True]:
   for error in [0,2,5,255,65535]:
    for r,v in [(UC_X86_REG_CS,0x311),(UC_X86_REG_DS,0x5000),(UC_X86_REG_SS,0x6000),(UC_X86_REG_SP,0x7e00),(UC_X86_REG_BP,0x8000)]:vm.reg_write(r,v)
    trace.clear();ctx.clear();ctx.update(error=error);vm.mem_write(0x5364a,b'\0\0')
    vm.mem_write(0x539c6,b'\x01X' if exists else b'\0');vm.mem_write(0x5366b,bytes([48+slot]))
    vm.emu_start(0xb3ae-h,0xb444-h,count=10000)
    assert trace==[] if not exists else trace[0]==['assign',f'Save{slot}.map'],trace
    assert vm.reg_read(UC_X86_REG_IP)==(0xb43f if exists and error else 0xb444)-h-base
    assert vm.reg_read(UC_X86_REG_SP)==0x7e00
    rows.append(dict(slot=slot,exists=exists,error=error,trace=list(trace)))
 return dict(exeSha256=hashlib.sha256(b).hexdigest(),start=0xb3ae,end=0xb444,fragmentSha256=hashlib.sha256(b[0xb3ae:0xb444]).hexdigest(),cases=rows)
if __name__=='__main__':
 import argparse
 parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args();data=build()
 if args.check:assert json.loads(OUT.read_text())==data,'creation erase fixture drift'
 else:OUT.write_text(json.dumps(data,separators=(',',':'))+'\n')

"""Original LORESUB Clear/PressAnyKey, AuxPrint/message and Set_All panel calls.

Only BGI/CRT operations and input bytes are platform adapters. Original string
copies, keyboard-flush loops, scan consumption, cursor/page stores and border
loops execute unchanged. Physical BIOS queue timing and glyph pixels excluded.
"""
import argparse, hashlib, json, struct
from pathlib import Path
from audit_lorespec import decode
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'test/fixtures/dos_common_screen.json'
def build():
 from unicorn import Uc,UC_ARCH_X86,UC_MODE_16,UC_HOOK_CODE
 from unicorn.x86_const import UC_X86_REG_CS,UC_X86_REG_DS,UC_X86_REG_SS,UC_X86_REG_SP,UC_X86_REG_BP,UC_X86_REG_AX,UC_X86_REG_IP
 b=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes();h=struct.unpack_from('<H',b,8)[0]*16;base=0x24660
 vm=Uc(UC_ARCH_X86,UC_MODE_16);vm.mem_map(0,0x90000);vm.mem_write(0,b[h:]);ctx={};trace=[]
 def hook(u,address,size,_):
  off=address+h
  if off==ctx['end']:u.emu_stop();return
  raw=b[off:off+size]
  if raw[:1]!=b'\x9a':return
  target,seg=struct.unpack_from('<HH',raw,1);sp=u.reg_read(UC_X86_REG_SP)
  if(seg,target)==(0x30cd,0xadc):return
  if(seg,target)==(0x30cd,0x4df):args=0
  elif(seg,target)==(0x306b,0x2fb):
   ready=bool(ctx['pending']);trace.append(['ready',ready]);u.reg_write(UC_X86_REG_AX,int(ready));args=0
  elif(seg,target)==(0x306b,0x30d):
   queue=ctx['pending'] if ctx['pending'] else ctx['fresh'];value=queue.pop(0);trace.append(['read',value]);u.reg_write(UC_X86_REG_AX,value);args=0
  elif(seg,target)==(0x2ab5,0x150):
   y,x=struct.unpack('<2H',u.mem_read(0x60000+sp,4));trace.append(['goto',x,y]);args=4
  elif(seg,target)==(0x2ab5,0x8cc):
   off,ds=struct.unpack('<2H',u.mem_read(0x60000+sp,4));p=ds*16+off;n=u.mem_read(p,1)[0];trace.append(['text',decode(bytes(u.mem_read(p+1,n)))]);args=4
  elif(seg,target)==(0x2ab5,0x959):
   off,ds,y,x=struct.unpack('<4H',u.mem_read(0x60000+sp,8));p=ds*16+off;n=u.mem_read(p,1)[0];trace.append(['prompt',x,y,decode(bytes(u.mem_read(p+1,n)))]);args=8
  elif(seg,target)==(0x2ab5,0xc3f):
   off,ds,y,x=struct.unpack('<4H',u.mem_read(0x60000+sp,8));p=ds*16+off;n=u.mem_read(p,1)[0];trace.append(['bold',x,y,decode(bytes(u.mem_read(p+1,n)))]);args=8
  elif(seg,target) in {(0x2d04,0x131f),(0x2d04,0x1620),(0x2d04,0x152c),(0x2d04,0x1305),(0x2d04,0xc79),(0x2d04,0xbf8),(0x2d04,0xc32),(0x2d04,0x14e4)}:
   name,count={(0x2d04,0x131f):('active',1),(0x2d04,0x1620):('color',1),(0x2d04,0x152c):('bar',4),(0x2d04,0x1305):('visible',1),(0x2d04,0xc79):('fill',2),(0x2d04,0xbf8):('style',3),(0x2d04,0xc32):('rectangle',4),(0x2d04,0x14e4):('line',4)}[(seg,target)];trace.append([name,*list(struct.unpack('<'+'H'*count,u.mem_read(0x60000+sp,count*2)))[::-1]]);args=count*2
  else:raise AssertionError((hex(off),hex(seg),hex(target)))
  u.reg_write(UC_X86_REG_SP,sp+args);u.reg_write(UC_X86_REG_IP,address+5-base)
 vm.hook_add(UC_HOOK_CODE,hook);rows=[]
 for page in [0,1]:
  for pending in [[],[32,13],[0,72,97]]:
   for fresh in [[13],[27],[32],[9],[8],[97],[0,72],[0,80],[0,75],[0,77]]:
    for r,v in [(UC_X86_REG_CS,0x2466),(UC_X86_REG_DS,0x5000),(UC_X86_REG_SS,0x6000),(UC_X86_REG_SP,0x7e00),(UC_X86_REG_BP,0x8000)]:vm.reg_write(r,v)
    vm.mem_write(0x59c10,bytes([page]));vm.mem_write(0x53d9b,b'\xff');vm.mem_write(0x59c14,struct.pack('<H',999));ctx.update(end=0x29aaf,pending=list(pending),fresh=list(fresh));trace.clear()
    vm.emu_start(0x29a5f-h,0x29aaf-h,count=10000)
    assert not ctx['pending'] and not ctx['fresh'] and vm.reg_read(UC_X86_REG_SP)==0x7e00
    rows.append(dict(page=page,pending=pending,fresh=fresh,trace=list(trace),c=vm.mem_read(0x5366a,1)[0],afterPage=vm.mem_read(0x59c10,1)[0],yline=vm.mem_read(0x53d9b,1)[0],hany=struct.unpack('<H',vm.mem_read(0x59c14,2))[0]))
 wait=rows;rows=[]
 for entry,end,kind in [(0x29d8f,0x29ddf,'aux'),(0x29e5c,0x29ec6,'message')]:
  for page in [0,1]:
   for initialY in [0,32,100]:
    for newline in [False,True] if kind=='aux' else [True]:
     for r,v in [(UC_X86_REG_CS,0x2466),(UC_X86_REG_DS,0x5000),(UC_X86_REG_SS,0x6000),(UC_X86_REG_SP,0x7e00),(UC_X86_REG_BP,0x8000)]:vm.reg_write(r,v)
     vm.mem_write(0x59c10,bytes([page]));vm.mem_write(0x53d9b,b'\xff');vm.mem_write(0x59c14,struct.pack('<H',initialY));vm.mem_write(0x70100,b'\x06SOURCE')
     vm.mem_write(0x67e00,struct.pack('<6H',0,0,int(newline),0x100,0x7000,12) if kind=='aux' else struct.pack('<5H',0,0,0x100,0x7000,12))
     ctx.update(end=end,pending=[],fresh=[]);trace.clear();vm.emu_start(entry-h,end-h,count=10000)
     rows.append(dict(kind=kind,page=page,hany=initialY,newline=newline,trace=list(trace),afterPage=vm.mem_read(0x59c10,1)[0],afterHany=struct.unpack('<H',vm.mem_read(0x59c14,2))[0]))
 for initialY in [0,32,100]:
  for page in [0,1]:
   parts=[' 나는 LORE 성의 성주 ','Lord Ahn',' 이오.']
   for n,text in enumerate(parts):
    raw=text.encode('johab');vm.mem_write(0x70100+n*256,bytes([len(raw)])+raw)
   for r,v in [(UC_X86_REG_CS,0x2466),(UC_X86_REG_DS,0x5000),(UC_X86_REG_SS,0x6000),(UC_X86_REG_SP,0x7e00),(UC_X86_REG_BP,0x8000)]:vm.reg_write(r,v)
   vm.mem_write(0x59c10,bytes([page]));vm.mem_write(0x59c14,struct.pack('<H',initialY));vm.mem_write(0x67e00,struct.pack('<10H',0,0,0x300,0x7000,0x200,0x7000,0x100,0x7000,11,7))
   ctx.update(end=0x29e58,pending=[],fresh=[]);trace.clear();vm.emu_start(0x29de3-h,0x29e58-h,count=10000)
   rows.append(dict(kind='cprint',page=page,hany=initialY,parts=parts,trace=list(trace),afterHany=struct.unpack('<H',vm.mem_read(0x59c14,2))[0]))
 prints=rows
 for r,v in [(UC_X86_REG_CS,0x2466),(UC_X86_REG_DS,0x5000),(UC_X86_REG_SS,0x6000),(UC_X86_REG_SP,0x7e00),(UC_X86_REG_BP,0x8000)]:vm.reg_write(r,v)
 ctx.update(end=0x2fb9a,pending=[],fresh=[]);trace.clear();vm.emu_start(0x2f7c8-h,0x2fb9a-h,count=100000);borders=list(trace)
 return dict(scope=__doc__,exeSha256=hashlib.sha256(b).hexdigest(),wait=wait,print=prints,borders=borders)
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args();data=build()
 if args.check:assert json.loads(OUT.read_text())==data
 else:OUT.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
if __name__=='__main__':main()

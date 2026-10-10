"""Native LOREHELP box, scrolling and title-intro instruction traces."""
import json,struct,hashlib,base64
from pathlib import Path
from audit_lorespec import decode
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'test/fixtures/dos_title_intro.json'

def build():
 from unicorn import Uc,UC_ARCH_X86,UC_MODE_16,UC_HOOK_CODE
 from unicorn.x86_const import UC_X86_REG_CS,UC_X86_REG_DS,UC_X86_REG_SS,UC_X86_REG_SP,UC_X86_REG_BP,UC_X86_REG_IP,UC_X86_REG_AX
 b=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes();h=struct.unpack_from('<H',b,8)[0]*16;base=0x1810
 vm=Uc(UC_ARCH_X86,UC_MODE_16);vm.mem_map(0,0xb0000);vm.mem_write(0,b[h:]);trace=[];ctx={}
 # Original unit data, not synthetic paragraph text.
 paragraph_data=b[0x37752:0x37752+25*256]
 vm.mem_write(0x50002,paragraph_data)
 paragraphs=[decode(paragraph_data[i*256+1:i*256+1+paragraph_data[i*256]]) for i in range(25)]
 calls={(0x2d04,0xc79):('fill',2),(0x2d04,0x152c):('bar',4),(0x2d04,0xbc0):('move',2),(0x2d04,0xbdd):('line',2),(0x2d04,0x1620):('color',1),(0x2d04,0xdf1):('palette',2),(0x2466,0):('rgb',4),(0x306b,0x29c):('delay',1)}
 def hook(u,address,size,_):
  off=address+h
  if off==ctx.get('end'):u.emu_stop();return
  raw=b[off:off+size];sp=u.reg_read(UC_X86_REG_SP)
  if raw[:1]==b'\xe8':
   target=address+3+struct.unpack('<h',raw[1:3])[0]
   if target==0x6ec8-h and ctx['kind'] in ('lift','story'):
    mode=struct.unpack('<H',u.mem_read(0x60000+sp,2))[0];trace.append(['scroll',mode]);u.reg_write(UC_X86_REG_SP,sp+2);u.reg_write(UC_X86_REG_IP,address+3-base);return
  if raw[:1]!=b'\x9a':return
  target,seg=struct.unpack_from('<HH',raw,1)
  if (seg,target)==(0x30cd,0x4df):args=0
  elif (seg,target)==(0x30cd,0xd77):return
  elif (seg,target)==(0x306b,0x2fb):
   ready=ctx['polls']>=ctx['falsePolls'];ctx['polls']+=1;trace.append(['ready',ready]);u.reg_write(UC_X86_REG_AX,int(ready));args=0
  elif (seg,target)==(0x2ab5,0x9c3):
   values=struct.unpack('<5H',u.mem_read(0x60000+sp,10));bold,offset,ds,y,x=values
   assert ds==0x5000 and (offset-2)%256==0
   trace.append(['text',x,y,(offset-2)//256+1,bool(bold)]);args=10
  elif (seg,target) in calls:
   name,count=calls[(seg,target)];values=list(struct.unpack('<'+'H'*count,u.mem_read(0x60000+sp,count*2)))[::-1]
   if name=='rgb':values=[v&255 for v in values]
   trace.append([name,*values]);args=count*2
  else:raise AssertionError((hex(off),hex(seg),hex(target)))
  u.reg_write(UC_X86_REG_SP,sp+args);u.reg_write(UC_X86_REG_IP,address+5-base)
 vm.hook_add(UC_HOOK_CODE,hook)
 spans={'box':(0x6b80,0x6d33),'messageBox':(0x6d36,0x6ddd),'lift':(0x74da,0x7561),'story':(0x7613,0x77c8),'nestedBox':(0x7408,0x744f),'nestedMessageBox':(0x75c2,0x7613),'scroll':(0x6ec8,0x6f85)}
 rows=[]
 for kind,(a,z) in spans.items():
  configs=[dict(shadow=s,bold=v) for s in [False,True] for v in [False,True]] if kind=='box' else [dict(shadow=s) for s in [False,True]] if kind=='messageBox' else [dict(falsePolls=n) for n in [0,1,14,15,16,17,127,255,399,9999]] if kind=='story' else [dict(mode=n) for n in range(256)] if kind=='scroll' else [{}]
  for cfg in configs:
   for r,v in [(UC_X86_REG_CS,0x181),(UC_X86_REG_DS,0x5000),(UC_X86_REG_SS,0x6000),(UC_X86_REG_SP,0x7e00),(UC_X86_REG_BP,0x8000)]:vm.reg_write(r,v)
   trace.clear();ctx.clear();ctx.update(kind=kind,polls=0,falsePolls=cfg.get('falsePolls',9999),end=z)
   if kind=='scroll':
    vm.mem_write(0x67e00,struct.pack('<2H',0,cfg['mode']));vm.mem_write(0x59c10,b'\0')
    vm.mem_write(0xa0000,bytes((i*37^(i>>8))&255 for i in range(65536)))
   if kind=='box':vm.mem_write(0x67e00,struct.pack('<8H',0,int(cfg['bold']),int(cfg['shadow']),4,590,510,45,30))
   if kind=='messageBox':vm.mem_write(0x67e00,struct.pack('<7H',0,int(cfg['shadow']),4,590,510,45,30))
   vm.emu_start(a-h,z-h,count=2000000)
   assert vm.reg_read(UC_X86_REG_IP)==z-h-base,(kind,hex(vm.reg_read(UC_X86_REG_IP)),hex(z-h-base))
   row=dict(kind=kind,**cfg,trace=list(trace))
   if kind=='scroll':row['planeSha256']=hashlib.sha256(vm.mem_read(0xa0000,65536)).hexdigest();row['plane']=base64.b64encode(vm.mem_read(0xa0000,38400)).decode() if cfg['mode']<2 else None
   rows.append(row)
 return dict(exeSha256=hashlib.sha256(b).hexdigest(),paragraphs=paragraphs,fragments=[dict(kind=k,start=a,end=z,sha256=hashlib.sha256(b[a:z]).hexdigest()) for k,(a,z) in spans.items()],cases=rows)
if __name__=='__main__':
 import argparse
 parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true')
 args=parser.parse_args();data=build()
 if args.check:assert json.loads(OUT.read_text())==data,'title intro fixture drift'
 else:OUT.write_text(json.dumps(data,separators=(',',':'))+'\n')

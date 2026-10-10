"""Unchanged LORE startup flags/loops and LOREHELP CLI help/Text_Fading.

Command-line values, DOS search/rename/exec and audio/graphics operations are
platform inputs/calls; native string comparisons/copies, branches, loop stores
and Text_Fading timing execute. Native UnSound executes for both End.cmd cases.
Main/PlaySong bodies are intercepted; two outer cycles establish dispatch only,
not whole-game playback, DOS drivers, AdLib registers or physical glyph pixels.
"""
import argparse,hashlib,json,struct
from pathlib import Path
from audit_lorespec import decode
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'test/fixtures/dos_startup.json'
def build():
 from unicorn import Uc,UC_ARCH_X86,UC_MODE_16,UC_HOOK_CODE,UC_HOOK_INTR
 from unicorn.x86_const import UC_X86_REG_CS,UC_X86_REG_DS,UC_X86_REG_SS,UC_X86_REG_SP,UC_X86_REG_BP,UC_X86_REG_AX,UC_X86_REG_DX,UC_X86_REG_IP,UC_X86_REG_CX
 b=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes();h=0x5370
 vm=Uc(UC_ARCH_X86,UC_MODE_16);vm.mem_map(0,0x90000);vm.mem_write(0,b[h:]);ctx={};trace=[]
 def textat(ds,off):
  p=ds*16+off;n=vm.mem_read(p,1)[0];return decode(bytes(vm.mem_read(p+1,n)))
 def put(ds,off,text):
  raw=text.encode('ascii');vm.mem_write(ds*16+off,bytes([len(raw)])+raw)
 def hook(u,address,size,_):
  off=address+h
  if off in ctx.get('ends',[]):ctx['stop']=off;u.emu_stop();return
  raw=b[off:off+size]
  if raw[:1]!=b'\x9a':return
  target,seg=struct.unpack_from('<HH',raw,1);sp=u.reg_read(UC_X86_REG_SP);mem=lambda n:struct.unpack('<'+'H'*n,u.mem_read(0x60000+sp,n*2))
  if(seg,target) in {(0x30cd,0xadc),(0x30cd,0xbc7),(0x2466,0x6215)}:return
  if(seg,target) in {(0x30cd,0x4df),(0x30cd,0x4a9)}:args=0
  elif(seg,target)==(0x30cd,0x16c2):trace.append(['argc',len(ctx['argv'])]);u.reg_write(UC_X86_REG_AX,len(ctx['argv']));args=0
  elif(seg,target)==(0x30cd,0x1673):
   index,dest,ds=mem(3);trace.append(['argv',index]);put(ds,dest,ctx['argv'][index-1]);args=2
  elif(seg,target)==(0x304a,0x130):
   directory,directoryseg,name,nameseg,dest,ds=mem(6);name=textat(nameseg,name);exists=ctx['endExists'] if name.lower()=='end.cmd' else ctx['initExists'];trace.append(['search',name,exists]);put(ds,dest,name if exists else '');args=8
  elif(seg,target)==(0x304a,0x199):
   off,ds,dest,segout=mem(4);trace.append(['env',textat(ds,off)]);put(segout,dest,'COMMAND.COM');args=4
  elif(seg,target)==(0x304a,0x97):
   cmd,cmdseg,path,pathseg=mem(4);trace.append(['exec',textat(pathseg,path),textat(cmdseg,cmd)]);args=8
  elif(seg,target)==(0x30cd,0x1399):
   name,nameseg,fileoff,fileseg=mem(4);trace.append(['assign',textat(nameseg,name)]);args=8
  elif(seg,target)==(0x30cd,0x15ed):
   name,nameseg,fileoff,fileseg=mem(4);trace.append(['rename',textat(nameseg,name)]);args=8
  elif(seg,target)==(0x2b8b,0x304):trace.append(['initSound']);u.mem_write(0x5de2a,struct.pack('<H',ctx['error']));args=0
  elif(seg,target)==(0x181,0x70e):
   trace.append(['title'])
   if ctx['argv'] and ctx['argv'][0] in ['/?','-?','?']:return
   args=0
  elif(seg,target)==(0x2d04,0x746):
   path,pathseg,j,jseg,i,iseg=mem(6);trace.append(['graph',struct.unpack('<H',u.mem_read(iseg*16+i,2))[0],struct.unpack('<H',u.mem_read(jseg*16+j,2))[0]]);args=12
  elif(seg,target)==(0x30cd,0x23f):
   count=mem(1)[0];trace.append(['alloc',count]);u.reg_write(UC_X86_REG_AX,0);u.reg_write(UC_X86_REG_DX,0x7000+ctx['alloc']*0x1000);ctx['alloc']+=1;args=2
  elif(seg,target)==(0x2ab5,0xa):trace.append(['font',mem(1)[0]]);args=2
  elif(seg,target)==(0x2466,0x5d5f):trace.append(['setAll']);put(0x5000,0x39c6,'Music2.Bgm');args=0
  elif(seg,target)==(0x25d,0x6c7):
   if ctx['loops']==2:u.emu_stop();return
   ctx['loops']+=1;trace.append(['main']);args=0
  elif(seg,target)==(0x2b8b,0x6bc):
   name,ds=mem(2);trace.append(['bank',textat(ds,name)]);args=4
  elif(seg,target)==(0x2b8b,0xded):
   if ctx['loops']==2:u.emu_stop();return
   name,ds=mem(2);trace.append(['song',textat(ds,name),u.mem_read(0x5de2c,1)[0]]);args=4
  elif(seg,target)==(0x2b8b,0x12b1):
   ip,cs=mem(2);trace.append(['play',cs,ip]);ctx['loops']+=1;put(0x5000,0x39c6,'Music3.Bgm');args=4
  elif(seg,target)==(0x2b8b,0x1283):trace.append(['playOff']);args=0
  elif(seg,target)==(0x2466,0):trace.append(['rgb',*list(mem(4))[::-1]]);args=8
  elif(seg,target)==(0x306b,0x257):trace.append(['color',mem(1)[0]]);args=2
  elif(seg,target)==(0x306b,0x2fb):
   ready=ctx['delays']>=ctx['delayLimit'];trace.append(['ready',ready]);u.reg_write(UC_X86_REG_AX,int(ready));args=0
  elif(seg,target)==(0x306b,0x29c):trace.append(['delay',mem(1)[0]]);ctx['delays']+=1;args=2
  elif(seg,target)==(0x306b,0x24b):u.reg_write(UC_X86_REG_AX,ctx['y']);args=0
  elif(seg,target)==(0x306b,0x213):y,x=mem(2);trace.append(['goto',x,y]);args=4
  elif(seg,target)==(0x30cd,0x917):
   width,name,ds,file,fileseg=mem(5);trace.append(['write',textat(ds,name)]);args=6
  elif(seg,target) in {(0x30cd,0x848),(0x30cd,0x86c)}:
   if target==0x848:trace.append(['newline']);ctx['y']+=1
   args=4
  elif(seg,target)==(0x30cd,0xe9):trace.append(['halt',u.reg_read(UC_X86_REG_AX)]);u.emu_stop();return
  else:raise AssertionError((hex(off),hex(seg),hex(target)))
  u.reg_write(UC_X86_REG_SP,sp+args);u.reg_write(UC_X86_REG_IP,address+5-u.reg_read(UC_X86_REG_CS)*16)
 def intr(u,number,_):
  assert number==0x10;trace.append(['cursor',u.reg_read(UC_X86_REG_CX)])
 vm.hook_add(UC_HOOK_CODE,hook);vm.hook_add(UC_HOOK_INTR,intr)
 def reset(cs,**kwargs):
  for r,v in [(UC_X86_REG_CS,cs),(UC_X86_REG_DS,0x5000),(UC_X86_REG_SS,0x6000),(UC_X86_REG_SP,0x7e00),(UC_X86_REG_BP,0x8000)]:vm.reg_write(r,v)
  ctx.clear();ctx.update(argv=[],initExists=False,endExists=False,error=0,alloc=0,loops=0,delays=0,delayLimit=999,y=1,ends=[],**kwargs);trace.clear()
 main=[]
 for argv in [[],['/m'],['/M'],['/g'],['/G'],['/c'],['/C'],['/?'],['-?'],['?'],['x'],['/g','/m'],['/m','/g'],['x','/m'],[' /g'],['/gg']]:
  for exists in [False,True]:
   for error in [0,1,65535]:
    reset(0);ctx.update(argv=argv,initExists=exists,error=error)
    vm.emu_start(0x5425-h,0x55bb-h,count=100000)
    main.append(dict(argv=argv,initExists=exists,error=error,adlib=bool(vm.mem_read(0x539b9,1)[0]),trace=list(trace)))
 title=[]
 for arg in ['', '/c','/C','/?','-?','?','/g','/M','/cc',' /c']:
  for exists in [False,True]:
   for limit in [0,1,43,64,129,999]:
    reset(0x181);ctx.update(endExists=exists,delayLimit=limit,ends=[0x73dc,0x7908]);put(0x5000,0x367a,arg)
    vm.emu_start(0x728e-h,0x7910-h,count=100000)
    title.append(dict(arg=arg,endExists=exists,delayLimit=limit,stop=ctx.get('stop','halt'),c=vm.mem_read(0x5366a,1)[0],trace=list(trace)))
 return dict(scope=__doc__,exeSha256=hashlib.sha256(b).hexdigest(),main=main,title=title)
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args();data=build()
 if args.check:assert data==json.loads(OUT.read_text())
 else:OUT.write_text(json.dumps(data,ensure_ascii=False,separators=(',',':'))+'\n')
if __name__=='__main__':main()

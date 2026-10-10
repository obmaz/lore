"""Original FindGold short-string conversion, both page prints and longint add.

Clear, SetActivePage and Print are intercepted platform calls. Original Str,
short-string concatenations, page/hany/i stores and gold arithmetic execute.
This evidence does not establish Clear pixels or actual BGI page rendering.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'test/fixtures/dos_findgold.json'
START,END=0x2c391,0x2c419
MONEY=[-2147483648,-1000000000,-123456789,-100000000,-99999999,-1,0,400,600,1000,1500,2500,4000,5000,6000,99999999,100000000,123456789,999999999,1000000000,1234567890,2147483647]
GOLD=[-2147483648,-1,0,1,2147483647]

def build():
    from unicorn import Uc,UC_ARCH_X86,UC_MODE_16,UC_HOOK_CODE
    from unicorn.x86_const import (UC_X86_REG_CS,UC_X86_REG_DS,UC_X86_REG_SS,
        UC_X86_REG_BP,UC_X86_REG_SP,UC_X86_REG_IP)
    exe=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    header=struct.unpack_from('<H',exe,8)[0]*16
    vm=Uc(UC_ARCH_X86,UC_MODE_16);vm.mem_map(0,0x80000);vm.mem_write(0,exe[header:])
    events=[]
    def hook(v,address,size,user):
        if address not in [0x299f2-header,0x2d040+0x131f,0x29d41-header]:return
        sp=v.reg_read(UC_X86_REG_SP)
        raw=bytes(v.mem_read(0x60000+sp,12));ip,cs=struct.unpack_from('<HH',raw);pop=0
        if address==0x299f2-header:events.append(['clear'])
        elif address==0x2d040+0x131f:
            events.append(['page',struct.unpack_from('<H',raw,4)[0]]);pop=2
        else:
            off,seg,color=struct.unpack_from('<HHH',raw,4)
            s=bytes(v.mem_read(seg*16+off,256))
            events.append(['print',color,s[1:1+s[0]].decode('johab')]);pop=6
        v.reg_write(UC_X86_REG_SP,sp+4+pop);v.reg_write(UC_X86_REG_CS,cs);v.reg_write(UC_X86_REG_IP,ip)
    vm.hook_add(UC_HOOK_CODE,hook)
    cases=[]
    for money in MONEY:
     for gold in GOLD:
      for page in [0,1]:
        events.clear()
        for reg,value in [(UC_X86_REG_CS,0x2466),(UC_X86_REG_DS,0x5000),
            (UC_X86_REG_SS,0x6000),(UC_X86_REG_BP,0x8000),(UC_X86_REG_SP,0x7cf6)]:vm.reg_write(reg,value)
        vm.mem_write(0x68006,struct.pack('<i',money));vm.mem_write(0x564ce,struct.pack('<i',gold));vm.mem_write(0x59c10,bytes([page]))
        vm.emu_start(START-header,END-header,count=100000)
        assert vm.reg_read(UC_X86_REG_CS)==0x2466 and 0x24660+vm.reg_read(UC_X86_REG_IP)==END-header
        assert len(events)==5 and events[1]==['page',1-page] and events[3]==['page',page]
        assert vm.mem_read(0x59c10,1)[0]==page and struct.unpack('<h',vm.mem_read(0x59c14,2))[0]==32
        cases.append(dict(money=money,gold=gold,page=page,events=list(events),
            afterGold=struct.unpack('<i',vm.mem_read(0x564ce,4))[0]))
    return dict(scope=__doc__,exeSha256=hashlib.sha256(exe).hexdigest(),
        fragment=dict(start=START,end=END,sha256=hashlib.sha256(exe[START:END]).hexdigest()),cases=cases)

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args()
    if args.check:
        data=json.loads(OUT.read_text());exe=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
        assert data['scope']==__doc__ and data['exeSha256']==hashlib.sha256(exe).hexdigest()
        assert data['fragment']==dict(start=START,end=END,sha256=hashlib.sha256(exe[START:END]).hexdigest())
        assert len(data['cases'])==len(MONEY)*len(GOLD)*2
    else:OUT.write_text(json.dumps(build(),separators=(',',':'))+'\n')
if __name__=='__main__':main()

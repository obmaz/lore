"""Original Load.ErrorMessage string copies/concats and need/Halt branch.

BIOS text-mode switch, CRT clear/color, text output, IO check and Halt are
intercepted platform boundaries. Original parameter copy, string concatenations
and conditional branch execute. This does not replay DOS file I/O or font errors.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'test/fixtures/dos_load_errors.json'
START,END=0x2ea0f,0x2eaa3
NAMES=['.map','party1.dat','party2.dat','party3.dat','party4.dat',
       'player1.dat','player2.dat','player3.dat','player4.dat','chara.fnt',
       'town.fnt','ground.fnt','den.fnt','keep.fnt']+[n+'.map' for n in
       ['ground1','ground2','water','swamp','lava','town1','town2','town3','town4','town5',
        't_den1','t_den2','den1','den2','den3','den4','den5','den6','den7','keep1','keep2','keep3','k_den1','k_den2','pyramid1']]

def build():
    from unicorn import Uc,UC_ARCH_X86,UC_MODE_16,UC_HOOK_CODE,UC_HOOK_INTR
    from unicorn.x86_const import (UC_X86_REG_CS,UC_X86_REG_DS,UC_X86_REG_SS,
        UC_X86_REG_BP,UC_X86_REG_SP,UC_X86_REG_IP,UC_X86_REG_AX)
    exe=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    header=struct.unpack_from('<H',exe,8)[0]*16
    vm=Uc(UC_ARCH_X86,UC_MODE_16);vm.mem_map(0,0x80000);vm.mem_write(0,exe[header:])
    events=[]
    targets={0x306b0+0x1c0:('clear',0),0x306b0+0x257:('color',2),
        0x30cd0+0x917:('write',10),0x30cd0+0x848:('newline',0),
        0x30cd0+0x4a9:('iocheck',0),0x30cd0+0xe9:('halt',0)}
    def interrupt(v,num,user):
        assert num==0x10 and v.reg_read(UC_X86_REG_AX)==3
        events.append(['mode',3])
    def hook(v,address,size,user):
        if address not in targets:return
        kind,pop=targets[address];sp=v.reg_read(UC_X86_REG_SP)
        raw=bytes(v.mem_read(0x60000+sp,16))
        if kind=='halt':
            assert v.reg_read(UC_X86_REG_AX)==0
            events.append(['halt',0]);v.emu_stop();return
        if kind=='write':
            width,off,seg=struct.unpack_from('<HHH',raw,4)
            assert width==0
            s=bytes(v.mem_read(seg*16+off,256))
            events.append(['write',s[1:1+s[0]].decode('ascii')])
        elif kind=='color':events.append(['color',struct.unpack_from('<H',raw,4)[0]])
        elif kind!='iocheck':events.append([kind])
        ip,cs=struct.unpack_from('<HH',raw)
        v.reg_write(UC_X86_REG_SP,sp+4+pop);v.reg_write(UC_X86_REG_CS,cs);v.reg_write(UC_X86_REG_IP,ip)
    vm.hook_add(UC_HOOK_CODE,hook);vm.hook_add(UC_HOOK_INTR,interrupt)
    cases=[]
    for name in NAMES:
     for need in [0,1]:
        events.clear()
        for reg,value in [(UC_X86_REG_CS,0x2466),(UC_X86_REG_DS,0x5000),
            (UC_X86_REG_SS,0x6000),(UC_X86_REG_BP,0x8000),(UC_X86_REG_SP,0x7c00)]:vm.reg_write(reg,value)
        vm.mem_write(0x70000,bytes([len(name)])+name.encode('ascii'))
        vm.mem_write(0x68006,struct.pack('<HHH',need,0,0x7000))
        vm.emu_start(START-header,0x7ffff,count=100000)
        assert events[0]==['mode',3] and events[-1]==['halt',0]
        cases.append(dict(name=name,need=bool(need),events=list(events)))
    return dict(scope=__doc__,exeSha256=hashlib.sha256(exe).hexdigest(),
        fragment=dict(start=START,end=END,sha256=hashlib.sha256(exe[START:END]).hexdigest()),cases=cases)

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args()
    if args.check:
        data=json.loads(OUT.read_text());exe=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
        assert data['scope']==__doc__ and data['exeSha256']==hashlib.sha256(exe).hexdigest()
        assert data['fragment']==dict(start=START,end=END,sha256=hashlib.sha256(exe[START:END]).hexdigest())
        assert len(data['cases'])==len(NAMES)*2
    else:OUT.write_text(json.dumps(build(),separators=(',',':'))+'\n')
if __name__=='__main__':main()

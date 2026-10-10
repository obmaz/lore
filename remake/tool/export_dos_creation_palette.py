"""Original LORECRET palette loops and idle keyboard-poll gates.

Only RGB, Delay and KeyPressed are supplied. Original loop bounds, bounce/wrap
branches and all five/ten reset stores execute. BGI glyphs/scanout excluded.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'test/fixtures/dos_creation_palette.json'
SPANS=[('displayBorder',0x86bb,0x8720),('displayTitle',0x87ab,0x8823),
       ('divider',0xa15e,0xa1c6),('classPulse',0xa91e,0xa971),
       ('confirmationPulse',0xaa3d,0xaa77),('quizReset',0x9847,0x9863),
       ('companionReset',0xabf5,0xac11),('allocationWait',0xa37e,0xa387),
       ('companionWait',0xac3f,0xac48),('companionChoiceWait',0xad33,0xad3c)]

def build():
    from unicorn import Uc,UC_ARCH_X86,UC_MODE_16,UC_HOOK_CODE
    from unicorn.x86_const import (UC_X86_REG_CS,UC_X86_REG_DS,UC_X86_REG_SS,
       UC_X86_REG_SP,UC_X86_REG_BP,UC_X86_REG_IP,UC_X86_REG_AX)
    exe=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    h=struct.unpack_from('<H',exe,8)[0]*16
    vm=Uc(UC_ARCH_X86,UC_MODE_16);vm.mem_map(0,0x80000);vm.mem_write(0,exe[h:])
    trace=[];context={}
    def hook(u,address,size,_):
        off=address+h
        if exe[off:off+1]!=b'\x9a':return
        target,seg=struct.unpack_from('<HH',exe,off+1);sp=u.reg_read(UC_X86_REG_SP)
        if (seg,target)==(0x2466,0):
            b,g,r,c=struct.unpack('<4H',u.mem_read(0x60000+sp,8))
            trace.append(['rgb',c&255,r&255,g&255,b&255]);args=8
        elif (seg,target)==(0x306b,0x29c):
            ms=struct.unpack('<H',u.mem_read(0x60000+sp,2))[0]
            trace.append(['delay',ms]);args=2
        elif (seg,target)==(0x306b,0x2fb):
            ready=context['polls']==context['falsePolls'];context['polls']+=1
            trace.append(['ready',ready]);u.reg_write(UC_X86_REG_AX,int(ready));args=0
        else:raise AssertionError((hex(off),hex(seg),hex(target)))
        u.reg_write(UC_X86_REG_SP,sp+args);u.reg_write(UC_X86_REG_IP,off+5-h)
    vm.hook_add(UC_HOOK_CODE,hook)
    rows=[]
    for kind,a,z in SPANS:
        budgets=[0,1,2,8,29,30,31,49,50,99,255] if 'Pulse' in kind or 'Wait' in kind else [0]
        for budget in budgets:
            for r,v in [(UC_X86_REG_CS,0),(UC_X86_REG_DS,0x5000),(UC_X86_REG_SS,0x6000),
                 (UC_X86_REG_SP,0x7e00),(UC_X86_REG_BP,0x8000)]:vm.reg_write(r,v)
            trace.clear();context.update(falsePolls=budget,polls=0)
            vm.mem_write(0x53653,bytes([255]*12))
            vm.emu_start(a-h,z-h,count=100000)
            assert vm.reg_read(UC_X86_REG_IP)==z-h
            assert vm.reg_read(UC_X86_REG_SP)==0x7e00
            rows.append(dict(kind=kind,falsePolls=budget,trace=list(trace),
                             reset=list(vm.mem_read(0x53653,12)) if kind.endswith('Reset') else None))
    return dict(scope=__doc__,exeSha256=hashlib.sha256(exe).hexdigest(),
        fragments=[dict(kind=k,start=a,end=z,sha256=hashlib.sha256(exe[a:z]).hexdigest()) for k,a,z in SPANS],cases=rows)

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--check',action='store_true')
    args=parser.parse_args()
    data=build()
    if args.check:
        assert json.loads(OUT.read_text())==data,'creation palette fixture drift'
    else:
        OUT.write_text(json.dumps(data,separators=(',',':'))+'\n')

#!/usr/bin/env python3
"""Original Fourth key/flag/cursor/choice/count transitions, valid flag states.

Only drawing/CRT output and sound delays are bypassed. Profile call arguments
are observed; its UI wait is outside the fixture. Inner loops stop at their next
native key wait, outer loops stop at theirs, or at the actual four-member exit.
"""
import argparse
import hashlib
import itertools
import json
import struct
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'test/fixtures/dos_companion_selection.json'
SPANS=[(0xabf5,0xac1c),(0xac50,0xae49)]


def configs():
    masks=[0,1,17,529]
    for mask,cursor,key in itertools.product(masks,range(1,11),range(256)):
        yield dict(mask=mask,cursor=cursor,key=key,scan=0,pending=False)
        if not mask&(1<<(cursor-1)):
            yield dict(mask=mask,cursor=cursor,key=key,scan=0,pending=True)
    for mask,cursor,scan in itertools.product(masks,range(1,11),range(256)):
        yield dict(mask=mask,cursor=cursor,key=0,scan=scan,pending=False)
    for mask in range(1024):
        if mask.bit_count()>3:continue
        for cursor,key in itertools.product(range(1,11),[13,49,50,27,88]):
            yield dict(mask=mask,cursor=cursor,key=key,scan=0,pending=False)
            if not mask&(1<<(cursor-1)):
                yield dict(mask=mask,cursor=cursor,key=key,scan=0,pending=True)


def build():
    from unicorn import Uc,UC_ARCH_X86,UC_MODE_16,UC_HOOK_CODE
    from unicorn.x86_const import UC_X86_REG_CS,UC_X86_REG_DS,UC_X86_REG_SS,UC_X86_REG_BP,UC_X86_REG_SP,UC_X86_REG_IP,UC_X86_REG_AX
    exe=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes();header=struct.unpack_from('<H',exe,8)[0]*16
    vm=Uc(UC_ARCH_X86,UC_MODE_16);vm.mem_map(0,0x80000);vm.mem_write(0,exe[header:]);phase=[];profiles=[];scan=[0]
    def setup():
        for r,v in [(UC_X86_REG_CS,0),(UC_X86_REG_DS,0x5000),(UC_X86_REG_SS,0x6000),(UC_X86_REG_BP,0x8000),(UC_X86_REG_SP,0x7e00)]:vm.reg_write(r,v)
    def hook(u,address,size,data):
        offset=address+header
        if offset==0xac5c:u.reg_write(UC_X86_REG_AX,scan[0]);u.reg_write(UC_X86_REG_IP,0xac61-header)
        if offset in [0xaca6,0xad0c,0xad58,0xadca,0xadf0]:
            target={0xaca6:0xacf0,0xad0c:0xad33,0xad58:0xadb9,0xadca:0xadd8,0xadf0:0xae0a}[offset]
            u.reg_write(UC_X86_REG_IP,target-header)
        if offset==0xadc7:
            sp=u.reg_read(UC_X86_REG_SP);profiles.append(struct.unpack('<h',u.mem_read(0x60000+sp,2))[0]);u.reg_write(UC_X86_REG_SP,sp+2);u.reg_write(UC_X86_REG_IP,0xadca-header)
        if offset in [0xac1c,0xac3f,0xad33,0xae49]:
            phase.append({0xac1c:'initial',0xac3f:'outer',0xad33:'choice',0xae49:'complete'}[offset]);u.emu_stop()
    vm.hook_add(UC_HOOK_CODE,hook)
    setup();vm.mem_write(0x53654,bytes([255]*10));vm.emu_start(0xabf5-header,0x7ffff,count=1000)
    assert phase==['initial'];initial=list(vm.mem_read(0x53654,10));assert initial==[0]*10
    rows=[]
    for r in configs():
        setup();phase.clear();profiles.clear();scan[0]=r['scan']
        vm.mem_write(0x53654,bytes(int(r['mask']&(1<<i)!=0) for i in range(10)))
        vm.mem_write(0x53662,struct.pack('<h',r['cursor']+15));vm.mem_write(0x5366a,bytes([r['key']]));vm.mem_write(0x539b4,b'\x00')
        vm.emu_start((0xad44 if r['pending'] else 0xac50)-header,0x7ffff,count=5000);assert len(phase)==1
        flags=list(vm.mem_read(0x53654,10));assert all(v in [0,1] for v in flags)
        rows.append(dict(**r,afterMask=sum(v<<i for i,v in enumerate(flags)),afterCursor=struct.unpack('<h',vm.mem_read(0x53662,2))[0]-15,
                         afterPending=phase[0]=='choice',complete=phase[0]=='complete',profiles=list(profiles)))
    return dict(scope=__doc__,exeSha256=hashlib.sha256(exe).hexdigest(),initial=initial,
                fragments=[dict(start=a,end=z,sha256=hashlib.sha256(exe[a:z]).hexdigest()) for a,z in SPANS],cases=rows)


def main():
    p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');args=p.parse_args()
    if args.check:
        d=json.loads(OUT.read_text());exe=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
        assert d['exeSha256']==hashlib.sha256(exe).hexdigest();assert d['scope']==__doc__
        assert d['fragments']==[dict(start=a,end=z,sha256=hashlib.sha256(exe[a:z]).hexdigest()) for a,z in SPANS]
    else:
        d=build();rows=d.pop('cases');head=json.dumps(d,indent=2)[:-2]
        OUT.write_text(head+',\n  "cases": [\n'+',\n'.join('    '+json.dumps(r,separators=(',',':')) for r in rows)+'\n  ]\n}\n')


if __name__=='__main__':main()

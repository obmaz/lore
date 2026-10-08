#!/usr/bin/env python3
"""Original Second key decoding, cursor clamps, byte rollback and Enter guard.

Synthetic valid allocation states; only CRT output spans are skipped before
their pushes. Actual instructions choose every transition and finish result.
"""
import argparse
import hashlib
import itertools
import json
import struct
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'test/fixtures/dos_creation_second.json'
START,END=0xa38f,0xa59e
SPANS=[(0xa362,0xa37e),(START,END)]


def configs():
    states=[[0,0,0],[20,20,0],[0,20,20],[20,0,20],[19,20,0]]
    for values,cursor,key in itertools.product(states,range(3),range(256)):
        yield dict(values=values,cursor=cursor,key=key,scan=0)
    for values,cursor,scan in itertools.product(states,range(3),range(256)):
        yield dict(values=values,cursor=cursor,key=0,scan=scan)
    for values in itertools.product(range(21),repeat=3):
        if sum(values)>40:continue
        for cursor,scan in itertools.product(range(3),[75,77]):
            yield dict(values=list(values),cursor=cursor,key=0,scan=scan)


def build():
    from unicorn import Uc,UC_ARCH_X86,UC_MODE_16,UC_HOOK_CODE
    from unicorn.x86_const import UC_X86_REG_CS,UC_X86_REG_DS,UC_X86_REG_SS,UC_X86_REG_BP,UC_X86_REG_SP,UC_X86_REG_IP,UC_X86_REG_AX
    exe=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes();header=struct.unpack_from('<H',exe,8)[0]*16
    u=Uc(UC_ARCH_X86,UC_MODE_16);u.mem_map(0,0x80000);u.mem_write(0,exe[header:]);done=[];scan=[0]
    def setup():
        for r,v in [(UC_X86_REG_CS,0),(UC_X86_REG_DS,0x5000),(UC_X86_REG_SS,0x6000),(UC_X86_REG_BP,0x8000),(UC_X86_REG_SP,0x7e00)]:u.reg_write(r,v)
    def hook(vm,address,size,data):
        offset=address+header
        if offset==0xa3a0:vm.reg_write(UC_X86_REG_AX,scan[0]);vm.reg_write(UC_X86_REG_IP,0xa3a5-header)
        if offset in [0xa402,0xa4d6]:vm.reg_write(UC_X86_REG_IP,({0xa402:0xa44c,0xa4d6:0xa578}[offset])-header)
        if offset in [0xa37e,END]:done.append(offset==END);vm.emu_stop()
    u.hook_add(UC_HOOK_CODE,hook)
    setup();u.mem_write(0x53654,b'\xff\xff\xff');u.emu_start(0xa362-header,0x7ffff,count=1000)
    assert done==[False];initial=list(u.mem_read(0x53654,3));assert initial==[0,0,0]
    rows=[]
    for r in configs():
        setup();done.clear();scan[0]=r['scan']
        u.mem_write(0x53654,bytes(r['values']));u.mem_write(0x53660,struct.pack('<hh',r['cursor']+17,40-sum(r['values'])))
        u.mem_write(0x5366a,bytes([r['key']]))
        u.emu_start(START-header,0x7ffff,count=2000);assert len(done)==1,r
        rows.append(dict(**r,afterValues=list(u.mem_read(0x53654,3)),
                         afterCursor=struct.unpack('<h',u.mem_read(0x53660,2))[0]-17,
                         afterRemaining=struct.unpack('<h',u.mem_read(0x53662,2))[0],finished=done[0]))
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

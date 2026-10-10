#!/usr/bin/env python3
"""Original Third byte key/flag gate, class store and repeat outcome.

Sound/error-delay spans are bypassed; every selection instruction is original.
WhatClass literals and companion profiles are independently read from Pascal.
"""
import argparse
import hashlib
import itertools
import json
import re
import struct
from pathlib import Path
from audit_lorespec import decode
from export_lore_cret import parse_characters,load_lines

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'test/fixtures/dos_creation_class.json'
START,END=0xa984,0xa9d2


def source_data():
    raw=(ROOT/'repo_source/LORE_1993_src/LORECRET.PAS').read_bytes()
    source='\n'.join(decode(l) for l in raw.splitlines())
    body=source.split('Procedure WhatClass',1)[1].split('Procedure Display',1)[0]
    labels=dict(re.findall(r"(\d+)\s*:\s*s := '([^']*)'",body))
    assert len(labels)==10
    default=re.search(r"else s := '([^']*)'",body)[1]
    return dict(sourceSha256=hashlib.sha256(raw).hexdigest(),labels=labels,default=default,characters=parse_characters(load_lines()))


def build():
    from unicorn import Uc,UC_ARCH_X86,UC_MODE_16,UC_HOOK_CODE
    from unicorn.x86_const import UC_X86_REG_CS,UC_X86_REG_DS,UC_X86_REG_SS,UC_X86_REG_BP,UC_X86_REG_SP,UC_X86_REG_IP
    exe=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes();header=struct.unpack_from('<H',exe,8)[0]*16
    vm=Uc(UC_ARCH_X86,UC_MODE_16);vm.mem_map(0,0x80000);vm.mem_write(0,exe[header:]);finished=[]
    def hook(u,address,size,data):
        offset=address+header
        if offset==0xa9b5:u.reg_write(UC_X86_REG_IP,0xa9c8-header)
        if offset in [0xa91e,END]:finished.append(offset==END);u.emu_stop()
    vm.hook_add(UC_HOOK_CODE,hook);rows=[]
    for key,mask in itertools.product(range(256),range(128)):
        for r,v in [(UC_X86_REG_CS,0),(UC_X86_REG_DS,0x5000),(UC_X86_REG_SS,0x6000),(UC_X86_REG_BP,0x8000),(UC_X86_REG_SP,0x7e00)]:vm.reg_write(r,v)
        vm.mem_write(0x5366a,bytes([key]));vm.mem_write(0x53654,bytes([*(int(mask&(1<<i)!=0) for i in range(7)),1]))
        vm.mem_write(0x56549,b'\xff');vm.mem_write(0x539b4,b'\x00');finished.clear()
        vm.emu_start(START-header,0x7ffff,count=1000);assert len(finished)==1
        cls=vm.mem_read(0x56549,1)[0];assert finished[0] or cls==255
        rows.append(dict(key=key,mask=mask,selected=cls if finished[0] else None))
    return dict(scope=__doc__,exeSha256=hashlib.sha256(exe).hexdigest(),source=source_data(),fragment=dict(start=START,end=END,sha256=hashlib.sha256(exe[START:END]).hexdigest()),cases=rows)


def main():
    p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');args=p.parse_args()
    if args.check:
        d=json.loads(OUT.read_text());exe=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
        assert d['exeSha256']==hashlib.sha256(exe).hexdigest();assert d['scope']==__doc__
        assert d['source']==source_data();assert d['fragment']==dict(start=START,end=END,sha256=hashlib.sha256(exe[START:END]).hexdigest())
    else:
        d=build();rows=d.pop('cases');head=json.dumps(d,indent=2)[:-2]
        OUT.write_text(head+',\n  "cases": [\n'+',\n'.join('    '+json.dumps(r,separators=(',',':')) for r in rows)+'\n  ]\n}\n')


if __name__=='__main__':main()

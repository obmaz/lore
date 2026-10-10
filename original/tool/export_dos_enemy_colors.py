#!/usr/bin/env python3
"""Original DisplayEnemies count loop, signed HP CASE and status colour priority.

SetColor/HPrintXY are observed at their call sites; drawing/glyphs and the
optional backdrop-clear branch are outside the numeric colour fixture.
"""
import argparse
import hashlib
import itertools
import json
import struct
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'test/fixtures/dos_enemy_colors.json'
START,END,BASE=0x20ac9,0x20bb5,0x207f0
COLOR_CALLS=[0x20b02,0x20b15,0x20b28,0x20b3b,0x20b4e,0x20b61,0x20b6a,0x20b7b,0x20b8c]
BOUNDARIES=[-32768,-1,0,1,19,20,49,50,99,100,199,200,299,300,32767]


def build():
    from unicorn import Uc,UC_ARCH_X86,UC_MODE_16,UC_HOOK_CODE
    from unicorn.x86_const import UC_X86_REG_CS,UC_X86_REG_DS,UC_X86_REG_SS,UC_X86_REG_BP,UC_X86_REG_SP,UC_X86_REG_IP
    exe=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes();header=struct.unpack_from('<H',exe,8)[0]*16
    vm=Uc(UC_ARCH_X86,UC_MODE_16);vm.mem_map(0,0x80000);vm.mem_write(0,exe[header:])
    printed=[];palette=[-1];reached=[]
    def hook(u,address,size,data):
        offset=address+header
        if offset in COLOR_CALLS:
            sp=u.reg_read(UC_X86_REG_SP);palette[0]=struct.unpack('<H',u.mem_read(0x60000+sp,2))[0]
            u.reg_write(UC_X86_REG_SP,sp+2);u.reg_write(UC_X86_REG_IP,offset+5-BASE)
        if offset==0x20b91:
            slot=struct.unpack('<h',u.mem_read(0x5702e,2))[0];printed.append([slot,palette[0]])
            u.reg_write(UC_X86_REG_IP,0x20baa-BASE)
        if offset==END:reached.append(True);u.emu_stop()
    vm.hook_add(UC_HOOK_CODE,hook)
    def run(hp,unconscious,dead,count):
        printed.clear();reached.clear();palette[0]=-1
        for r,v in [(UC_X86_REG_CS,(BASE-header)//16),(UC_X86_REG_DS,0x5000),(UC_X86_REG_SS,0x6000),(UC_X86_REG_BP,0x8000),(UC_X86_REG_SP,0x7f00)]:vm.reg_write(r,v)
        vm.mem_write(0x56f37,bytes([count]))
        for slot in range(1,8):
            e=bytearray(35);struct.pack_into('<h',e,30,hp);e[33]=unconscious;e[34]=dead
            vm.mem_write(0x56f15+35*slot,bytes(e))
        vm.emu_start(START-header,0x7ffff,count=5000);assert reached
        return dict(hp=hp,unconscious=bool(unconscious),dead=bool(dead),count=count,printed=list(printed))
    rows=[run(hp,0,0,1) for hp in range(-32768,32768)]
    rows.extend(run(hp,u,d,count) for hp,u,d,count in itertools.product(BOUNDARIES,[0,1],[0,1],range(8)))
    return dict(scope=__doc__,exeSha256=hashlib.sha256(exe).hexdigest(),fragment=dict(start=START,end=END,sha256=hashlib.sha256(exe[START:END]).hexdigest()),cases=rows)


def main():
    p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');args=p.parse_args()
    if args.check:
        d=json.loads(OUT.read_text());exe=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
        assert d['exeSha256']==hashlib.sha256(exe).hexdigest();assert d['scope']==__doc__
        assert d['fragment']==dict(start=START,end=END,sha256=hashlib.sha256(exe[START:END]).hexdigest())
    else:
        d=build();rows=d.pop('cases');head=json.dumps(d,indent=2)[:-2]
        OUT.write_text(head+',\n  "cases": [\n'+',\n'.join('    '+json.dumps(r,separators=(',',':')) for r in rows)+'\n  ]\n}\n')


if __name__=='__main__':main()

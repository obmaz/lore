#!/usr/bin/env python3
"""Unmodified CastOne cost/SP/base-damage arithmetic. Unicorn required only for generation.
Values outside spells1..6 are synthetic instruction boundaries, not reachable UI.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUTPUT=ROOT/'test/fixtures/dos_spell_arithmetic.json'
FRAGMENTS=[('cost',0x2133e,0x21369),('sp',0x21385,0x21397),('damage',0x213e1,0x21405)]


def build():
    from unicorn import Uc,UC_ARCH_X86,UC_MODE_16
    from unicorn.x86_const import (UC_X86_REG_CS,UC_X86_REG_DS,UC_X86_REG_SS,
        UC_X86_REG_SP,UC_X86_REG_BP,UC_X86_REG_IP)
    exe=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    header=struct.unpack_from('<H',exe,8)[0]*16
    pairs=[(1,1),(3,1),(20,3),(255,6),(200,13),(255,255),(128,16),(1,255)]
    cases=[]
    for level,spell in pairs:
        for sp in [0,30000,-32768]:
            vm=Uc(UC_ARCH_X86,UC_MODE_16);vm.mem_map(0,0x80000);vm.mem_write(0,exe[header:])
            for r,v in [(UC_X86_REG_CS,0x1000),(UC_X86_REG_DS,0x5000),(UC_X86_REG_SS,0x6000),
                        (UC_X86_REG_SP,0xff00),(UC_X86_REG_BP,0x8000)]:vm.reg_write(r,v)
            vm.mem_write(0x67ffc,struct.pack('<HH',0x100,0x5000))
            vm.mem_write(0x5012a,bytes([level]));vm.mem_write(0x50125,struct.pack('<h',sp))
            vm.mem_write(0x53660,struct.pack('<h',spell))
            vm.emu_start(0x2133e-header,0x21369-header,count=10000)
            assert vm.reg_read(UC_X86_REG_CS)==0x1000 and 0x10000+vm.reg_read(UC_X86_REG_IP)==0x21369-header
            cost=struct.unpack('<h',vm.mem_read(0x5702e,2))[0]
            can_cast=sp>=cost
            if can_cast:
                vm.emu_start(0x21385-header,0x21397-header,count=40)
                assert vm.reg_read(UC_X86_REG_CS)==0x1000 and 0x10000+vm.reg_read(UC_X86_REG_IP)==0x21397-header
            after=struct.unpack('<h',vm.mem_read(0x50125,2))[0]
            vm.emu_start(0x213e1-header,0x21405-header,count=10000)
            assert vm.reg_read(UC_X86_REG_CS)==0x1000 and 0x10000+vm.reg_read(UC_X86_REG_IP)==0x21405-header
            damage=struct.unpack('<h',vm.mem_read(0x5702e,2))[0]
            cases.append(dict(level=level,spell=spell,sp=sp,cost=cost,canCast=can_cast,
                              afterSp=after,damage=damage,reachableCommand=1<=spell<=6))
    return dict(source='Unmodified CastOne MUL/MUL/CWD, shipped TP real /2 and Round, SP word SUB/store, and signed low-word damage conversion/Round executed by Unicorn x86-16. Synthetic player memory; original code unchanged.',
        executableSha256=hashlib.sha256(exe).hexdigest(),
        fragments=[dict(name=n,startFileOffset=a,endFileOffset=b,codeHex=exe[a:b].hex()) for n,a,b in FRAGMENTS],
        cases=cases,scope='Cost, SP and base damage instruction arithmetic only. spells1..6 are normal command range; other spell numbers are synthetic arithmetic boundaries, not valid gameplay replays. Whole RNG stream/battle/UI and enemy attacks are separate gates.')


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--check',action='store_true');a=p.parse_args()
    if a.check:
        f=json.loads(OUTPUT.read_text());exe=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
        assert hashlib.sha256(exe).hexdigest()==f['executableSha256']
        assert [(x['name'],x['startFileOffset'],x['endFileOffset']) for x in f['fragments']]==FRAGMENTS
        for x in f['fragments']:assert exe[x['startFileOffset']:x['endFileOffset']].hex()==x['codeHex']
        print('Original CastOne arithmetic fragments are current')
    else:OUTPUT.write_text(json.dumps(build(),ensure_ascii=False,indent=2)+'\n')


if __name__=='__main__':main()

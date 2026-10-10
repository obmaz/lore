#!/usr/bin/env python3
"""Original BattleMode level CASEs supplying maxsum to Select, all byte levels."""
import argparse
import hashlib
import json
import struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'test/fixtures/dos_battle_menus.json'
SPANS=[(2,0x24f17,0x24f76),(3,0x2501d,0x25088),(4,0x2511e,0x2518d)]


def build():
    from unicorn import Uc,UC_ARCH_X86,UC_MODE_16
    from unicorn.x86_const import UC_X86_REG_CS,UC_X86_REG_DS,UC_X86_REG_SS,UC_X86_REG_BP,UC_X86_REG_SP,UC_X86_REG_IP
    exe=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes();header=struct.unpack_from('<H',exe,8)[0]*16
    u=Uc(UC_ARCH_X86,UC_MODE_16);u.mem_map(0,0x80000);u.mem_write(0,exe[header:]);rows=[]
    for how,a,z in SPANS:
        for level in range(256):
            person=level%6+1
            for r,v in [(UC_X86_REG_CS,0x1000),(UC_X86_REG_DS,0x5000),(UC_X86_REG_SS,0x6000),(UC_X86_REG_BP,0x8000),(UC_X86_REG_SP,0x7f00)]:u.reg_write(r,v)
            u.mem_write(0x53d9e,struct.pack('<h',person));u.mem_write(0x56529+55*person,bytes([level]))
            u.emu_start(a-header,z-header,count=1000)
            assert u.reg_read(UC_X86_REG_CS)==0x1000 and 0x10000+u.reg_read(UC_X86_REG_IP)==z-header
            rows.append(dict(how=how,level=level,person=person,maxsum=struct.unpack('<h',u.mem_read(0x53660,2))[0]))
    return dict(scope=__doc__,exeSha256=hashlib.sha256(exe).hexdigest(),fragments=[dict(how=h,start=a,end=z,sha256=hashlib.sha256(exe[a:z]).hexdigest()) for h,a,z in SPANS],cases=rows)


def main():
    p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');args=p.parse_args()
    if args.check:
        data=json.loads(OUT.read_text());exe=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
        assert data['exeSha256']==hashlib.sha256(exe).hexdigest();assert data['scope']==__doc__
        assert data['fragments']==[dict(how=h,start=a,end=z,sha256=hashlib.sha256(exe[a:z]).hexdigest()) for h,a,z in SPANS]
    else:OUT.write_text(json.dumps(build(),indent=2)+'\n')


if __name__=='__main__':main()

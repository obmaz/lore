#!/usr/bin/env python3
"""Run unmodified DOS AttackOne/CastOne defence arithmetic, including TP real Round.
Generation requires Unicorn; --check needs only the Python standard library.
This is arithmetic evidence, not a complete original battle replay.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'test/fixtures/dos_defence_arithmetic.json'
FRAGMENTS = [('AttackOne', 0x20fe6, 0x2101d), ('CastOne', 0x21471, 0x214a8)]


def build():
    from unicorn import Uc, UC_ARCH_X86, UC_MODE_16
    from unicorn.x86_const import (UC_X86_REG_AX, UC_X86_REG_BP, UC_X86_REG_CS,
                                  UC_X86_REG_DS, UC_X86_REG_IP, UC_X86_REG_SP,
                                  UC_X86_REG_SS)
    exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    header = struct.unpack_from('<H', exe, 8)[0] * 16
    cases = []
    pairs = [(0,255), (1,1), (5,1), (8,4), (20,20), (128,128),
             (128,255), (255,255), (255,128), (255,26)]
    for routine, start, end in FRAGMENTS:
        for ac, level in pairs:
            for roll in [0,3,4,9]:
                vm = Uc(UC_ARCH_X86, UC_MODE_16)
                vm.mem_map(0, 0x80000)
                vm.mem_write(0, exe[header:])
                for reg, value in [(UC_X86_REG_CS,0x1000), (UC_X86_REG_DS,0x5000),
                                   (UC_X86_REG_SS,0x6000), (UC_X86_REG_SP,0xff00),
                                   (UC_X86_REG_BP,0x8000), (UC_X86_REG_AX,roll)]:
                    vm.reg_write(reg,value)
                vm.mem_write(0x67ffc,struct.pack('<HH',0x100,0x5000))
                # Original enemydata2 is 35 bytes; AC at25, level at29.
                monster = bytearray(35)
                monster[25],monster[29] = ac,level
                vm.mem_write(0x50100,bytes(monster))
                # Starts just after Random(10); executes both MULs, unsigned
                # low-word conversion, real /10 and the shipped Round helper.
                vm.emu_start(start-header,end-header,count=10000)
                if 0x10000+vm.reg_read(UC_X86_REG_IP) != end-header:
                    raise RuntimeError('Native defence fragment did not complete')
                defence = struct.unpack('<h',vm.mem_read(0x53660,2))[0]
                cases.append(dict(routine=routine,ac=ac,level=level,
                                  random10=roll,defence=defence))
    return {
        'source':'Unmodified LORE.EXE AttackOne and CastOne defence fragments, including original Turbo Pascal real conversion/division/Round helpers, executed by Unicorn x86-16. Synthetic enemy memory and Random(10) result; executable is unchanged.',
        'executableSha256':hashlib.sha256(exe).hexdigest(),
        'fragments':[dict(routine=r,startFileOffset=a,endFileOffset=b,codeHex=exe[a:b].hex()) for r,a,b in FRAGMENTS],
        'cases':cases,
        'scope':'Defence arithmetic only: low unsigned word of ac*level*(random10+1), real division by10 and Round. Original RNG stream, magic base damage/cost, enemy attacks and whole-game parity are separate gates.',
    }


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check',action='store_true')
    args=parser.parse_args()
    if args.check:
        data=json.loads(OUTPUT.read_text())
        exe=(ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
        assert hashlib.sha256(exe).hexdigest()==data['executableSha256']
        assert [(f['routine'],f['startFileOffset'],f['endFileOffset']) for f in data['fragments']]==FRAGMENTS
        for f in data['fragments']:
            assert exe[f['startFileOffset']:f['endFileOffset']].hex()==f['codeHex']
        print('Original physical/magic defence arithmetic fragments are current')
    else:
        OUTPUT.write_text(json.dumps(build(),ensure_ascii=False,indent=2)+'\n')


if __name__=='__main__':
    main()

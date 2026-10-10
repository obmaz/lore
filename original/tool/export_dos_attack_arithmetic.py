#!/usr/bin/env python3
"""Execute original AttackOne arithmetic fragments in Unicorn x86-16.
Generation needs unicorn; --check verifies immutable EXE bytes without it.
This is instruction-level evidence, not a complete DOS battle replay.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'test/fixtures/dos_attack_arithmetic.json'
BASE_START, BASE_END = 0x20f27, 0x20f4d
VAR_START, VAR_END = 0x20f62, 0x20f8a


def build():
    from unicorn import Uc, UcError, UC_ARCH_X86, UC_MODE_16
    from unicorn.x86_const import (UC_X86_REG_AX, UC_X86_REG_BP, UC_X86_REG_CS,
                                  UC_X86_REG_DI, UC_X86_REG_DS, UC_X86_REG_ES,
                                  UC_X86_REG_IP, UC_X86_REG_SP, UC_X86_REG_SS)
    exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    header = struct.unpack_from('<H', exe, 8)[0] * 16
    cases = []
    triples = [(20,75,20), (20,50,20), (17,3,1), (20,20,20),
               (255,255,128), (255,255,255), (128,128,4),
               (20,75,22), (255,255,1), (128,255,1)]
    for strength, power, level in triples:
        vm = Uc(UC_ARCH_X86, UC_MODE_16)
        vm.mem_map(0, 0x80000)
        # Load the original unrelocated image at its link-time segment addresses.
        vm.mem_write(0, exe[header:])
        for reg, value in [(UC_X86_REG_CS,0x1000), (UC_X86_REG_DS,0x5000),
                           (UC_X86_REG_ES,0x5000), (UC_X86_REG_SS,0x6000),
                           (UC_X86_REG_SP,0xff00), (UC_X86_REG_BP,0x8000),
                           (UC_X86_REG_DI,0x100)]:
            vm.reg_write(reg,value)
        vm.mem_write(0x60000+0x7ffc,struct.pack('<HH',0x100,0x5000))
        player = bytearray(55)
        player[20],player[52],player[41] = strength,power,level
        vm.mem_write(0x50100,bytes(player))
        row = dict(strength=strength,weaponPower=power,level=level)
        try:
            vm.emu_start(BASE_START-header, BASE_END-header, count=40)
        except UcError as error:
            # The original CWD + unsigned DIV traps when the product's low
            # word has its sign bit set. Accept only that exact instruction.
            if 0x10000+vm.reg_read(UC_X86_REG_IP) != 0x20f4b-header:
                raise RuntimeError('Unexpected native fault') from error
            row['fault'] = 'division-overflow'
            cases.append(row)
            continue
        if 0x10000+vm.reg_read(UC_X86_REG_IP) != BASE_END-header:
            raise RuntimeError('Base fragment did not complete')
        row['baseDamage'] = vm.reg_read(UC_X86_REG_AX)
        row['variation'] = []
        # Round(integer quotient) leaves this nonnegative integer unchanged.
        # Execute the actual subsequent TP long multiply/divide helpers too.
        for variance in [0,25,49]:
            vm.reg_write(UC_X86_REG_CS,0x1000)
            vm.reg_write(UC_X86_REG_AX,variance)
            vm.mem_write(0x50000+0x702e,struct.pack('<h',row['baseDamage']))
            vm.emu_start(VAR_START-header,VAR_END-header,count=1000)
            if 0x10000+vm.reg_read(UC_X86_REG_IP) != VAR_END-header:
                raise RuntimeError('Variance fragment did not complete')
            damage=struct.unpack('<h',vm.mem_read(0x50000+0x702e,2))[0]
            row['variation'].append(dict(random50=variance,damage=damage))
        cases.append(row)
    return {
        'source':'Unmodified LORE.EXE AttackOne byte-product/div20 and long variance fragments executed by Unicorn x86-16, including original TP long multiply/divide helpers. Synthetic player memory/registers; no EXE code changes.',
        'executableSha256':hashlib.sha256(exe).hexdigest(),
        'fragments':[dict(startFileOffset=a,endFileOffset=b,codeHex=exe[a:b].hex()) for a,b in [(BASE_START,BASE_END),(VAR_START,VAR_END)]],
        'cases':cases,
        'scope':'Instruction-level arithmetic evidence. Native division faults are represented by an engine StateError; DOS runtime error-screen presentation is not reproduced here. Original random seed/call stream, defence operand widths, full battle and new-game-to-ending parity are separate gates.',
    }


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check',action='store_true')
    args=parser.parse_args()
    if args.check:
        data=json.loads(OUTPUT.read_text())
        exe=(ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
        assert hashlib.sha256(exe).hexdigest()==data['executableSha256']
        assert [(f['startFileOffset'],f['endFileOffset']) for f in data['fragments']]==[(BASE_START,BASE_END),(VAR_START,VAR_END)]
        for f in data['fragments']:
            assert exe[f['startFileOffset']:f['endFileOffset']].hex()==f['codeHex']
        print('Original AttackOne arithmetic fragments are current')
    else:
        OUTPUT.write_text(json.dumps(build(),ensure_ascii=False,indent=2)+'\n')


if __name__=='__main__':
    main()

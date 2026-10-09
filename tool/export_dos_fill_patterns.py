"""Execute the embedded original EGAVGA driver's fill-pattern selector.

No drawing or pattern implementation is supplied. The original instructions
copy the native table or construct EMPTY/SOLID into the driver's eight rows.
This covers source fill masks, not VGA hardware scanout or wall-clock timing.
"""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'test/fixtures/dos_fill_patterns.json'
BASE, START, END = 0x5663, 0x5a63, 0x5a98


def build():
    from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_CODE
    from unicorn.x86_const import (UC_X86_REG_CS, UC_X86_REG_DS,
        UC_X86_REG_SS, UC_X86_REG_SP, UC_X86_REG_AX, UC_X86_REG_IP)
    exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    vm = Uc(UC_ARCH_X86, UC_MODE_16)
    vm.mem_map(0, 0x80000)
    # The BGI registration strips its header and executes the relocatable
    # driver at offset zero, with DS=CS inside the dispatch entry.
    vm.mem_write(0x70000, exe[BASE:BASE+0x6ad0])
    def hook(u,address,size,_):
        if address in (0x70000+0x5a86-BASE,0x70000+0x5a97-BASE):
            u.emu_stop()
    vm.hook_add(UC_HOOK_CODE, hook)
    rows = []
    for form in range(12):
        for reg,value in [(UC_X86_REG_CS,0x7000),(UC_X86_REG_DS,0x7000),
                (UC_X86_REG_SS,0x6000),(UC_X86_REG_SP,0x7e00),(UC_X86_REG_AX,form)]:
            vm.reg_write(reg,value)
        vm.mem_write(0x70437,b'\x5a'*8)
        vm.emu_start(0x70000+START-BASE,0x70000+END-BASE,count=100)
        assert vm.reg_read(UC_X86_REG_IP) in (0x5a86-BASE,0x5a97-BASE)
        rows.append(list(vm.mem_read(0x70437,8)))
    return dict(scope=__doc__,exeSha256=hashlib.sha256(exe).hexdigest(),
        driverBase=BASE,fragmentSha256=hashlib.sha256(exe[START:END]).hexdigest(),
        tableSha256=hashlib.sha256(exe[BASE+0x890:BASE+0x8e0]).hexdigest(),patterns=rows)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--check',action='store_true')
    args=parser.parse_args()
    data=build()
    if args.check:
        assert json.loads(OUT.read_text())==data,'fill-pattern fixture drift'
    else:
        OUT.write_text(json.dumps(data,indent=2)+'\n')


if __name__=='__main__':
    main()

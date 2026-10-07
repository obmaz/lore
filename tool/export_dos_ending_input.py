#!/usr/bin/env python3
"""Execute original ThunderEffect loop with synthetic c/keyboard/seed inputs.

Original RNG and branch instructions execute unchanged. RGB, Delay and CRT
keyboard calls are intercepted; this does not verify BGI timing or campaign play.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'test/fixtures/dos_ending_input.json'
START, END = 0x1ffde, 0x20041
RANDOM = 225719


def build():
    from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_CODE
    from unicorn.x86_const import (UC_X86_REG_CS, UC_X86_REG_DS,
        UC_X86_REG_SS, UC_X86_REG_SP, UC_X86_REG_BP, UC_X86_REG_AX,
        UC_X86_REG_IP)
    exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    header = struct.unpack_from('<H', exe, 8)[0] * 16
    rows = []
    for seed in [0, 1, 26622, 0xffffffff]:
        for initial, keys, limit in [(27, [], 8), (27, [13, 27], 8),
                                     (13, [65, 27, 13], 8), (27, [13], 2),
                                     (27, [0, 72, 27, 13], 8),
                                     (13, [0, 59, 27], 8)]:
            u = Uc(UC_ARCH_X86, UC_MODE_16)
            u.mem_map(0, 0x80000)
            u.mem_write(0, exe[header:])
            for r, v in [(UC_X86_REG_CS, 0x1000), (UC_X86_REG_DS, 0x5000),
                         (UC_X86_REG_SS, 0x6000), (UC_X86_REG_SP, 0x7ff0),
                         (UC_X86_REG_BP, 0x8000)]:
                u.reg_write(r, v)
            u.mem_write(0x5364c, struct.pack('<I', seed))
            u.mem_write(0x5366a, bytes([initial]))
            u.mem_write(0x67fff, b'\0')
            queue, events = list(keys), []
            loops, closed = [0], [False]
            def skip(vm, args=0, ax=None):
                if ax is not None: vm.reg_write(UC_X86_REG_AX, ax)
                vm.reg_write(UC_X86_REG_SP, vm.reg_read(UC_X86_REG_SP) + args)
                vm.reg_write(UC_X86_REG_IP, vm.reg_read(UC_X86_REG_IP) + 5)
            def hook(vm, address, size, data):
                offset = address + header
                if offset == START:
                    if loops[0] == limit:
                        vm.emu_stop(); return
                    loops[0] += 1
                if offset == RANDOM:
                    sp = vm.reg_read(UC_X86_REG_SP)
                    bound = struct.unpack('<H', vm.mem_read(0x60000 + sp + 4, 2))[0]
                    events.append(['random', bound])
                elif offset in (0x1fffd, 0x2001a):
                    events.append(['rgb']); skip(vm, 8)
                elif offset == 0x2000d:
                    sp = vm.reg_read(UC_X86_REG_SP)
                    events.append(['delay', struct.unpack('<H', vm.mem_read(0x60000 + sp, 2))[0]])
                    skip(vm, 2)
                elif offset == 0x2001f:
                    events.append(['keyPressed', bool(queue)]); skip(vm, ax=int(bool(queue)))
                elif offset == 0x20028:
                    key = queue.pop(0); events.append(['readKey', key]); skip(vm, ax=key)
                elif offset == END:
                    closed[0] = True; vm.emu_stop()
            u.hook_add(UC_HOOK_CODE, hook)
            u.emu_start(START-header, 0x7ffff, count=50000)
            assert loops[0] == (keys.index(27) + 1 if 27 in keys else (2 if keys else 1))
            assert closed[0] == (keys != [13])
            rows.append(dict(seed=seed, initialKey=initial, keys=keys,
                             loopLimit=limit, iterations=loops[0], closed=closed[0],
                             remainingKeys=queue, lastKey=u.mem_read(0x5366a, 1)[0],
                             afterSeed=struct.unpack('<I', u.mem_read(0x5364c, 4))[0], events=events))
    return dict(scope=__doc__.strip(), executableSha256=hashlib.sha256(exe).hexdigest(),
                fragment=dict(start=START, end=END, sha256=hashlib.sha256(exe[START:END]).hexdigest()),
                cases=rows)


def check():
    assert json.loads(OUT.read_text()) == build()
    print('Original ThunderEffect shared c, RNG-before-key and FIFO: verified')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--check', action='store_true')
    if p.parse_args().check: check()
    else:
        OUT.write_text(json.dumps(build(), indent=2) + '\n')
        check()

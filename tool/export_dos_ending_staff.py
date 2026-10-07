#!/usr/bin/env python3
"""Run the original compiled End_Demo staff loop with synthetic keyboard input.

BGI image/sprite drawing and CRT keyboard/delay calls are observed at call
boundaries. The original loop, y wrap, sprite sequence and exit guard execute
unchanged; this is not full native BGI or campaign execution.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'test/fixtures/dos_ending_staff.json'
START, LOOP, END = 0x20544, 0x2055d, 0x2064d


def build():
    from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_CODE
    from unicorn.x86_const import (UC_X86_REG_CS, UC_X86_REG_DS,
        UC_X86_REG_SS, UC_X86_REG_SP, UC_X86_REG_BP, UC_X86_REG_AX,
        UC_X86_REG_IP)
    exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    header = struct.unpack_from('<H', exe, 8)[0] * 16
    rows = []
    for keys in [[27], [65, 27], [65, 13, 27], [27, 27], [65] * 177 + [27], []]:
        vm = Uc(UC_ARCH_X86, UC_MODE_16)
        vm.mem_map(0, 0x80000)
        vm.mem_write(0, exe[header:])
        for r, v in [(UC_X86_REG_CS, 0x1000), (UC_X86_REG_DS, 0x5000),
                     (UC_X86_REG_SS, 0x6000), (UC_X86_REG_SP, 0x7ff0),
                     (UC_X86_REG_BP, 0x8000)]:
            vm.reg_write(r, v)
        vm.mem_write(0x5366a, bytes([27]))
        queue, frames, events = list(keys), [], []
        closed = [False]
        def skip(size, args=0, ax=None):
            if ax is not None: vm.reg_write(UC_X86_REG_AX, ax)
            vm.reg_write(UC_X86_REG_SP, vm.reg_read(UC_X86_REG_SP) + args)
            vm.reg_write(UC_X86_REG_IP, vm.reg_read(UC_X86_REG_IP) + size)
        def hook(u, address, size, data):
            offset = address + header
            sp = vm.reg_read(UC_X86_REG_SP)
            if offset == LOOP and len(frames) == 180:
                vm.emu_stop(); return
            if offset in (0x20579, 0x2059b):
                args = struct.unpack('<5H', vm.mem_read(0x60000 + sp, 10))
                events.append(['erase', args[4], args[3]]); skip(5, 10)
            elif offset == 0x205bf:
                sprite, y, x = struct.unpack('<3H', vm.mem_read(0x60000 + sp, 6))
                frames.append(dict(x=x, y=y, sprite=sprite))
                events.append(['sprite', x, y, sprite]); skip(3, 6)
            elif offset == 0x2061e:
                events.append(['keyPressed', bool(queue)]); skip(5, ax=int(bool(queue)))
            elif offset == 0x20627:
                key = queue.pop(0); events.append(['readKey', key]); skip(5, ax=key)
            elif offset == 0x2063e:
                delay = struct.unpack('<H', vm.mem_read(0x60000 + sp, 2))[0]
                events.append(['delay', delay]); skip(5, 2)
            elif offset == END:
                closed[0] = True; vm.emu_stop()
        vm.hook_add(UC_HOOK_CODE, hook)
        vm.emu_start(START-header, 0x7ffff, count=100000)
        assert closed[0] == bool(keys)
        assert len(frames) == (keys.index(27)+1 if keys else 180)
        assert all(v[1] == 200 for v in events if v[0] == 'delay')
        rows.append(dict(keys=keys, inheritedKey=27, loopLimit=180,
                         closed=closed[0], remainingKeys=queue,
                         lastKey=vm.mem_read(0x5366a, 1)[0], frames=frames, events=events))
    return dict(scope=__doc__.strip(), executableSha256=hashlib.sha256(exe).hexdigest(),
                fragment=dict(start=START, end=END, sha256=hashlib.sha256(exe[START:END]).hexdigest()), cases=rows)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    result = build()
    if args.check:
        assert json.loads(OUT.read_text()) == result
        print('Compiled End_Demo staff FIFO, frames, y wrap and final delay verified')
    else:
        OUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
        print(OUT)

if __name__ == '__main__': main()

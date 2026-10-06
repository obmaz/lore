#!/usr/bin/env python3
"""Unchanged Train_Center level CASE dispatch and shortfall subtraction.
Synthetic XP, initialized previous j and gold; not a full DOS training replay.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'test/fixtures/dos_training_dispatch.json'
FRAGMENTS = [('level-case', 0x2d9d9, 0x2db59),
             ('shortfall', 0x2dd30, 0x2dd3f)]


def build():
    from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_CODE
    from unicorn.x86_const import (UC_X86_REG_CS, UC_X86_REG_DS,
        UC_X86_REG_SS, UC_X86_REG_SP, UC_X86_REG_BP, UC_X86_REG_AX,
        UC_X86_REG_DX)
    exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    header = struct.unpack_from('<H', exe, 8)[0] * 16
    def machine():
        u = Uc(UC_ARCH_X86, UC_MODE_16)
        u.mem_map(0, 0x80000)
        u.mem_write(0, exe[header:])
        for r, v in [(UC_X86_REG_CS, 0x2000), (UC_X86_REG_DS, 0x5000),
                     (UC_X86_REG_SS, 0x6000), (UC_X86_REG_SP, 0xff00),
                     (UC_X86_REG_BP, 0x8000)]:
            u.reg_write(r, v)
        return u
    def run(u, start, stop):
        reached = []
        def hook(vm, address, size, data):
            if address == stop - header:
                reached.append(True)
                vm.emu_stop()
        h = u.hook_add(UC_HOOK_CODE, hook)
        try:
            u.emu_start(start-header, 0x7ffff, count=100000)
        finally:
            u.hook_del(h)
        assert reached, hex(start)
    levels = []
    experiences = [-2147483648, -65537, -65536, -64036, -59536, -1,
                   0, 1499, 1500, 5999, 6000, 19999, 20000,
                   50000, 5100000, 327680000, 655360000, 655380000,
                   655410000, 1310750000, 2147483647]
    for experience in experiences:
        for previous in [0, 3, 15, 20]:
            u = machine()
            u.mem_write(0x53666, struct.pack('<i', experience))
            u.mem_write(0x67ffc, struct.pack('<h', previous))
            run(u, 0x2d9d9, 0x2db59)
            levels.append(dict(experience=experience, previousLevel=previous,
                level=struct.unpack('<h', u.mem_read(0x67ffc, 2))[0]))
    shortfalls = []
    for gold, cost in [(1, 5), (-2147483648, 3), (-2147483647, 24000),
                       (0, 40000), (40000, 40000)]:
        u = machine()
        u.mem_write(0x564ce, struct.pack('<i', gold))
        u.mem_write(0x53666, struct.pack('<i', cost))
        run(u, 0x2dd30, 0x2dd3f)
        bits = u.reg_read(UC_X86_REG_AX) | u.reg_read(UC_X86_REG_DX) << 16
        signed = bits if bits < 0x80000000 else bits - 0x100000000
        shortfalls.append(dict(gold=gold, cost=cost, shortfall=signed))
    return dict(scope=__doc__.strip(), exeSha256=hashlib.sha256(exe).hexdigest(),
        fragments=[dict(name=n, start=a, end=z,
            sha256=hashlib.sha256(exe[a:z]).hexdigest()) for n,a,z in FRAGMENTS],
        levels=levels, shortfalls=shortfalls,
        limitation='Previous j is supplied explicitly. Initial uninitialized stack contents are not inferred. The Dart port rejects a first unmatched CASE without a known previous j.')


def check():
    d = json.loads(OUT.read_text())
    exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    assert d['exeSha256'] == hashlib.sha256(exe).hexdigest()
    for row, (n,a,z) in zip(d['fragments'], FRAGMENTS, strict=True):
        assert row == dict(name=n, start=a, end=z,
                          sha256=hashlib.sha256(exe[a:z]).hexdigest())
    print('Original training CASE and shortfall fragments checked')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--check', action='store_true')
    if p.parse_args().check:
        check()
    else:
        OUT.write_text(json.dumps(build(), indent=2)+'\n')
        check()

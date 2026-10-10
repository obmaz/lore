#!/usr/bin/env python3
"""Execute original lava and EnemyAttack dispatch with the original RNG.
Synthetic records/seed; UI and full battle/campaign replay are separate gates.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'test/fixtures/dos_random_order.json'
FRAGMENTS = [('lava-roll', 0x7c70, 0x7c94),
             ('enemy-dispatch', 0x24901, 0x24947),
             ('random', 225719, 225865)]

def build():
    from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_CODE
    from unicorn.x86_const import (UC_X86_REG_CS, UC_X86_REG_DS,
        UC_X86_REG_SS, UC_X86_REG_SP, UC_X86_REG_BP)
    exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    header = struct.unpack_from('<H', exe, 8)[0] * 16
    def machine(seed):
        u = Uc(UC_ARCH_X86, UC_MODE_16)
        u.mem_map(0, 0x80000)
        u.mem_write(0, exe[header:])
        for r, v in [(UC_X86_REG_DS, 0x5000), (UC_X86_REG_SS, 0x6000),
                     (UC_X86_REG_SP, 0xff00), (UC_X86_REG_BP, 0x8000)]:
            u.reg_write(r, v)
        u.mem_write(0x5364c, struct.pack('<I', seed))
        return u
    def run(u, start, stops):
        calls, hit = [], []
        def hook(vm, address, size, data):
            if address == 225719 - header:
                sp = vm.reg_read(UC_X86_REG_SP)
                calls.append(struct.unpack('<H', vm.mem_read(0x60000 + sp + 4, 2))[0])
            if address + header in stops:
                hit.append(address + header)
                vm.emu_stop()
        h = u.hook_add(UC_HOOK_CODE, hook)
        u.reg_write(UC_X86_REG_CS, 0 if start < 0x15370 else 0x1000)
        try:
            u.emu_start(start - header, 0x7ffff, count=10000)
        finally:
            u.hook_del(h)
        assert len(hit) == 1
        return calls, hit[0], struct.unpack('<I', u.mem_read(0x5364c, 4))[0]
    lava, dispatch = [], []
    for seed in [0, 1, 0xdeadbeef, 0xffffffff]:
        for luck in [[0]*6, [1, 5, 10, 20, 128, 255], [10]*6]:
            u = machine(seed)
            for i, v in enumerate(luck, 1):
                p = bytearray(55); p[29] = v
                u.mem_write(0x564ff + i*55, bytes(p))
            bounds, damages = [], []
            for i in range(1, 7):
                u.mem_write(0x5702e, struct.pack('<h', i))
                calls, _, after = run(u, 0x7c70, [0x7c94])
                bounds.extend(calls)
                damages.append(struct.unpack('<h', u.mem_read(0x53660, 2))[0])
            assert bounds == [v for l in luck for v in (l, 40)]
            lava.append(dict(seed=seed, luck=luck, bounds=bounds, damages=damages, afterSeed=after))
        for arms, magic, strength in [(10, 3, 20), (20, 20, 20), (0, 0, 20),
                                      (255, 128, 20), (66, 65, 20), (20, 1, 0)]:
            u = machine(seed)
            u.mem_write(0x53d9e, struct.pack('<h', 1))
            e = bytearray(35); e[18] = strength; e[23] = arms; e[24] = magic
            u.mem_write(0x56f38, bytes(e))
            bounds, stop, after = run(u, 0x24901, [0x2493d, 0x24943])
            assert bounds == [(magic*1000) & 0xffff, (arms*1000) & 0xffff]
            dispatch.append(dict(seed=seed, arms=arms, magic=magic, strength=strength,
                                 bounds=bounds, weapon=stop == 0x2493d, afterSeed=after))
    return dict(scope=__doc__.strip(), exeSha256=hashlib.sha256(exe).hexdigest(),
        fragments=[dict(name=n, start=a, end=z, sha256=hashlib.sha256(exe[a:z]).hexdigest())
                   for n,a,z in FRAGMENTS], lava=lava, dispatch=dispatch)

def check():
    d = json.loads(OUT.read_text())
    exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    assert d['exeSha256'] == hashlib.sha256(exe).hexdigest()
    for row, (n,a,z) in zip(d['fragments'], FRAGMENTS, strict=True):
        assert row == dict(name=n, start=a, end=z, sha256=hashlib.sha256(exe[a:z]).hexdigest())
    print('Original RNG evaluation order evidence checked')

if __name__ == '__main__':
    p=argparse.ArgumentParser(description=__doc__); p.add_argument('--check', action='store_true')
    if p.parse_args().check: check()
    else: OUT.write_text(json.dumps(build(), indent=2)+'\n'); check()

#!/usr/bin/env python3
"""Execute original CastAttack modes 1..3 through target dispatch only.
Synthetic party records and seeds; stops before spell effects/UI, not a full battle.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'test/fixtures/dos_enemy_magic_targets.json'
FRAGMENTS = [('target-dispatch', 0x235ee, 0x237cd),
             ('exist', 0x29cf8, 0x29d41),
             ('random', 225719, 225865)]

def build():
    from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_CODE
    from unicorn.x86_const import (UC_X86_REG_CS, UC_X86_REG_DS,
        UC_X86_REG_SS, UC_X86_REG_SP, UC_X86_REG_BP)
    exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    header = struct.unpack_from('<H', exe, 8)[0] * 16
    rows = []
    for mode in [1, 2, 3]:
        for mask in range(64):
            for blank in [False, True]:
                for seed in [0, 1, 0xdeadbeef, 0xffffffff]:
                    u = Uc(UC_ARCH_X86, UC_MODE_16)
                    u.mem_map(0, 0x80000)
                    u.mem_write(0, exe[header:])
                    for r, v in [(UC_X86_REG_CS, 0x1000), (UC_X86_REG_DS, 0x5000),
                                 (UC_X86_REG_SS, 0x6000), (UC_X86_REG_SP, 0x7e00),
                                 (UC_X86_REG_BP, 0x8000)]:
                        u.reg_write(r, v)
                    u.mem_write(0x5364c, struct.pack('<I', seed))
                    u.mem_write(0x53d9e, struct.pack('<h', 1))
                    e = bytearray(35); e[27] = mode
                    u.mem_write(0x56f38, bytes(e))
                    for slot in range(1, 7):
                        live = bool(mask & (1 << (slot - 1)))
                        p = bytearray(55)
                        if live or not blank: p[0:2] = b'\x01X'
                        struct.pack_into('<h', p, 35, 20 if live else 0)
                        struct.pack_into('<h', p, 31, 0 if live else 1)
                        u.mem_write(0x564ff + slot * 55, bytes(p))
                    bounds, hits = [], []
                    def hook(vm, address, size, data):
                        if address == 225719 - header:
                            sp = vm.reg_read(UC_X86_REG_SP)
                            bounds.append(struct.unpack('<H', vm.mem_read(0x60000 + sp + 4, 2))[0])
                        if address + header in [0x23632, 0x236de, 0x237be, 0x237c7]:
                            hits.append(address + header)
                            vm.emu_stop()
                    u.hook_add(UC_HOOK_CODE, hook)
                    u.emu_start(0x235ee - header, 0x7ffff, count=10000)
                    assert len(hits) == 1, (mode, mask, blank, seed, hits)
                    all_targets = hits[0] == 0x237c7
                    target = None if all_targets else struct.unpack('<h', u.mem_read(0x67ffc, 2))[0]
                    rows.append(dict(mode=mode, mask=mask, blank=blank, seed=seed,
                                     bounds=bounds, target=target, all=all_targets,
                                     afterSeed=struct.unpack('<I', u.mem_read(0x5364c, 4))[0]))
    return dict(scope=__doc__.strip(), exeSha256=hashlib.sha256(exe).hexdigest(),
                fragments=[dict(name=n, start=a, end=z,
                                sha256=hashlib.sha256(exe[a:z]).hexdigest())
                           for n, a, z in FRAGMENTS], cases=rows)

def check():
    d = json.loads(OUT.read_text())
    exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    assert d['exeSha256'] == hashlib.sha256(exe).hexdigest()
    assert len(d['cases']) == 1536
    for row, (n, a, z) in zip(d['fragments'], FRAGMENTS, strict=True):
        assert row == dict(name=n, start=a, end=z, sha256=hashlib.sha256(exe[a:z]).hexdigest())
    print('Original enemy magic target dispatch evidence checked')

if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--check', action='store_true')
    if p.parse_args().check: check()
    else:
        OUT.write_text(json.dumps(build(), indent=2) + '\n')
        check()

#!/usr/bin/env python3
"""Run original mode4..6 decisions and unsupported byte CastAttack selectors.
Uses native Exist and RNG.
Synthetic records. Stop at first attack/cure/armor effect; no UI or effect replay.
"""
import argparse
import hashlib
import itertools
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'test/fixtures/dos_enemy_ai_dispatch.json'
FRAGMENTS = [('dispatch', 0x235ee, 0x23e2d), ('exist', 0x29cf8, 0x29d41),
             ('random', 225719, 225865)]
SEEDS = [0, 1, 0xdeadbeef, 0xffffffff]
PARTY_HP = [20, 7, 7, 99, 1, 10]
ARMORS = [[6] * 6, [0] * 6, [4] * 6, [5] * 6,
          [4, 4, 4, 4, 4, 5], [0, 4, 5, 6, 10, 255]]
# hp, endurance, level, mentality. Includes self-threshold equality,
# group eligible/ineligible, enemy-count threshold and signed aggregate wrap.
LAYOUTS = [[(400, 20, 20, 20)], [(132, 20, 20, 20)],
           [(133, 20, 20, 20)], [(133, 20, 20, 20), (0, 20, 20, 20)],
           [(133, 20, 20, 20), (0, 20, 20, 20), (0, 20, 20, 20)],
           [(133, 20, 20, 20), (400, 20, 20, 20), (400, 20, 20, 20)],
           [(12000, 100, 150, 20)] * 3]
STOPS = {0x23908: 'one', 0x23af4: 'one', 0x23e1f: 'one',
         0x23911: 'all', 0x23afd: 'all', 0x23e28: 'all',
         0x23831: 'self-cure', 0x2397b: 'self-cure', 0x23b67: 'self-cure',
         0x23a8a: 'group-cure', 0x23d83: 'group-cure', 0x23bc8: 'armor',
         0x23e2c: 'none'}


def build():
    from unicorn import Uc, UcError, UC_ARCH_X86, UC_MODE_16, UC_HOOK_CODE
    from unicorn.x86_const import (UC_X86_REG_AX, UC_X86_REG_CS, UC_X86_REG_DS,
        UC_X86_REG_SS, UC_X86_REG_SP, UC_X86_REG_BP, UC_X86_REG_IP)
    exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    header = struct.unpack_from('<H', exe, 8)[0] * 16
    rows = []
    inputs = [(m, k, b, l, s, 0) for m, k, b, l, s in itertools.product(
        [4, 5, 6], range(64), [False, True], range(len(LAYOUTS)), SEEDS)]
    inputs.extend((6, k, True, l, s, a) for k, l, s, a in itertools.product(
        [0, 1, 3, 16, 63], [0, 4], SEEDS, range(1, len(ARMORS))))
    inputs.extend((m, 63, False, 0, 0, 0) for m in [0, *range(7, 256)])
    for mode, mask, blank, layout, seed, armor in inputs:
        u = Uc(UC_ARCH_X86, UC_MODE_16)
        u.mem_map(0, 0x80000)
        u.mem_write(0, exe[header:])
        for r, v in [(UC_X86_REG_CS, 0x1000), (UC_X86_REG_DS, 0x5000),
                     (UC_X86_REG_SS, 0x6000), (UC_X86_REG_SP, 0x7e00),
                     (UC_X86_REG_BP, 0x8000)]:
            u.reg_write(r, v)
        u.mem_write(0x5364c, struct.pack('<I', seed))
        u.mem_write(0x53d9e, struct.pack('<h', 1))
        u.mem_write(0x56f37, bytes([len(LAYOUTS[layout])]))
        for slot, (hp, endurance, level, mentality) in enumerate(LAYOUTS[layout], 1):
            e = bytearray(35)
            e[19], e[20], e[27], e[29] = mentality, endurance, mode, level
            struct.pack_into('<h', e, 30, hp)
            u.mem_write(0x56f15 + slot * 35, bytes(e))
        for slot, hp in enumerate(PARTY_HP, 1):
            live = bool(mask & (1 << (slot - 1)))
            p = bytearray(55)
            if live or not blank: p[0:2] = b'\x01X'
            p[44] = ARMORS[armor][slot - 1]
            struct.pack_into('<h', p, 35, hp if live else 0)
            struct.pack_into('<h', p, 31, 0 if live else 1)
            u.mem_write(0x564ff + slot * 55, bytes(p))
        bounds, hits = [], []
        def hook(vm, address, size, data):
            if address == 225719 - header:
                sp = vm.reg_read(UC_X86_REG_SP)
                bounds.append(struct.unpack('<H', vm.mem_read(0x60000 + sp + 4, 2))[0])
            if address + header in STOPS:
                hits.append(address + header)
                vm.emu_stop()
        u.hook_add(UC_HOOK_CODE, hook)
        row = dict(mode=mode, mask=mask, blank=blank, layout=layout, seed=seed, armor=armor)
        try:
            u.emu_start(0x235ee - header, 0x7ffff, count=20000)
            assert len(hits) == 1, (row, hits)
            effect = STOPS[hits[0]]
            row['effect'] = effect
            if effect == 'one':
                row['target'] = struct.unpack('<h', u.mem_read(0x67ffc, 2))[0]
            if effect.endswith('cure'):
                row['amount'] = u.reg_read(UC_X86_REG_AX)
                sp = u.reg_read(UC_X86_REG_SP)
                row['target'] = struct.unpack('<h', u.mem_read(0x60000 + sp, 2))[0]
        except UcError:
            ip = 0x10000 + u.reg_read(UC_X86_REG_IP) + header
            assert mode == 6 and mask == 0 and blank and ip == 0x23bab, (row, hex(ip))
            row['effect'] = 'armor-division-zero'
        row['bounds'] = bounds
        row['afterSeed'] = struct.unpack('<I', u.mem_read(0x5364c, 4))[0]
        rows.append(row)
    return dict(scope=__doc__.strip(), exeSha256=hashlib.sha256(exe).hexdigest(),
                fragments=[dict(name=n, start=a, end=z, sha256=hashlib.sha256(exe[a:z]).hexdigest())
                           for n, a, z in FRAGMENTS], partyHp=PARTY_HP,
                layouts=[[list(e) for e in row] for row in LAYOUTS],
                armors=ARMORS, cases=rows)


def check():
    data = json.loads(OUT.read_text())
    assert data['scope'] == __doc__.strip()
    exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    assert data['exeSha256'] == hashlib.sha256(exe).hexdigest()
    assert len(data['cases']) == 11202
    assert data['layouts'] == [[list(e) for e in row] for row in LAYOUTS]
    assert data['partyHp'] == PARTY_HP
    assert data['armors'] == ARMORS
    for row, (n, a, z) in zip(data['fragments'], FRAGMENTS, strict=True):
        assert row == dict(name=n, start=a, end=z, sha256=hashlib.sha256(exe[a:z]).hexdigest())
    print('Original seeded enemy AI dispatch evidence checked')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    if parser.parse_args().check: check()
    else:
        OUT.write_text(json.dumps(build(), indent=2) + '\n')
        check()

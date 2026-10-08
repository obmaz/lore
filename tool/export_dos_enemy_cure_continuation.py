#!/usr/bin/env python3
"""Execute mode4..6 complete cure continuations and original enemycure stores.
Native RNG/decision/iteration/return. Synthetic records; cure Print span bypassed.
Stops at CastAttack return; does not cover rendered UI or spell attack effects.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'test/fixtures/dos_enemy_cure_continuation.json'
FRAGMENTS = [('castattack', 0x235ee, 0x23e2d), ('enemycure', 0x23478, 0x23593),
             ('exist', 0x29cf8, 0x29d41), ('random', 225719, 225865)]


def build():
    from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_CODE
    from unicorn.x86_const import (UC_X86_REG_CS, UC_X86_REG_DS, UC_X86_REG_SS,
        UC_X86_REG_SP, UC_X86_REG_BP, UC_X86_REG_IP)
    exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    header = struct.unpack_from('<H', exe, 8)[0] * 16
    decisions = json.loads((ROOT / 'test/fixtures/dos_enemy_ai_dispatch.json').read_text())
    selected = {}
    for r in decisions['cases']:
        if r['effect'].endswith('cure'):
            key = (r['mode'], r['layout'], r['seed'], r['armor'], r['effect'])
            selected.setdefault(key, r)
    cases = []
    for row in selected.values():
        for status in ['normal', 'dead', 'unconscious', 'mixed']:
            u = Uc(UC_ARCH_X86, UC_MODE_16)
            u.mem_map(0, 0x80000)
            u.mem_write(0, exe[header:])
            for reg, value in [(UC_X86_REG_CS, 0x1000), (UC_X86_REG_DS, 0x5000),
                               (UC_X86_REG_SS, 0x6000), (UC_X86_REG_SP, 0x7e00),
                               (UC_X86_REG_BP, 0x8000)]:
                u.reg_write(reg, value)
            u.mem_write(0x5364c, struct.pack('<I', row['seed']))
            u.mem_write(0x53d9e, struct.pack('<h', 1))
            enemies = decisions['layouts'][row['layout']]
            u.mem_write(0x56f37, bytes([len(enemies)]))
            before = []
            for slot, (hp, endurance, level, mentality) in enumerate(enemies, 1):
                dead = status == 'dead' or status == 'mixed' and slot % 3 == 1
                unconscious = status == 'unconscious' or status == 'mixed' and slot % 3 == 2
                e = bytearray(35)
                e[19], e[20], e[27], e[29] = mentality, endurance, row['mode'], level
                e[33], e[34] = int(unconscious), int(dead)
                struct.pack_into('<h', e, 30, hp)
                u.mem_write(0x56f15 + slot * 35, bytes(e))
                before.append(dict(hp=hp, endurance=endurance, level=level,
                                   mentality=mentality, dead=dead, unconscious=unconscious))
            for slot in range(1, 7):
                live = bool(row['mask'] & (1 << (slot - 1)))
                p = bytearray(55)
                if live or not row['blank']: p[0:2] = b'\x01X'
                p[44] = decisions['armors'][row['armor']][slot - 1]
                struct.pack_into('<h', p, 35, decisions['partyHp'][slot - 1] if live else 0)
                struct.pack_into('<h', p, 31, 0 if live else 1)
                u.mem_write(0x564ff + slot * 55, bytes(p))
            bounds, cures, stops = [], [], []
            def hook(vm, address, size, data):
                offset = address + header
                sp = vm.reg_read(UC_X86_REG_SP)
                if address == 225719 - header:
                    bounds.append(struct.unpack('<H', vm.mem_read(0x60000 + sp + 4, 2))[0])
                if offset == 0x23478:
                    amount, target = struct.unpack('<hh', vm.mem_read(0x60000 + sp + 4, 4))
                    cures.append([target, amount])
                if offset == 0x23487:
                    vm.reg_write(UC_X86_REG_IP, 0x234f8 - header - 0x10000)
                if offset == 0x23e2c:
                    stops.append(offset)
                    vm.emu_stop()
            u.hook_add(UC_HOOK_CODE, hook)
            u.emu_start(0x235ee - header, 0x7ffff, count=30000)
            assert stops == [0x23e2c] and cures
            after = []
            for slot in range(1, len(enemies) + 1):
                e = bytes(u.mem_read(0x56f15 + slot * 35, 35))
                after.append(dict(hp=struct.unpack_from('<h', e, 30)[0],
                                  dead=bool(e[34]), unconscious=bool(e[33])))
            cases.append(dict(mode=row['mode'], mask=row['mask'], blank=row['blank'],
                              ac=decisions['armors'][row['armor']], seed=row['seed'],
                              effect=row['effect'], status=status, before=before,
                              after=after, cures=cures, bounds=bounds,
                              afterSeed=struct.unpack('<I', u.mem_read(0x5364c, 4))[0]))
    return dict(scope=__doc__.strip(), exeSha256=hashlib.sha256(exe).hexdigest(),
                fragments=[dict(name=n, start=a, end=z, sha256=hashlib.sha256(exe[a:z]).hexdigest())
                           for n, a, z in FRAGMENTS],
                bypassedUiSpan=dict(start=0x23487, end=0x234f8),
                partyHp=decisions['partyHp'], cases=cases)


def check():
    data = json.loads(OUT.read_text())
    assert data['scope'] == __doc__.strip()
    exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    assert data['exeSha256'] == hashlib.sha256(exe).hexdigest()
    assert len(data['cases']) == 112
    for row, (n, a, z) in zip(data['fragments'], FRAGMENTS, strict=True):
        assert row == dict(name=n, start=a, end=z, sha256=hashlib.sha256(exe[a:z]).hexdigest())
    assert data['bypassedUiSpan'] == dict(start=0x23487, end=0x234f8)
    print('Original cure iteration/store/return evidence checked (UI bypassed)')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    if parser.parse_args().check: check()
    else:
        OUT.write_text(json.dumps(build(), indent=2) + '\n')
        check()

#!/usr/bin/env python3
"""Execute original mode6 armor slot loop, RNG, luck comparison and AC stores.
Synthetic records. String/Print spans bypassed; stop before display_condition.
Message color/order observed at original branch entrances, not rendered DOS UI.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'test/fixtures/dos_enemy_armor_effects.json'
FRAGMENTS = [('castattack', 0x235ee, 0x23e2d), ('random', 225719, 225865)]
# Skip complete UI spans before any argument push. Do not replace game logic.
UI_SKIPS = {0x23be0: (0x23c1e, 13), 0x23c35: (0x23c9f, 7),
            0x23c66: (0x23c8c, 5)}


def build():
    from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_CODE
    from unicorn.x86_const import (UC_X86_REG_AX, UC_X86_REG_CS, UC_X86_REG_DS,
        UC_X86_REG_SS, UC_X86_REG_SP, UC_X86_REG_BP, UC_X86_REG_IP)
    exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    header = struct.unpack_from('<H', exe, 8)[0] * 16
    decisions = json.loads((ROOT / 'test/fixtures/dos_enemy_ai_dispatch.json').read_text())
    selected = [r for r in decisions['cases']
                if r['mode'] == 6 and r['layout'] == 0 and r['effect'] == 'armor']
    assert len(selected) == 133

    def run(row, luck):
        u = Uc(UC_ARCH_X86, UC_MODE_16)
        u.mem_map(0, 0x80000)
        u.mem_write(0, exe[header:])
        for reg, value in [(UC_X86_REG_CS, 0x1000), (UC_X86_REG_DS, 0x5000),
                           (UC_X86_REG_SS, 0x6000), (UC_X86_REG_SP, 0x7e00),
                           (UC_X86_REG_BP, 0x8000)]:
            u.reg_write(reg, value)
        u.mem_write(0x5364c, struct.pack('<I', row['seed']))
        u.mem_write(0x53d9e, struct.pack('<h', 1))
        e = bytearray(35); e[19], e[20], e[27], e[29] = 20, 20, 6, 20
        struct.pack_into('<h', e, 30, 400)
        u.mem_write(0x56f38, bytes(e))
        initial = []
        for slot in range(1, 7):
            live = bool(row['mask'] & (1 << (slot - 1)))
            p = bytearray(55)
            if live or not row['blank']: p[0:2] = b'\x01X'
            p[29], p[44] = luck[slot - 1], decisions['armors'][row['armor']][slot - 1]
            struct.pack_into('<h', p, 35, decisions['partyHp'][slot - 1] if live else 0)
            struct.pack_into('<h', p, 31, 0 if live else 1)
            initial.append(bytes(p))
            u.mem_write(0x564ff + slot * 55, bytes(p))
        bounds, rolls, messages, stops = [], [], [], []
        def hook(vm, address, size, data):
            offset = address + header
            if address == 225719 - header:
                sp = vm.reg_read(UC_X86_REG_SP)
                bounds.append(struct.unpack('<H', vm.mem_read(0x60000 + sp + 4, 2))[0])
            if offset == 0x23c25:
                slot = struct.unpack('<h', vm.mem_read(0x67ffe, 2))[0]
                rolls.append([slot, vm.reg_read(UC_X86_REG_AX)])
            if offset in UI_SKIPS:
                destination, color = UI_SKIPS[offset]
                slot = struct.unpack('<h', vm.mem_read(0x67ffe, 2))[0]
                messages.append([slot, color])
                vm.reg_write(UC_X86_REG_IP, destination - header - 0x10000)
            if offset == 0x23ca8:
                stops.append(offset)
                vm.emu_stop()
        u.hook_add(UC_HOOK_CODE, hook)
        u.emu_start(0x235ee - header, 0x7ffff, count=20000)
        assert stops == [0x23ca8]
        after = [bytes(u.mem_read(0x564ff + slot * 55, 55)) for slot in range(1, 7)]
        for a, b in zip(initial, after, strict=True):
            assert a[:44] == b[:44] and a[45:] == b[45:], 'Only AC may change'
        return dict(mask=row['mask'], blank=row['blank'], seed=row['seed'],
                    ac=decisions['armors'][row['armor']], luck=luck,
                    rolls=rolls, bounds=bounds, messages=messages,
                    afterAc=[p[44] for p in after],
                    afterSeed=struct.unpack('<I', u.mem_read(0x5364c, 4))[0])

    cases = []
    for row in selected:
        baseline = run(row, [0] * 6)
        luck_patterns = [[0] * 6, [255] * 6, [19] * 6, [20] * 6,
                         [0, 1, 10, 19, 20, 21]]
        for delta in [-1, 0, 1]:
            luck = [0] * 6
            for slot, value in baseline['rolls']:
                luck[slot - 1] = max(0, value + delta)
            luck_patterns.append(luck)
        for index, luck in enumerate(luck_patterns):
            result = run(row, luck)
            result['pattern'] = index
            cases.append(result)
    return dict(scope=__doc__.strip(), exeSha256=hashlib.sha256(exe).hexdigest(),
                fragments=[dict(name=n, start=a, end=z, sha256=hashlib.sha256(exe[a:z]).hexdigest())
                           for n, a, z in FRAGMENTS],
                bypassedUiSpans=[dict(start=a, end=b, color=c) for a, (b, c) in UI_SKIPS.items()],
                partyHp=decisions['partyHp'], cases=cases)


def check():
    data = json.loads(OUT.read_text())
    assert data['scope'] == __doc__.strip()
    exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    assert data['exeSha256'] == hashlib.sha256(exe).hexdigest()
    assert len(data['cases']) == 1064
    for row, (n, a, z) in zip(data['fragments'], FRAGMENTS, strict=True):
        assert row == dict(name=n, start=a, end=z, sha256=hashlib.sha256(exe[a:z]).hexdigest())
    assert data['bypassedUiSpans'] == [dict(start=a, end=b, color=c) for a, (b, c) in UI_SKIPS.items()]
    print('Original armor loop/RNG/store evidence checked (UI bypassed)')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    if parser.parse_args().check: check()
    else:
        OUT.write_text(json.dumps(build(), indent=2) + '\n')
        check()

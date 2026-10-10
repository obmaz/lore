#!/usr/bin/env python3
"""Execute original SpecialAttack target/RNG/status/HP stores and return.
Synthetic records; entire string/Print spans bypassed before argument pushes.
Color/slot events captured at original branch entrances, not rendered DOS UI.
"""
import argparse
import hashlib
import itertools
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'test/fixtures/dos_enemy_special_attack.json'
FRAGMENTS = [('specialattack', 0x23f47, 0x24473), ('random', 225719, 225865)]
HP = [30, 0, -10, 32767, 1, 20]
SEEDS = [0, 1, 0xdeadbeef, 0xffffffff]
UI_SKIPS = {0x24019: (0x24058, 13), 0x2406e: (0x2446f, 7),
            0x24095: (0x2446f, 7), 0x240c9: (0x240f0, 4),
            0x241b6: (0x241f5, 13), 0x2420b: (0x2446f, 7),
            0x24232: (0x2446f, 7), 0x24266: (0x2428d, 4),
            0x2436b: (0x243aa, 13), 0x243c0: (0x2446f, 7),
            0x243e7: (0x2446f, 7), 0x2441a: (0x24441, 4)}
ROLLS = {0x2405f: 'agility', 0x24084: 'luck', 0x241fc: 'agility',
         0x24221: 'luck', 0x243b1: 'agility', 0x243d6: 'luck'}


def build():
    from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_CODE
    from unicorn.x86_const import (UC_X86_REG_AX, UC_X86_REG_CS, UC_X86_REG_DS,
        UC_X86_REG_SS, UC_X86_REG_SP, UC_X86_REG_BP, UC_X86_REG_IP)
    exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    header = struct.unpack_from('<H', exe, 8)[0] * 16

    def run(mode, mask, blank, seed, agility, luck):
        u = Uc(UC_ARCH_X86, UC_MODE_16)
        u.mem_map(0, 0x80000)
        u.mem_write(0, exe[header:])
        for reg, value in [(UC_X86_REG_CS, 0x1000), (UC_X86_REG_DS, 0x5000),
                           (UC_X86_REG_SS, 0x6000), (UC_X86_REG_SP, 0x7e00),
                           (UC_X86_REG_BP, 0x8000)]:
            u.reg_write(reg, value)
        u.mem_write(0x5364c, struct.pack('<I', seed))
        u.mem_write(0x53d9e, struct.pack('<h', 1))
        e = bytearray(35); e[22], e[26] = agility, mode
        u.mem_write(0x56f38, bytes(e))
        before = []
        for slot in range(1, 7):
            eligible = bool(mask & (1 << (slot - 1)))
            p = bytearray(55)
            if eligible or not blank: p[0:2] = b'\x01X'
            p[29] = luck
            poison = 0 if mode != 1 or eligible else 255
            unconscious = 0 if mode != 2 or eligible else [1, -1, 32767, 2, -32768, 3][slot - 1]
            dead = 0 if mode != 3 or eligible else [1, -1, 32767, 2, -32768, 3][slot - 1]
            p[30] = poison
            struct.pack_into('<hhh', p, 31, unconscious, dead, HP[slot - 1])
            u.mem_write(0x564ff + slot * 55, bytes(p))
            before.append(dict(name=bool(p[0]), hp=HP[slot - 1], poison=poison,
                               unconscious=unconscious, dead=dead))
        bounds, rolls, events, stops = [], [], [], []
        def hook(vm, address, size, data):
            offset = address + header
            if address == 225719 - header:
                sp = vm.reg_read(UC_X86_REG_SP)
                bounds.append(struct.unpack('<H', vm.mem_read(0x60000 + sp + 4, 2))[0])
            if offset in ROLLS:
                rolls.append([ROLLS[offset], vm.reg_read(UC_X86_REG_AX)])
            if offset in UI_SKIPS:
                destination, color = UI_SKIPS[offset]
                target = struct.unpack('<h', vm.mem_read(0x53660, 2))[0]
                events.append([target, color])
                vm.reg_write(UC_X86_REG_IP, destination - header - 0x10000)
            if offset == 0x2446f:
                stops.append(offset)
                vm.emu_stop()
        u.hook_add(UC_HOOK_CODE, hook)
        u.emu_start(0x23f56 - header, 0x7ffff, count=20000)
        assert stops == [0x2446f]
        after = []
        for slot in range(1, 7):
            p = bytes(u.mem_read(0x564ff + slot * 55, 55))
            unconscious, dead, hp = struct.unpack_from('<hhh', p, 31)
            after.append(dict(name=bool(p[0]), hp=hp, poison=p[30],
                              unconscious=unconscious, dead=dead))
        return dict(mode=mode, mask=mask, blank=blank, seed=seed, agility=agility,
                    luck=luck, before=before, after=after, bounds=bounds,
                    rolls=rolls, events=events,
                    afterSeed=struct.unpack('<I', u.mem_read(0x5364c, 4))[0])

    cases = []
    for mode, mask, blank, seed in itertools.product([1, 2, 3], range(64), [False, True], SEEDS):
        baseline = run(mode, mask, blank, seed, 255, 0)
        observed = dict(baseline['rolls'])
        a, l = observed['agility'], observed['luck']
        patterns = [(0, 0), (0, 255), (255, 0), (255, 255),
                    (19, 10), (39, 19), (49, 20), (59, 21),
                    (a, l), (max(0, a - 1), 0), (255, l + 1), (255, max(0, l - 1))]
        for index, (agility, luck) in enumerate(patterns):
            row = run(mode, mask, blank, seed, agility, luck)
            row['pattern'] = index
            cases.append(row)
    for mode in [0, *range(4, 256)]:
        row = run(mode, 63, False, 0, 255, 0)
        row['pattern'] = -1
        cases.append(row)
    return dict(scope=__doc__.strip(), exeSha256=hashlib.sha256(exe).hexdigest(),
                fragments=[dict(name=n, start=a, end=z, sha256=hashlib.sha256(exe[a:z]).hexdigest())
                           for n, a, z in FRAGMENTS],
                bypassedUiSpans=[dict(start=a, end=b, color=c) for a, (b, c) in UI_SKIPS.items()],
                cases=cases)


def check():
    data = json.loads(OUT.read_text())
    exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    assert data['scope'] == __doc__.strip()
    assert len(data['cases']) == 18685
    assert data['exeSha256'] == hashlib.sha256(exe).hexdigest()
    for row, (n, a, z) in zip(data['fragments'], FRAGMENTS, strict=True):
        assert row == dict(name=n, start=a, end=z, sha256=hashlib.sha256(exe[a:z]).hexdigest())
    assert data['bypassedUiSpans'] == [dict(start=a, end=b, color=c) for a, (b, c) in UI_SKIPS.items()]
    print('Original SpecialAttack RNG/target/status evidence checked (UI bypassed)')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    if parser.parse_args().check: check()
    else:
        data = build()
        cases = data.pop('cases')
        # One generated case per line keeps large native replays reviewable.
        prefix = json.dumps(data, indent=2)[:-2]
        records = ',\n'.join('    ' + json.dumps(r, separators=(',', ':')) for r in cases)
        OUT.write_text(prefix + ',\n  "cases": [\n' + records + '\n  ]\n}\n')
        check()

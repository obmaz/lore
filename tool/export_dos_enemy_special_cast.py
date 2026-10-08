#!/usr/bin/env python3
"""Original SpecialCastAttack with real RNG, joinenemy and turn_mind stores.

UI strings/graphics are bypassed before pushes. Display_Condition's numeric
effects are replayed through the unmodified ReturnCondition instruction span.
Summons use original FOEDATA.DAT, constrained to defined template indices.
This does not settle original out-of-range enemydata reads or glyph rendering.
"""
import argparse
import hashlib
import itertools
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'test/fixtures/dos_enemy_special_cast.json'
FRAGMENTS = [('specialcast', 0x24513, 0x24859),
             ('joinenemy', 0x2c847, 0x2c9ab),
             ('turnmind', 0x2c9ab, 0x2cb15),
             ('condition', 0x2ad98, 0x2ade7), ('random', 225719, 225865)]
UI_SKIPS = {0x245dd: 0x24622, 0x246b2: 0x246f7,
            0x24749: 0x24788, 0x2479e: 0x2484d,
            0x247c5: 0x2484d, 0x247f8: 0x2481f}
HP = [-10, 0, 1, 30, 32767, -32768]
SEEDS = [0, 1, 4, 5, 6, 0xdeadbeef, 0xffffffff]


def compact(data):
    """Intern repeated raw records without dropping any observed byte."""
    if 'enemyRecords' in data:
        return data
    for kind in ['Enemy', 'Party']:
        records = []
        ids = {}
        for row in data['cases']:
            for key in ['before' + kind, 'after' + kind]:
                compacted = []
                for record in row[key]:
                    signature = bytes(record)
                    if signature not in ids:
                        ids[signature] = len(records)
                        records.append(record)
                    compacted.append(ids[signature])
                row[key] = compacted
        data[kind.lower() + 'Records'] = records
    return data


def build():
    from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_CODE
    from unicorn.x86_const import (UC_X86_REG_CS, UC_X86_REG_DS, UC_X86_REG_SS,
                                  UC_X86_REG_BP, UC_X86_REG_SP, UC_X86_REG_IP)
    exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    database = (ROOT / 'repo_source/LORE_1993_runtime/FOEDATA.DAT').read_bytes()
    header = struct.unpack_from('<H', exe, 8)[0] * 16
    condition_cache = {}

    def machine(cs=0x1000):
        u = Uc(UC_ARCH_X86, UC_MODE_16)
        u.mem_map(0, 0x80000)
        u.mem_write(0, exe[header:])
        for reg, value in [(UC_X86_REG_CS, cs), (UC_X86_REG_DS, 0x5000),
                           (UC_X86_REG_SS, 0x6000), (UC_X86_REG_SP, 0x7e00),
                           (UC_X86_REG_BP, 0x8000)]:
            u.reg_write(reg, value)
        return u

    def condition(record):
        key = bytes(record)
        if key not in condition_cache:
            u = machine(0x2000)
            u.mem_write(0x50100, key)
            u.mem_write(0x67ffc, struct.pack('<HH', 0x100, 0x5000))
            hit = []
            def stop(vm, address, size, data):
                if address == 0x2ade7 - header:
                    hit.append(True)
                    vm.emu_stop()
            u.hook_add(UC_HOOK_CODE, stop)
            u.emu_start(0x2ad98 - header, 0x7ffff, count=1000)
            assert hit
            condition_cache[key] = bytes(u.mem_read(0x50100, 55))
        return condition_cache[key]

    def run(count, caster, mask, mode, named, seed, agility=255, luck=0,
            special=1, foe_id=40, blank_mask=0, dead_mask=0):
        u = machine()
        u.mem_write(0x566b8, database)
        u.mem_write(0x5364c, struct.pack('<I', seed))
        u.mem_write(0x53d9e, struct.pack('<h', caster))
        u.mem_write(0x56f37, bytes([count]))
        before_enemy = []
        for slot in range(1, 8):
            e = bytearray(35)
            e[0:3] = bytes([foe_id if slot == caster else 30, 1, 88])
            e[18:30] = bytes([18, 19, 20, 21, agility, 23, 24, 5,
                             special, 2, mode if slot == caster else 0, 10])
            struct.pack_into('<h', e, 30, 200)
            e[34] = 1 if mask & (1 << (slot - 1)) else 0
            if slot > count:
                e = bytearray(35)
            u.mem_write(0x56f15 + 35 * slot, bytes(e))
            before_enemy.append(list(e))
        before_party = []
        for slot in range(1, 8):
            p = bytearray(55)
            if slot <= 6:
                if not (blank_mask & (1 << (slot - 1))) and (slot != 6 or named):
                    p[0:2] = b'\x01P'
                p[19:30] = bytes([7 if slot % 2 else 4, 20, 21, 22,
                                  23, 24, 25, 26, 27, 28, luck])
                struct.pack_into('<hhh', p, 31, 0, 0, HP[slot - 1])
                if dead_mask & (1 << (slot - 1)):
                    struct.pack_into('<h', p, 33, [-1, 1, 32767, -32768, 30000, 2][slot - 1])
                p[41:45] = bytes([slot, 255 if slot == 5 else 20, 1, 5])
            u.mem_write(0x564ff + 55 * slot, bytes(p))
            before_party.append(list(p))
        bounds, calls, events, stops = [], [], [], []
        def hook(vm, address, size, data):
            offset = address + header
            if offset == 225719:
                sp = vm.reg_read(UC_X86_REG_SP)
                bounds.append(struct.unpack('<H', vm.mem_read(0x60000 + sp + 4, 2))[0])
            if offset in [0x245d8, 0x246a3]:
                sp = vm.reg_read(UC_X86_REG_SP)
                second, first = struct.unpack('<HH', vm.mem_read(0x60000 + sp, 4))
                calls.append(['summon' if offset == 0x245d8 else 'mind', first & 255, second & 255])
                if offset == 0x245d8:
                    assert 1 <= (second & 255) <= len(database) // 29
            if offset == 0x246ad:
                for slot in range(1, 7):
                    ptr = 0x564ff + 55 * slot
                    vm.mem_write(ptr, condition(bytes(vm.mem_read(ptr, 55))))
                events.append(['condition', 0])
                vm.reg_write(UC_X86_REG_IP, 0x246b2 - header - 0x10000)
            if offset in UI_SKIPS:
                color = {0x245dd: 13, 0x246b2: 13, 0x24749: 13,
                         0x2479e: 7, 0x247c5: 7, 0x247f8: 4}[offset]
                target = struct.unpack('<h', vm.mem_read(0x53662, 2))[0]
                events.append([color, target])
                vm.reg_write(UC_X86_REG_IP, UI_SKIPS[offset] - header - 0x10000)
            if offset == 0x24857:
                stops.append(offset)
                vm.emu_stop()
        u.hook_add(UC_HOOK_CODE, hook)
        u.emu_start(0x24522 - header, 0x7ffff, count=20000)
        assert stops == [0x24857]
        return dict(count=count, caster=caster, mask=mask, mode=mode, named=named,
                    seed=seed, agility=agility, luck=luck, special=special,
                    foeId=foe_id, blankMask=blank_mask, deadMask=dead_mask, beforeEnemy=before_enemy,
                    beforeParty=before_party,
                    afterEnemy=[list(u.mem_read(0x56f15 + 35 * n, 35)) for n in range(1, 8)],
                    afterParty=[list(u.mem_read(0x564ff + 55 * n, 55)) for n in range(1, 8)],
                    afterCount=u.mem_read(0x56f37, 1)[0], bounds=bounds, calls=calls,
                    events=events, afterSeed=struct.unpack('<I', u.mem_read(0x5364c, 4))[0])
    cases = []
    for count in range(1, 8):
        for caster, mask, mode, named, seed in itertools.product(
                sorted({1, count}), range(1 << count), [0, 1, 2, 3, 255],
                [False, True], SEEDS):
            cases.append(run(count, caster, mask, mode, named, seed))
    for mode, seed in itertools.product(range(256), SEEDS):
        cases.append(run(3, 1, 2, mode, True, seed, special=0))
    for agility, luck, seed in itertools.product([0, 19, 39, 59, 60, 255], [0, 1, 19, 20, 255], SEEDS):
        cases.append(run(7, 1, 0, 3, False, seed, agility=agility, luck=luck))
    for blank, seed in itertools.product(range(64), SEEDS):
        cases.append(run(7, 1, 0, 3, True, seed, blank_mask=blank))
    for dead, seed in itertools.product(range(64), SEEDS):
        cases.append(run(7, 1, 0, 3, False, seed, dead_mask=dead))
    for mode, seed in itertools.product(range(256), SEEDS):
        cases.append(run(1, 1, 0, mode, True, seed, foe_id=1))
    # Every real template that can enter this source procedure: no invented
    # enemydata values. Also cover both ends of the defined summon index range.
    ids = {20, 21, 65}
    ids.update(index + 1 for index in range(len(database) // 29)
               if database[index * 29 + 27] > 0)
    for foe_id, count, seed in itertools.product(sorted(ids), range(1, 8), SEEDS):
        # E_number=20 and Random(4)=0 would index outside the original table.
        # Keep that unresolved behavior out of these native cases explicitly.
        if foe_id == 20:
            continue
        mode = database[(foe_id - 1) * 29 + 27]
        cases.append(run(count, 1, (1 << count) - 1, mode, True, seed,
                         foe_id=foe_id))
    return dict(scope=__doc__.strip(), exeSha256=hashlib.sha256(exe).hexdigest(),
                databaseSha256=hashlib.sha256(database).hexdigest(),
                fragments=[dict(name=n, start=a, end=z, sha256=hashlib.sha256(exe[a:z]).hexdigest())
                           for n, a, z in FRAGMENTS],
                bypassedUiSpans=UI_SKIPS, cases=cases)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--compact-existing', action='store_true',
                        help='Losslessly intern raw records in an existing generated fixture')
    args = parser.parse_args()
    if args.check:
        data = json.loads(OUT.read_text())
        exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
        assert data['exeSha256'] == hashlib.sha256(exe).hexdigest()
        assert [(f['name'], f['start'], f['end']) for f in data['fragments']] == FRAGMENTS
        database = (ROOT / 'repo_source/LORE_1993_runtime/FOEDATA.DAT').read_bytes()
        assert data['databaseSha256'] == hashlib.sha256(database).hexdigest()
        assert data['bypassedUiSpans'] == {str(k): v for k, v in UI_SKIPS.items()}
        for fragment in data['fragments']:
            assert fragment['sha256'] == hashlib.sha256(exe[fragment['start']:fragment['end']]).hexdigest()
    else:
        data = compact(json.loads(OUT.read_text()) if args.compact_existing else build())
        # One case per line keeps the large exhaustive evidence reviewable.
        rows = data.pop('cases')
        head = json.dumps(data, indent=2)[:-2]
        OUT.write_text(head + ',\n  "cases": [\n' + ',\n'.join(
            '    ' + json.dumps(row, separators=(',', ':')) for row in rows) + '\n  ]\n}\n')


if __name__ == '__main__':
    main()

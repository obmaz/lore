#!/usr/bin/env python3
"""Original BattleESP: real RNG, PlusExperience, join and numeric continuation.

Actual battle CS preserves original set-literal addresses. UI/string spans are
bypassed before pushes; Display_Condition numeric stores are separately replayed
through original ReturnCondition instructions. Effect-threshold input HP is set
at the observed native k, before any HP read; no expected effect is synthesized.
FOEDATA.DAT supplies the original recruitment templates. Glyphs/BGI are excluded.
"""
import argparse
from collections import defaultdict, Counter
import hashlib
import itertools
import json
import struct
from pathlib import Path
from export_dos_enemy_special_cast import compact
from audit_lorespec import decode
import re

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'test/fixtures/dos_battle_esp.json'
BASE = 0x207f0
SEEDS = [0, 1, 4, 5, 6, 0xdeadbeef, 0xffffffff]
FRAGMENTS = [('battle-esp', 0x221a1, 0x22a66),
             ('xp', 0x2080b, 0x20934), ('join', 0x2c4a4, 0x2c847),
             ('condition', 0x2ad98, 0x2ade7),
             ('sets-and-literals', 0x21e73, 0x221a1),
             ('random', 225719, 225865)]
# Each entry is before the first parameter push; no partial stack is discarded.
UI_SKIPS = {0x221cf: (0x22a64, [7]), 0x221f9: (0x22a64, [7]),
    0x22269: (0x22a64, [7]), 0x222a0: (0x22a64, [7]),
    0x222e6: (0x22a64, [7]), 0x2232d: (0x22a64, [7]),
    0x2233c: (0x22348, [11]), 0x2238b: (0x22a64, [7]),
    0x223e9: (0x224bf, [7]), 0x22435: (0x224bf, [7]),
    0x22476: (0x224bf, [7]), 0x225ec: (0x22628, [7, 7]),
    0x22610: (0x22628, [7, 7]), 0x2270b: (0x2272c, [7]),
    0x227dd: (0x22a5e, [10]), 0x22817: (0x22848, [7]),
    0x228b7: (0x228d8, [7]), 0x22995: (0x229b6, [7]),
    0x20875: (0x208bc, [14])}
MESSAGE_LINES = {0x223e9: [411], 0x22435: [413], 0x22476: [415],
                 0x225ec: [434, 435], 0x22610: [438, 439]}


def source_messages():
    raw = (ROOT / 'repo_source/LORE_1993_src/LOREBATT.PAS').read_bytes()
    lines = [decode(line) for line in raw.splitlines()]
    templates = {}
    pattern = re.compile(r"'((?:[^']|'')*)'|enemy\[battle\[person,3\]\]\.name|sexdata")
    for offset, numbers in MESSAGE_LINES.items():
        messages = []
        for number in numbers:
            statement = '\n'.join(lines[number - 1:number + 2]).split(');', 1)[0]
            expression = statement.split('Print(7,', 1)[1]
            pieces = []
            for token in pattern.finditer(expression):
                pieces.append(token[1].replace("''", "'") if token[1] is not None
                              else '{target}' if token[0].startswith('enemy') else '{sex}')
            messages.append(''.join(pieces))
        templates[str(offset)] = messages
    return dict(sourceSha256=hashlib.sha256(raw).hexdigest(), templates=templates)


def configurations():
    for level, count, status, hp_mode, seed in itertools.product(
            range(256), [1, 7], range(5), [-1, 0, 1], SEEDS):
        yield dict(level=level, count=count, status=status, hpMode=hp_mode, seed=seed)
    for cls, bits, action, esp in itertools.product(
            range(11), [0, 1, 2, 3, 128, 255], [0, 1, 2, 3, 4, 5, 255],
            [-32768, 0, 14, 15, 19, 20, 32767]):
        yield dict(cls=cls, bits=bits, action=action, esp=esp)
    for enemy_id, level, enemy_level, accuracy, seed in itertools.product(
            [0, 1, 6, 10, 20, 24, 27, 29, 33, 35, 40, 47, 53, 62, 255],
            [0, 1, 16, 17, 18, 255], [0, 1, 16, 17, 18, 255],
            [0, 59, 60, 255], SEEDS):
        yield dict(action=3, enemyId=enemy_id, level=level, enemyLevel=enemy_level,
                   accuracy=accuracy, seed=seed)
    for enemy_id, person, seed in itertools.product(range(256), [1, 6], SEEDS):
        yield dict(action=3, enemyId=enemy_id, person=person, level=255,
                   enemyLevel=17, accuracy=255, seed=seed)
    for level, resistance, accuracy, hp_mode, seed in itertools.product(
            [12, 14, 17, 18, 255], [0, 4, 5, 39, 40, 255],
            [0, 29, 30, 39, 40, 59, 60, 79, 80, 255], [-1, 0, 1], [*SEEDS, 135, 152]):
        yield dict(level=level, resistance=resistance, accuracy=accuracy,
                   endurance=resistance, agility=resistance, hpMode=hp_mode, seed=seed)
    for action, seed in itertools.product(range(256), SEEDS):
        yield dict(action=action, seed=seed, enemyId=1)
    for level, count, status, hp_mode, seed in itertools.product(
            range(1, 21), [1, 7], range(5), ['minimum', 'maximum', 'zero'], SEEDS):
        yield dict(level=level, count=count, status=status, hpMode=hp_mode, seed=seed)
    for level, pair, accuracy, resistance, seed in itertools.product(
            [18, 255], [(0, 0), (0, 1), (1, 0), (255, 255)],
            [0, 29, 30, 255], [0, 4, 5, 39, 255], [4, 152]):
        yield dict(level=level, enemyAccuracy=list(pair), accuracy=accuracy,
                   resistance=resistance, agility=resistance, seed=seed)


def build(smoke=False):
    from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_CODE
    from capstone import Cs, CS_ARCH_X86, CS_MODE_16
    from unicorn.x86_const import (UC_X86_REG_AX, UC_X86_REG_CS, UC_X86_REG_DS,
                                  UC_X86_REG_SS, UC_X86_REG_BP,
                                  UC_X86_REG_SP, UC_X86_REG_IP)
    exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    database = (ROOT / 'repo_source/LORE_1993_runtime/FOEDATA.DAT').read_bytes()
    header = struct.unpack_from('<H', exe, 8)[0] * 16
    condition_cache = {}
    conditionals = {i.address for i in Cs(CS_ARCH_X86, CS_MODE_16).disasm(
        exe[0x221b0:0x22a66], 0x221b0)
        if i.mnemonic.startswith('j') and i.mnemonic != 'jmp'}
    edges = defaultdict(Counter)

    def machine(cs):
        u = Uc(UC_ARCH_X86, UC_MODE_16)
        u.mem_map(0, 0x80000)
        u.mem_write(0, exe[header:])
        for reg, value in [(UC_X86_REG_CS, cs), (UC_X86_REG_DS, 0x5000),
                           (UC_X86_REG_SS, 0x6000), (UC_X86_REG_BP, 0x8000),
                           (UC_X86_REG_SP, 0x7e00)]:
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

    def run(config):
        row = dict(count=7, person=1, cls=3, bits=0, action=5, esp=40,
                   level=20, accuracy=255, enemyId=40, enemyLevel=20,
                   resistance=0, endurance=20, agility=20, status=0,
                   hpMode=None, seed=4, enemyAccuracy=[23, 24])
        row.update(config)
        u = machine((BASE - header) // 16)
        u.mem_write(0x566b8, database)
        u.mem_write(0x5364c, struct.pack('<I', row['seed']))
        u.mem_write(0x53d9e, struct.pack('<h', row['person']))
        u.mem_write(0x56f37, bytes([row['count']]))
        u.mem_write(0x564f8, bytes([row['bits']]))
        # Original battle[person, 2/3] are bytes, three bytes per row.
        u.mem_write(0x564b6 + 3 * row['person'],
                    bytes([row['action'], row['count']]))
        before_enemy = []
        for slot in range(1, 8):
            e = bytearray(35)
            e[:3] = bytes([row['enemyId'], 1, 88])
            e[18:30] = bytes([18, 19, row['endurance'], row['resistance'],
                row['agility'], *row['enemyAccuracy'], 5, 0, 0, 0, row['enemyLevel']])
            struct.pack_into('<h', e, 30, [-32768, -1, 0, 1, 9, 10, 32767][slot - 1])
            e[33] = int(row['status'] in [2, 4] or row['status'] == 1 and slot % 2 == 0)
            e[34] = int(row['status'] in [3, 4] or row['status'] == 2 and slot % 2 == 0)
            u.mem_write(0x56f15 + 35 * slot, bytes(e))
            before_enemy.append(list(e))
        before_party = []
        for slot in range(1, 8):
            p = bytearray(55)
            if slot <= 6:
                p[:2] = b'\x01P'
                p[19:30] = bytes([row['cls'] if slot == row['person'] else 8,
                    20, 21, 22, 23, 24, 25, 26, 27, row['accuracy'], 10])
                struct.pack_into('<hhh', p, 35, 100, 50,
                                 row['esp'] if slot == row['person'] else 50)
                p[41:45] = bytes([10, 20, row['level'] if slot == row['person'] else 10, 5])
                struct.pack_into('<i', p, 45,
                                 [2147483600, -2147483648, 0, 1, -1, 1000][slot - 1])
            u.mem_write(0x564ff + 55 * slot, bytes(p))
            before_party.append(list(p))
        bounds, colors, calls, stops, k_values = [], [], [], [], []
        message_kinds = []
        pending_branch = []
        def jump(vm, offset):
            # All bypassed spans belong to the battle unit.
            vm.reg_write(UC_X86_REG_IP, offset - BASE)
        def hook(vm, address, size, data):
            offset = address + header
            if pending_branch:
                edges[hex(pending_branch.pop())][hex(offset)] += 1
            if offset in conditionals:
                pending_branch.append(offset)
            if offset == 225719:
                sp = vm.reg_read(UC_X86_REG_SP)
                bounds.append(struct.unpack('<H', vm.mem_read(0x60000 + sp + 4, 2))[0])
            if offset == 0x223c9:
                k = struct.unpack('<h', vm.mem_read(0x53662, 2))[0]
                k_values.append(k)
                if row['hpMode'] is not None:
                    cost = k * 10 if k <= 6 else k * 5 if k <= 10 else 10
                    for slot in range(1, 8):
                        value = ({'minimum': -32768, 'maximum': 32767, 'zero': 0}[row['hpMode']]
                                 if isinstance(row['hpMode'], str) else cost + row['hpMode'])
                        e = bytearray(before_enemy[slot - 1])
                        struct.pack_into('<h', e, 30, value)
                        before_enemy[slot - 1] = list(e)
                        vm.mem_write(0x56f15 + 35 * slot, bytes(e))
            if offset in [0x2080b, 0x22351]:
                sp = vm.reg_read(UC_X86_REG_SP)
                params = bytes(vm.mem_read(0x60000 + sp + (4 if offset == 0x2080b else 0), 4))
                second, first = struct.unpack('<HH', params)
                calls.append(['xp' if offset == 0x2080b else 'join', first & 255, second & 255])
            if offset == 0x22377:
                for slot in range(1, 7):
                    ptr = 0x564ff + 55 * slot
                    vm.mem_write(ptr, condition(bytes(vm.mem_read(ptr, 55))))
                colors.append('condition')
                jump(vm, 0x2237c)
            if offset in UI_SKIPS:
                destination, emitted = UI_SKIPS[offset]
                colors.extend(emitted)
                if offset in MESSAGE_LINES:
                    message_kinds.append(offset)
                jump(vm, destination)
            if offset == 0x22a5e:
                jump(vm, 0x22a64)
            if offset == 0x22a64:
                stops.append(offset)
                vm.emu_stop()
        u.hook_add(UC_HOOK_CODE, hook)
        u.emu_start(0x221b0 - header, 0x7ffff, count=100000)
        assert stops == [0x22a64], row
        row.update(beforeEnemy=before_enemy, beforeParty=before_party,
            afterEnemy=[list(u.mem_read(0x56f15 + 35 * n, 35)) for n in range(1, 8)],
            afterParty=[list(u.mem_read(0x564ff + 55 * n, 55)) for n in range(1, 8)],
            bounds=bounds, colors=colors, calls=calls, k=k_values,
            messageKinds=message_kinds,
            sexData=decode(bytes(u.mem_read(0x53675, u.mem_read(0x53674, 1)[0]))) if k_values else '',
            afterSeed=struct.unpack('<I', u.mem_read(0x5364c, 4))[0])
        return row
    configs = configurations() if not smoke else [
        {}, dict(cls=1), dict(action=1), dict(action=3, enemyId=62, level=255),
        dict(action=3, enemyId=62, level=255, person=6),
        *[dict(level=n, seed=s) for n, s in itertools.product(range(1, 22), SEEDS)],
    ]
    rows = [run(config) for config in configs]
    return dict(scope=__doc__.strip(), exeSha256=hashlib.sha256(exe).hexdigest(),
                databaseSha256=hashlib.sha256(database).hexdigest(),
                fragments=[dict(name=n, start=a, end=z, sha256=hashlib.sha256(exe[a:z]).hexdigest())
                           for n, a, z in FRAGMENTS],
                bypassedUiSpans=UI_SKIPS, sourceMessages=source_messages(),
                conditionalEdges=dict(edges), cases=rows)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--smoke', action='store_true')
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if args.check:
        data = json.loads(OUT.read_text())
        exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
        database = (ROOT / 'repo_source/LORE_1993_runtime/FOEDATA.DAT').read_bytes()
        assert data['exeSha256'] == hashlib.sha256(exe).hexdigest()
        assert data['databaseSha256'] == hashlib.sha256(database).hexdigest()
        assert data['scope'] == __doc__.strip()
        assert data['bypassedUiSpans'] == {
            str(k): [v[0], v[1]] for k, v in UI_SKIPS.items()}
        assert data['sourceMessages'] == source_messages()
        assert [(f['name'], f['start'], f['end']) for f in data['fragments']] == FRAGMENTS
        for fragment in data['fragments']:
            assert fragment['sha256'] == hashlib.sha256(exe[fragment['start']:fragment['end']]).hexdigest()
    else:
        data = compact(build(smoke=args.smoke))
        if args.smoke:
            print(json.dumps({'cases': len(data['cases']), 'k': sorted({
                k for row in data['cases'] for k in row['k']})}))
            return
        rows = data.pop('cases')
        head = json.dumps(data, indent=2)[:-2]
        OUT.write_text(head + ',\n  "cases": [\n' + ',\n'.join(
            '    ' + json.dumps(row, separators=(',', ':')) for row in rows) + '\n  ]\n}\n')


if __name__ == '__main__':
    main()

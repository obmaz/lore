#!/usr/bin/env python3
"""Execute original CastSpecial stores, short-circuit RNG and native text branches.

Only Print/string construction and stack-check prologue are bypassed; text is
decoded from the original EXE literals, not generated from Dart rules.
"""
import argparse
from collections import Counter, defaultdict
import hashlib
import itertools
import json
import struct
from pathlib import Path
from audit_lorespec import decode
from export_dos_enemy_special_cast import compact

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'test/fixtures/dos_cast_special.json'
BASE = 0x207f0
START, END = 0x21887, 0x21e71
SEEDS = [0, 1, 4, 5, 6, 135, 152, 0xdeadbeef, 0xffffffff]
# (next instruction, colour, CS literal offset, prepend enemy name)
UI = {
    0x21890: (END, 7, 0xe3d, False),
    0x218dd: (END, 7, 0xe5a, False),
    0x21917: (END, 7, 0xe6f, False),
    0x2193e: (END, 7, 0xe88, False),
    0x2194d: (0x21972, 4, 0xe9b, True),
    0x219ad: (END, 7, 0xe5a, False),
    0x219e7: (END, 7, 0xeaa, False),
    0x21a0e: (END, 7, 0xec9, False),
    0x21a1d: (0x21a42, 4, 0xee5, True),
    0x21a7d: (END, 7, 0xe5a, False),
    0x21ab7: (END, 7, 0xf04, False),
    0x21af8: (END, 7, 0xf23, False),
    0x21b07: (0x21b2c, 4, 0xf3f, True),
    0x21b90: (END, 7, 0xe5a, False),
    0x21bcb: (END, 7, 0xf59, False),
    0x21bf2: (END, 7, 0xf76, False),
    0x21c01: (0x21c26, 4, 0xf90, True),
    0x21c91: (END, 7, 0xe5a, False),
    0x21ccb: (END, 7, 0xfae, False),
    0x21cf2: (END, 7, 0xfcb, False),
    0x21d0b: (0x21d57, 4, 0xfe5, True),
    0x21d32: (0x21d57, 4, 0xfff, True),
    0x21d9b: (END, 7, 0xe5a, False),
    0x21dd5: (END, 7, 0x1017, False),
    0x21dfc: (END, 7, 0x1034, False),
    0x21e14: (0x21e60, 4, 0x104e, True),
    0x21e3b: (0x21e60, 4, 0x106c, True),
}


def configurations():
    for action, bits, sp in itertools.product(range(256), [0, 1, 2, 255],
            [-32768, -1, 0, 9, 10, 14, 15, 19, 20, 29, 30, 32767]):
        yield dict(action=action, bits=bits, sp=sp)
    for action, resistance, accuracy, seed in itertools.product(
            range(1, 7), range(256), [0, 255], SEEDS):
        yield dict(action=action, resistance=resistance, accuracy=accuracy, seed=seed)
    for action, accuracy, seed in itertools.product(range(1, 7), range(256), SEEDS):
        yield dict(action=action, accuracy=accuracy, seed=seed)
    for action, value, seed in itertools.product(range(1, 7), range(256), SEEDS):
        yield dict(action=action, ac=value, level=value, cast=value, specialCast=value,
                   special=value, seed=seed)
    for ac, resistance, seed in itertools.product([0, 4, 5, 255], [0, 30, 31, 40, 99], range(256)):
        yield dict(action=3, ac=ac, resistance=resistance, seed=seed)
    for person, target, action, seed in itertools.product([1, 6], range(1, 8), range(1, 7), SEEDS):
        yield dict(person=person, target=target, action=action, seed=seed)


def build(smoke=False):
    from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_CODE
    from unicorn.x86_const import (UC_X86_REG_CS, UC_X86_REG_DS, UC_X86_REG_SS,
                                  UC_X86_REG_BP, UC_X86_REG_SP, UC_X86_REG_IP)
    from capstone import Cs, CS_ARCH_X86, CS_MODE_16
    exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    header = struct.unpack_from('<H', exe, 8)[0] * 16
    branches = {i.address for i in Cs(CS_ARCH_X86, CS_MODE_16).disasm(exe[START:END], START)
                if i.mnemonic.startswith('j') and i.mnemonic != 'jmp'}
    edges = defaultdict(Counter)
    literal = lambda n: decode(exe[BASE+n+1:BASE+n+1+exe[BASE+n]])

    def run(config):
        row = dict(action=1, bits=1, sp=100, resistance=0, accuracy=255,
                   ac=5, level=2, cast=2, specialCast=2, special=40,
                   person=1, target=7, seed=4)
        row.update(config)
        vm = Uc(UC_ARCH_X86, UC_MODE_16)
        vm.mem_map(0, 0x80000)
        vm.mem_write(0, exe[header:])
        for r, v in [(UC_X86_REG_CS, (BASE-header)//16), (UC_X86_REG_DS, 0x5000),
                     (UC_X86_REG_SS, 0x6000), (UC_X86_REG_BP, 0x8000), (UC_X86_REG_SP, 0x7e00)]:
            vm.reg_write(r, v)
        vm.mem_write(0x5364c, struct.pack('<I', row['seed']))
        vm.mem_write(0x53d9e, struct.pack('<h', row['person']))
        vm.mem_write(0x564f7, bytes([row['bits']]))
        vm.mem_write(0x564b6+3*row['person'], bytes([row['action'], row['target']]))
        party, enemy = [], []
        for slot in range(1, 8):
            p = bytearray(55)
            p[:2] = b'\x01P'
            p[19:30] = bytes([3, 20, 21, 22, 23, 24, 25, 26,
                            row['accuracy'] if slot == row['person'] else 27, 28, 29])
            struct.pack_into('<hhh', p, 35, 100, row['sp'] if slot == row['person'] else 50, 40)
            p[41:45] = bytes([10, 20, 30, 5])
            vm.mem_write(0x564ff+55*slot, bytes(p)); party.append(list(p))
            e = bytearray(35);e[:3] = b'\x28\x01X'
            e[18:30] = bytes([18, 19, 20, row['resistance'], 22, 23, 24,
                             row['ac'], row['special'], row['cast'], row['specialCast'], row['level']])
            struct.pack_into('<h', e, 30, [-32768, -1, 0, 1, 9, 10, 32767][slot-1])
            e[32:35] = bytes([slot%2, (slot//2)%2, (slot//3)%2])
            vm.mem_write(0x56f15+35*slot, bytes(e));enemy.append(list(e))
        bounds, messages, stops, pending = [], [], [], []
        def hook(u, address, size, data):
            offset = address + header
            if pending: edges[hex(pending.pop())][hex(offset)] += 1
            if offset in branches: pending.append(offset)
            if offset == 225719:
                sp = u.reg_read(UC_X86_REG_SP)
                bounds.append(struct.unpack('<H', u.mem_read(0x60000+sp+4, 2))[0])
            if offset in UI:
                dest, color, text, name = UI[offset]
                messages.append([color, ('X' if name else '')+literal(text)])
                u.reg_write(UC_X86_REG_IP, dest-BASE)
            if offset == END:
                stops.append(offset);u.emu_stop()
        vm.hook_add(UC_HOOK_CODE, hook)
        vm.emu_start(START-header, 0x7ffff, count=10000)
        assert stops == [END], row
        row.update(beforeParty=party, beforeEnemy=enemy,
                   afterParty=[list(vm.mem_read(0x564ff+55*n, 55)) for n in range(1, 8)],
                   afterEnemy=[list(vm.mem_read(0x56f15+35*n, 35)) for n in range(1, 8)],
                   bounds=bounds, messages=messages,
                   afterSeed=struct.unpack('<I', vm.mem_read(0x5364c, 4))[0])
        return row
    configs = configurations() if not smoke else [dict(action=n, seed=s) for n,s in itertools.product(range(7), SEEDS)]
    rows = [run(c) for c in configs]
    return dict(scope=__doc__, exeSha256=hashlib.sha256(exe).hexdigest(),
                fragmentSha256=hashlib.sha256(exe[BASE+0xe3d:END+2]).hexdigest(),
                ui=UI, conditionalEdges=dict(edges), cases=rows)


def main():
    parser = argparse.ArgumentParser();parser.add_argument('--smoke', action='store_true');parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if args.check:
        data=json.loads(OUT.read_text());exe=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
        assert data['exeSha256']==hashlib.sha256(exe).hexdigest()
        assert data['fragmentSha256']==hashlib.sha256(exe[BASE+0xe3d:END+2]).hexdigest()
        assert data['scope']==__doc__
        assert data['ui']=={str(k):list(v) for k,v in UI.items()}
    else:
        data=compact(build(args.smoke))
        if args.smoke: print(json.dumps({'cases':len(data['cases'])}));return
        rows=data.pop('cases');head=json.dumps(data,indent=2)[:-2]
        OUT.write_text(head+',\n  "cases": [\n'+',\n'.join('    '+json.dumps(r,separators=(',',':')) for r in rows)+'\n  ]\n}\n')


if __name__ == '__main__': main()

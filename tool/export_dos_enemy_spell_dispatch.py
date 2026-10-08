#!/usr/bin/env python3
"""Execute original single/all enemy spell selectors, powers and slot iteration.
All mentality bytes; representative level boundaries. String/Print spans skipped.
CastAttackSub calls captured and returned without effects; not full spell/UI replay.
"""
import argparse
import hashlib
import itertools
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'test/fixtures/dos_enemy_spell_dispatch.json'
FRAGMENTS = [('single', 0x2317b, 0x232db), ('all', 0x23322, 0x23455)]
LEVELS = [0, 1, 128, 255]
COPIES = {0x231a8: (0x231ba, 1), 0x231cb: (0x231dd, 2),
          0x231ed: (0x231ff, 3), 0x2320f: (0x23221, 4),
          0x23231: (0x23243, 5), 0x2324b: (0x2325d, 6),
          0x23342: (0x23355, 1), 0x23366: (0x23379, 2),
          0x23389: (0x2339c, 3), 0x233ac: (0x233bf, 4),
          0x233c7: (0x233da, 5)}
PRINTS = {0x23273: 0x232c7, 0x233f2: 0x2342e}


def build():
    from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_CODE
    from unicorn.x86_const import (UC_X86_REG_CS, UC_X86_REG_DS, UC_X86_REG_SS,
        UC_X86_REG_SP, UC_X86_REG_BP, UC_X86_REG_IP)
    exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    header = struct.unpack_from('<H', exe, 8)[0] * 16
    cases = []
    for all_slots, mentality, level in itertools.product([False, True], range(256), LEVELS):
        u = Uc(UC_ARCH_X86, UC_MODE_16)
        u.mem_map(0, 0x80000)
        u.mem_write(0, exe[header:])
        for reg, value in [(UC_X86_REG_CS, 0x1000), (UC_X86_REG_DS, 0x5000),
                           (UC_X86_REG_SS, 0x6000), (UC_X86_REG_SP, 0x7e00),
                           (UC_X86_REG_BP, 0x8000)]:
            u.reg_write(reg, value)
        u.mem_write(0x5364c, struct.pack('<I', 0xdeadbeef))
        u.mem_write(0x53d9e, struct.pack('<h', 1))
        target = mentality % 6 + 1
        u.mem_write(0x68006, struct.pack('<h', target))
        e = bytearray(35); e[19], e[29] = mentality, level
        u.mem_write(0x56f38, bytes(e))
        calls, methods, stops = [], [], []
        def hook(vm, address, size, data):
            offset = address + header
            if offset in COPIES:
                destination, method = COPIES[offset]
                methods.append(method)
                vm.reg_write(UC_X86_REG_IP, destination - header - 0x10000)
            if offset in PRINTS:
                vm.reg_write(UC_X86_REG_IP, PRINTS[offset] - header - 0x10000)
            if offset == 0x22f27:
                sp = vm.reg_read(UC_X86_REG_SP)
                ret_ip, ret_cs, num, power = struct.unpack('<HHhh', vm.mem_read(0x60000 + sp, 8))
                calls.append([power, num])
                vm.reg_write(UC_X86_REG_SP, sp + 12)
                vm.reg_write(UC_X86_REG_CS, ret_cs)
                vm.reg_write(UC_X86_REG_IP, ret_ip)
            if offset == (0x23453 if all_slots else 0x232d7):
                stops.append(offset)
                vm.emu_stop()
        u.hook_add(UC_HOOK_CODE, hook)
        start = 0x23331 if all_slots else 0x2318a
        u.emu_start(start - header, 0x7ffff, count=10000)
        assert len(stops) == 1 and len(methods) == 1
        assert struct.unpack('<I', u.mem_read(0x5364c, 4))[0] == 0xdeadbeef
        cases.append(dict(all=all_slots, mentality=mentality, level=level,
                          target=target, method=methods[0], calls=calls,
                          factor=struct.unpack('<h', u.mem_read(0x53662, 2))[0]))
    return dict(scope=__doc__.strip(), exeSha256=hashlib.sha256(exe).hexdigest(),
                fragments=[dict(name=n, start=a, end=z, sha256=hashlib.sha256(exe[a:z]).hexdigest())
                           for n, a, z in FRAGMENTS],
                bypassedCopySpans=[dict(start=a, end=b, method=m) for a, (b, m) in COPIES.items()],
                bypassedPrintSpans=[dict(start=a, end=b) for a, b in PRINTS.items()], cases=cases)


def check():
    data = json.loads(OUT.read_text())
    exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    assert data['scope'] == __doc__.strip() and len(data['cases']) == 2048
    assert data['exeSha256'] == hashlib.sha256(exe).hexdigest()
    for row, (n, a, z) in zip(data['fragments'], FRAGMENTS, strict=True):
        assert row == dict(name=n, start=a, end=z, sha256=hashlib.sha256(exe[a:z]).hexdigest())
    assert data['bypassedCopySpans'] == [dict(start=a, end=b, method=m) for a, (b, m) in COPIES.items()]
    assert data['bypassedPrintSpans'] == [dict(start=a, end=b) for a, b in PRINTS.items()]
    print('Original enemy spell selection/power/slot evidence checked')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    if parser.parse_args().check: check()
    else:
        data = build(); cases = data.pop('cases')
        prefix = json.dumps(data, indent=2)[:-2]
        records = ',\n'.join('    ' + json.dumps(r, separators=(',', ':')) for r in cases)
        OUT.write_text(prefix + ',\n  "cases": [\n' + records + '\n  ]\n}\n')
        check()

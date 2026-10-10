#!/usr/bin/env python3
"""Original BattleMode k=8 class/level/target dispatch, synthetic records.
Runs unmodified instructions including the shipped real /2 and Round helpers.
This is not a whole battle, UI, startup-memory or campaign replay.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'test/fixtures/dos_auto_select.json'
START, END = 0x24cf1, 0x24e83


def build():
    from unicorn import Uc, UC_ARCH_X86, UC_MODE_16
    from unicorn.x86_const import (UC_X86_REG_CS, UC_X86_REG_DS,
        UC_X86_REG_SS, UC_X86_REG_SP, UC_X86_REG_BP, UC_X86_REG_IP)
    exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    header = struct.unpack_from('<H', exe, 8)[0] * 16
    vm = Uc(UC_ARCH_X86, UC_MODE_16)
    vm.mem_map(0, 0x80000)
    vm.mem_write(0, exe[header:])

    def run(cls, level, person, weapon, states):
        for reg, value in [(UC_X86_REG_CS, 0x1000), (UC_X86_REG_DS, 0x5000),
                          (UC_X86_REG_SS, 0x6000), (UC_X86_REG_SP, 0xff00),
                          (UC_X86_REG_BP, 0x8000)]:
            vm.reg_write(reg, value)
        vm.mem_write(0x5364c, struct.pack('<I', 0xdeadbeef))
        vm.mem_write(0x53d9e, struct.pack('<h', person))
        record = bytearray(55)
        record[19], record[42], record[49] = cls, level, weapon
        vm.mem_write(0x564ff + person * 55, bytes(record))
        vm.mem_write(0x56f37, bytes([len(states)]))
        for i, state in enumerate(states, 1):
            enemy = bytearray(35)
            enemy[33] = int(state == 'unconscious')
            enemy[34] = int(state == 'dead')
            vm.mem_write(0x56f15 + i * 35, bytes(enemy))
        address = 0x564b5 + 3 * person
        vm.mem_write(address, bytes([8, 99, 99]))
        vm.emu_start(START - header, END - header, count=10000)
        assert vm.reg_read(UC_X86_REG_CS) == 0x1000
        assert 0x10000 + vm.reg_read(UC_X86_REG_IP) == END - header
        assert struct.unpack('<I', vm.mem_read(0x5364c, 4))[0] == 0xdeadbeef
        return list(vm.mem_read(address, 3))

    classes = []
    for cls in range(11):
        for level in range(256):
            person = level % 6 + 1
            weapon = level % 13
            states = ['alive', 'dead', 'unconscious', 'alive']
            classes.append(dict(classId=cls, level=level, person=person,
                weapon=weapon, command=run(cls, level, person, weapon, states)))
    targets = []
    for count in range(1, 8):
        for mask in range(1 << count):
            states = [('dead' if i % 2 else 'unconscious') if mask & (1 << i)
                      else 'alive' for i in range(count)]
            targets.append(dict(states=states,
                command=run(3, 1, 6, 0, states)))
    return dict(scope=__doc__.strip(), exeSha256=hashlib.sha256(exe).hexdigest(),
        fragment=dict(start=START, end=END,
                      sha256=hashlib.sha256(exe[START:END]).hexdigest()),
        classes=classes, targets=targets)


def check():
    data = json.loads(OUT.read_text())
    exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    assert data['exeSha256'] == hashlib.sha256(exe).hexdigest()
    assert data['fragment'] == dict(start=START, end=END,
        sha256=hashlib.sha256(exe[START:END]).hexdigest())
    assert len(data['classes']) == 11 * 256
    assert {(r['classId'], r['level']) for r in data['classes']} == {
        (cls, level) for cls in range(11) for level in range(256)}
    assert len(data['targets']) == sum(1 << n for n in range(1, 8))
    print('Original automatic command selection evidence checked')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    if parser.parse_args().check:
        check()
    else:
        OUT.write_text(json.dumps(build(), indent=2) + '\n')
        check()

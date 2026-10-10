"""Original Train_Center level selector over every signed-word CASE operand.

Negative XP covers all low words in the first CASE; large positive XP covers
all quotient words in the second CASE. A supplied -32768 local marks the first
CASE's unassigned result, without assuming actual uninitialized stack contents.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path
from export_dos_training_dispatch import FRAGMENTS

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'test/fixtures/dos_training_words.json'
START, END = FRAGMENTS[0][1:]
UNASSIGNED = -32768


def build():
    from unicorn import Uc, UC_ARCH_X86, UC_MODE_16
    from unicorn.x86_const import (UC_X86_REG_CS, UC_X86_REG_DS,
        UC_X86_REG_SS, UC_X86_REG_BP, UC_X86_REG_SP, UC_X86_REG_IP)
    exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    header = struct.unpack_from('<H', exe, 8)[0] * 16
    vm = Uc(UC_ARCH_X86, UC_MODE_16)
    vm.mem_map(0, 0x80000)
    vm.mem_write(0, exe[header:])

    def run(xp, previous=UNASSIGNED):
        for reg, value in [(UC_X86_REG_CS, 0x2466), (UC_X86_REG_DS, 0x5000),
                           (UC_X86_REG_SS, 0x6000), (UC_X86_REG_BP, 0x8000),
                           (UC_X86_REG_SP, 0x7d00)]:
            vm.reg_write(reg, value)
        vm.mem_write(0x53666, struct.pack('<i', xp))
        vm.mem_write(0x67ffc, struct.pack('<h', previous))
        vm.emu_start(START - header, END - header, count=1000)
        assert vm.reg_read(UC_X86_REG_CS) == 0x2466
        assert 0x24660 + vm.reg_read(UC_X86_REG_IP) == END - header
        assert vm.reg_read(UC_X86_REG_SP) == 0x7d00
        return struct.unpack('<h', vm.mem_read(0x67ffc, 2))[0]

    negative = [run(-65536 + word) for word in range(65536)]
    positive = [run((65536 + word) * 10000) for word in range(65536)]
    small = [run(xp) for xp in range(20000)]
    retention = [dict(xp=xp, previous=previous, result=run(xp, previous))
        for xp in [-2147483648, -65536, -64036, -59536, -32768, -1]
        for previous in [-32768, -1, 0, 1, 3, 15, 20, 32767]]
    assert set(negative) == {1, 2, 3, UNASSIGNED}
    assert set(positive) == set(range(4, 21))
    assert set(small) == {1, 2, 3}
    return dict(scope=__doc__, exeSha256=hashlib.sha256(exe).hexdigest(),
        fragment=dict(start=START, end=END, sha256=hashlib.sha256(exe[START:END]).hexdigest()),
        unassigned=UNASSIGNED, negativeWords=negative, quotientWords=positive,
        smallXp=small, retention=retention)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if args.check:
        data = json.loads(OUT.read_text())
        exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
        assert data['scope'] == __doc__ and data['exeSha256'] == hashlib.sha256(exe).hexdigest()
        assert data['fragment'] == dict(start=START, end=END,
            sha256=hashlib.sha256(exe[START:END]).hexdigest())
        assert len(data['negativeWords']) == len(data['quotientWords']) == 65536
        assert len(data['smallXp']) == 20000 and len(data['retention']) == 48
    else:
        OUT.write_text(json.dumps(build(), separators=(',', ':')) + '\n')


if __name__ == '__main__':
    main()

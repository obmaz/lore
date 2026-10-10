"""Original BattleMode poison/status/iteration instructions; attacks stubbed.
Actual EnemyAttack side effects and UI are separate evidence, not this fixture.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'test/fixtures/dos_enemy_phase.json'
START, END = 0x253f6, 0x25475


def build():
    from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_CODE
    from unicorn.x86_const import UC_X86_REG_CS, UC_X86_REG_DS, UC_X86_REG_SS, UC_X86_REG_SP, UC_X86_REG_BP, UC_X86_REG_IP
    exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    header = struct.unpack_from('<H', exe, 8)[0] * 16
    vm = Uc(UC_ARCH_X86, UC_MODE_16)
    vm.mem_map(0, 0x80000)
    vm.mem_write(0, exe[header:])
    attacks = []
    def hook(u, address, size, _):
        if address == 0x25469 - header:
            attacks.append(struct.unpack('<h', u.mem_read(0x53d9e, 2))[0])
            u.reg_write(UC_X86_REG_IP, 0x2546d - header - 0x20000)
    vm.hook_add(UC_HOOK_CODE, hook)
    def run(hp, flags, count):
        attacks.clear()
        for r, v in [(UC_X86_REG_CS, 0x2000), (UC_X86_REG_DS, 0x5000), (UC_X86_REG_SS, 0x6000), (UC_X86_REG_SP, 0x7f00), (UC_X86_REG_BP, 0x8000)]: vm.reg_write(r, v)
        vm.mem_write(0x56f37, bytes([count]))
        record = bytearray(35)
        struct.pack_into('<h', record, 30, hp)
        record[32:35] = bytes([(flags >> i) & 1 for i in range(3)])
        for i in range(1, 8): vm.mem_write(0x56f15 + 35 * i, bytes(record))
        vm.emu_start(START - header, END - header, count=1000)
        assert 0x20000 + vm.reg_read(UC_X86_REG_IP) == END - header, (hp, flags, count, hex(vm.reg_read(UC_X86_REG_IP)), hex(END-header), attacks)
        result = []
        for i in range(1, count + 1):
            b = vm.mem_read(0x56f15 + 35 * i, 35)
            result.append([struct.unpack_from('<h', b, 30)[0], *b[32:35]])
        return dict(hp=hp, flags=flags, count=count, records=result, attacks=list(attacks))
    rows = [run(hp, 1, 1) for hp in range(-32768, 32768)]
    for hp in [-32768, -32767, -1, 0, 1, 2, 32766, 32767]:
        for flags in range(8):
            for count in range(8): rows.append(run(hp, flags, count))
    return dict(scope=__doc__, exeSha256=hashlib.sha256(exe).hexdigest(), fragment=dict(start=START, end=END, sha256=hashlib.sha256(exe[START:END]).hexdigest()), cases=rows)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if args.check:
        data = json.loads(OUT.read_text())
        exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
        assert data['exeSha256'] == hashlib.sha256(exe).hexdigest()
        assert data['fragment'] == dict(start=START, end=END, sha256=hashlib.sha256(exe[START:END]).hexdigest())
        assert len(data['cases']) == 66048
    else: OUT.write_text(json.dumps(build(), separators=(',', ':')) + '\n')


if __name__ == '__main__': main()

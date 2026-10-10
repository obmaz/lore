"""Original ReturnMessage and its original string/label helpers.

Only prologue stack-space checks are bypassed. Defined branch strings execute
through original integer parameters, short-string copies and concatenations.
Synthetic out-of-array names demonstrate why those reads are explicit port faults.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path
from audit_lorespec import decode

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'test/fixtures/dos_return_message.json'
START, END = 0x2b5ea, 0x2b91f
SPANS = [('ReturnMessage', START, END), ('ReturnMagic', 0x2b07a, 0x2b55f),
         ('stringHelpers', 0x36b02, 0x36b40)]
PROFILES = [
    dict(players=[dict(name=f'Player{i}', weapon=i) for i in range(1, 8)],
         enemies=[f'Enemy{i}' for i in range(1, 8)]),
    dict(players=[dict(name=n, weapon=w) for n, w in zip(
        ['', '영웅', 'ABCDEFGHIJKLMNOPQ', '마법사', '여섯째전사', 'Reserved', 'Scratch7'],
        [0, 1, 2, 9, 10, 255, 7])],
         enemies=['', '적', 'ABCDEFGHIJKLMNOPQ', '괴물', '검은기사', 'Enemy6', '일곱째'])]


def build():
    from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_CODE
    from unicorn.x86_const import (UC_X86_REG_CS, UC_X86_REG_DS,
        UC_X86_REG_SS, UC_X86_REG_BP, UC_X86_REG_SP, UC_X86_REG_IP)
    exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    header = struct.unpack_from('<H', exe, 8)[0] * 16
    vm = Uc(UC_ARCH_X86, UC_MODE_16)
    vm.mem_map(0, 0x80000)
    vm.mem_write(0, exe[header:])

    def hook(u, address, size, _):
        if address == 0x30cd0 + 0x4df:
            sp = u.reg_read(UC_X86_REG_SP)
            ip, cs = struct.unpack('<HH', u.mem_read(0x60000 + sp, 4))
            u.reg_write(UC_X86_REG_SP, sp + 4)
            u.reg_write(UC_X86_REG_CS, cs)
            u.reg_write(UC_X86_REG_IP, ip)
    vm.hook_add(UC_HOOK_CODE, hook)

    def short(name):
        raw = name.encode('johab')
        assert len(raw) <= 17
        return bytes([len(raw)]) + raw

    def run(profile, who, how, what, whom, weapon=None):
        if weapon is not None:
            vm.mem_write(0x56536 + (who - 1) * 55 + 49, bytes([weapon]))
        before_players = bytes(vm.mem_read(0x56536, 7 * 55))
        before_enemies = bytes(vm.mem_read(0x56f39, 7 * 35))
        for reg, value in [(UC_X86_REG_CS, 0x2466), (UC_X86_REG_DS, 0x5000),
                           (UC_X86_REG_SS, 0x6000), (UC_X86_REG_BP, 0x8000),
                           (UC_X86_REG_SP, 0x7d00)]:
            vm.reg_write(reg, value)
        vm.mem_write(0x68006, struct.pack('<hhhhHH', whom, what, how, who, 0, 0x7000))
        vm.emu_start(START - header, END - header, count=100000)
        assert vm.reg_read(UC_X86_REG_CS) == 0x2466
        assert 0x24660 + vm.reg_read(UC_X86_REG_IP) == END - header
        assert vm.reg_read(UC_X86_REG_SP) == 0x7d00
        assert bytes(vm.mem_read(0x56536, 7 * 55)) == before_players
        assert bytes(vm.mem_read(0x56f39, 7 * 35)) == before_enemies
        raw = bytes(vm.mem_read(0x70000, 256))
        return dict(profile=profile, who=who, how=how, what=what, whom=whom,
                    weapon=weapon, text=decode(raw[1:raw[0]+1]))

    cases = []
    for profile, data in enumerate(PROFILES):
        for i, row in enumerate(data['players']):
            record = bytearray(55)
            name = short(row['name'])
            record[:len(name)] = name
            record[49] = row['weapon']
            vm.mem_write(0x56536 + i * 55, bytes(record))
        for i, name in enumerate(data['enemies']):
            record = bytearray(35)
            raw = short(name)
            record[:len(raw)] = raw
            vm.mem_write(0x56f39 + i * 35, bytes(record))
        for who in range(1, 8):
            for weapon in range(256):
                cases.append(run(profile, who, 1, 0, 1 if who % 2 else 7, weapon))
            for whom in [1, 7]:
                for how, shift in [(2, 0), (3, 6), (4, 12), (5, 18), (6, 40)]:
                    for magic in range(1, 46):
                        cases.append(run(profile, who, how, magic - shift, whom))
            for how in [-32768, -256, -1, 0, 7, 8, 255, 256, 32767]:
                cases.append(run(profile, who, how, -32768, 0))
    unsafe = []
    for who, how, whom in [(0, 0, 0), (8, 0, 0), (1, 2, 0), (1, 2, 8)]:
        if who not in range(1, 8):
            vm.mem_write(0x50000 + 0x64ff + who * 55, short('OtherMemory'))
        if how == 2:
            vm.mem_write(0x50000 + 0x6f16 + whom * 35, short('OtherMemory'))
        unsafe.append(run(1, who, how, 1, whom))
    return dict(scope=__doc__, exeSha256=hashlib.sha256(exe).hexdigest(),
        fragments=[dict(name=n, start=a, end=z,
            sha256=hashlib.sha256(exe[a:z]).hexdigest()) for n, a, z in SPANS],
        profiles=PROFILES, cases=cases, outOfArrayReads=unsafe)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if args.check:
        data = json.loads(OUT.read_text())
        exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
        assert data['scope'] == __doc__ and data['exeSha256'] == hashlib.sha256(exe).hexdigest()
        assert data['fragments'] == [dict(name=n, start=a, end=z,
            sha256=hashlib.sha256(exe[a:z]).hexdigest()) for n, a, z in SPANS]
        assert len(data['cases']) == 10010 and len(data['outOfArrayReads']) == 4
    else:
        OUT.write_text(json.dumps(build(), ensure_ascii=False, separators=(',', ':')) + '\n')


if __name__ == '__main__':
    main()

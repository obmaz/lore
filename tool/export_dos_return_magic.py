"""Original ReturnMagic CASE, string copy and grammatical set helper execution.

All signed 16-bit arguments run without call stubs. Only the procedure's
prologue stack-space check is omitted. Undefined results retain caller buffer
contents, demonstrated with distinct buffers rather than assumed empty strings.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path
from audit_lorespec import decode

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'test/fixtures/dos_return_magic.json'
SPANS = [('ReturnMagic', 0x2b084, 0x2b55b),
         ('stringAssign', 0x36b1c, 0x36b40),
         ('setMembership', 0x36db7, 0x36dd8)]
INVALID = [-32768, -257, -256, -255, -254, -1, 0, 46, 255, 256, 258, 32767]


def build():
    from unicorn import Uc, UC_ARCH_X86, UC_MODE_16
    from unicorn.x86_const import (UC_X86_REG_CS, UC_X86_REG_DS,
        UC_X86_REG_SS, UC_X86_REG_BP, UC_X86_REG_SP, UC_X86_REG_IP)
    exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    header = struct.unpack_from('<H', exe, 8)[0] * 16
    vm = Uc(UC_ARCH_X86, UC_MODE_16)
    vm.mem_map(0, 0x80000)
    vm.mem_write(0, exe[header:])

    def run(magic, seed):
        for reg, value in [(UC_X86_REG_CS, 0x2466), (UC_X86_REG_DS, 0x5000),
                           (UC_X86_REG_SS, 0x6000), (UC_X86_REG_BP, 0x8000),
                           (UC_X86_REG_SP, 0x7e00)]:
            vm.reg_write(reg, value)
        vm.mem_write(0x68006, struct.pack('<hHH', magic, 0, 0x7000))
        before = bytes([len(seed)]) + seed + bytes([254]) * (255 - len(seed))
        vm.mem_write(0x70000, before)
        vm.emu_start(0x2b084 - header, 0x2b55b - header, count=10000)
        assert vm.reg_read(UC_X86_REG_CS) == 0x2466
        assert 0x24660 + vm.reg_read(UC_X86_REG_IP) == 0x2b55b - header
        assert vm.reg_read(UC_X86_REG_SP) == 0x7e00
        after = bytes(vm.mem_read(0x70000, 256))
        def text(pointer):
            length = vm.mem_read(pointer, 1)[0]
            return decode(bytes(vm.mem_read(pointer + 1, length)))
        return dict(magic=magic, name=text(0x70000), josa=text(0x5366c),
                    mokjuk=text(0x53670), unchanged=after == before)

    grammar = []
    defined = []
    unchanged = 0
    for magic in range(-32768, 32768):
        row = run(magic, b'JUNK')
        if 1 <= magic <= 45:
            assert not row['unchanged']
            defined.append(row)
        else:
            assert row['unchanged']
            unchanged += 1
        pair = [row['josa'], row['mokjuk']]
        low = magic & 255
        if len(grammar) < 256:
            assert low == len(grammar)
            grammar.append(pair)
        else:
            assert pair == grammar[low]
    unknown = [dict(seed=seed.decode(), **run(magic, seed))
               for magic in INVALID for seed in [b'JUNK', b'Old result', b'']]
    return dict(scope=__doc__, exeSha256=hashlib.sha256(exe).hexdigest(),
        fragments=[dict(name=n, start=a, end=z,
            sha256=hashlib.sha256(exe[a:z]).hexdigest()) for n, a, z in SPANS],
        checkedInputs=65536, unassignedInputs=unchanged,
        defined=defined, grammarByLowByte=grammar, unassigned=unknown)


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
        assert data['checkedInputs'] == 65536 and data['unassignedInputs'] == 65491
        assert len(data['defined']) == 45 and len(data['grammarByLowByte']) == 256
    else:
        OUT.write_text(json.dumps(build(), ensure_ascii=False, separators=(',', ':')) + '\n')


if __name__ == '__main__':
    main()

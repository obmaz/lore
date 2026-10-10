"""Execute original Load region/resource CASE and weather CASE/setscrolltype.

Only short-string assignment and prologue stack-space checking are supplied.
Original branches, selectors, resource literals and weather stores execute.
No DOS file I/O, playback waveform or BGI compositor parity is claimed.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'test/fixtures/dos_load_state.json'
SPANS = [('resources', 0x2f277, 0x2f366),
         ('weather', 0x2f485, 0x2f4ca),
         ('setscrolltype', 0x29c63, 0x29cf8)]
PROFILES = [(0, 0, 0), (1, 1, 2), (3, 1, 2), (1, 6, 2),
            (9, 1, 2), (255, 254, 253)]


def build():
    from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_CODE
    from unicorn.x86_const import (UC_X86_REG_CS, UC_X86_REG_DS,
        UC_X86_REG_SS, UC_X86_REG_BP, UC_X86_REG_SP, UC_X86_REG_IP)
    exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    header = struct.unpack_from('<H', exe, 8)[0] * 16
    vm = Uc(UC_ARCH_X86, UC_MODE_16)
    vm.mem_map(0, 0x80000)
    vm.mem_write(0, exe[header:])
    assignments = []

    def hook(u, address, size, _):
        offset = address + header
        if offset == 0x29c68:
            # Original stack-check helper only; execute all setter instructions.
            u.reg_write(UC_X86_REG_IP, 0x29c6d - header - 0x24660)
        elif offset in [0x2f2d5, 0x2f2e6, 0x2f2fe, 0x2f30f,
                        0x2f327, 0x2f338, 0x2f350, 0x2f361]:
            sp = u.reg_read(UC_X86_REG_SP)
            limit, dst, ds, src, cs = struct.unpack('<5H', u.mem_read(0x60000 + sp, 10))
            pointer = cs * 16 + src
            length = min(u.mem_read(pointer, 1)[0], limit)
            raw = bytes(u.mem_read(pointer, length + 1))
            u.mem_write(ds * 16 + dst, raw)
            assignments.append(dict(destination=dst, value=raw[1:].decode('ascii')))
            u.reg_write(UC_X86_REG_SP, sp + 10)
            u.reg_write(UC_X86_REG_IP, offset + 5 - header - 0x24660)
    vm.hook_add(UC_HOOK_CODE, hook)

    def run(name):
        # Original LORESUB CS base is required by its embedded string literals.
        for reg, value in [(UC_X86_REG_CS, 0x2466), (UC_X86_REG_DS, 0x5000),
                           (UC_X86_REG_SS, 0x6000), (UC_X86_REG_BP, 0x8000),
                           (UC_X86_REG_SP, 0x7e00)]:
            vm.reg_write(reg, value)
        _, start, end = next(s for s in SPANS if s[0] == name)
        vm.emu_start(start - header, end - header, count=1000)
        assert 0x24660 + vm.reg_read(UC_X86_REG_IP) == end - header
        assert vm.reg_read(UC_X86_REG_SP) == 0x7e00

    resources = []
    for map_id in range(256):
        vm.mem_write(0x564ca, bytes([map_id]))
        vm.mem_write(0x5de2c, b'\x00')
        assignments.clear()
        run('resources')
        assert len(assignments) == 2
        assert [r['destination'] for r in assignments] == [0x367a, 0x39c6]
        resources.append(dict(map=map_id, position=vm.mem_read(0x539bc, 1)[0],
                              font=assignments[0]['value'], music=assignments[1]['value'],
                              quitPlay=vm.mem_read(0x5de2c, 1)[0]))
    weather = []
    for raw in range(256):
        for form, color, put in PROFILES:
            before = bytes(range(100))
            vm.mem_write(0x564d2, before)
            vm.mem_write(0x564dd, bytes([raw]))
            vm.mem_write(0x53d98, bytes([form, color, put]))
            vm.mem_write(0x539bb, b'\xff')
            run('weather')
            after = bytes(vm.mem_read(0x564d2, 100))
            assert after[:11] == before[:11] and after[12:] == before[12:]
            stores = list(vm.mem_read(0x53d98, 3))
            weather.append(dict(raw=raw, before=[form, color, put],
                                mode=vm.mem_read(0x539bb, 1)[0],
                                after=stores, etc12=after[11]))
    return dict(scope=__doc__, exeSha256=hashlib.sha256(exe).hexdigest(),
                fragments=[dict(name=n, start=a, end=z,
                    sha256=hashlib.sha256(exe[a:z]).hexdigest()) for n, a, z in SPANS],
                resources=resources, weather=weather)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if args.check:
        data = json.loads(OUT.read_text())
        exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
        assert data['scope'] == __doc__
        assert data['exeSha256'] == hashlib.sha256(exe).hexdigest()
        assert data['fragments'] == [dict(name=n, start=a, end=z,
            sha256=hashlib.sha256(exe[a:z]).hexdigest()) for n, a, z in SPANS]
        assert len(data['resources']) == 256 and len(data['weather']) == 1536
    else:
        OUT.write_text(json.dumps(build(), separators=(',', ':')) + '\n')


if __name__ == '__main__':
    main()

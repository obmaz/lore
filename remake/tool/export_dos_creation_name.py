"""Original Name single-key loop and sex gate, with native string operations.

ReadKey is supplied, and only CRT/BGI output spans are skipped. All counter,
reset, string concat, repeat termination and UpCase/sex stores are original.
No glyph, IME, polling duration or graphic output equivalence is claimed.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'test/fixtures/dos_creation_name.json'
SPANS = [(0x88f0, 0x8a13), (0x8a88, 0x8ad9)]

def build():
    from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_CODE
    from unicorn.x86_const import UC_X86_REG_CS, UC_X86_REG_DS, UC_X86_REG_SS, UC_X86_REG_BP, UC_X86_REG_SP, UC_X86_REG_IP, UC_X86_REG_AX
    exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    header = struct.unpack_from('<H', exe, 8)[0] * 16
    vm = Uc(UC_ARCH_X86, UC_MODE_16)
    vm.mem_map(0, 0x80000)
    vm.mem_write(0, exe[header:])
    state = {}
    def hook(u, address, size, _):
        address += header
        if address in (0x88f4, 0x8903, 0x8a88):
            if address == 0x8a88 and state['reads']:
                state['complete'] = False
                u.emu_stop()
                return
            state['reads'] += 1
            u.reg_write(UC_X86_REG_AX, state['scan'] if address == 0x8903 else state['key'])
            u.reg_write(UC_X86_REG_IP, address + 5 - header)
        if address in (0x896a, 0x89b3, 0x8aa9, 0x8ac7):
            u.reg_write(UC_X86_REG_IP, {
                0x896a: 0x899b, 0x89b3: 0x89f1,
                0x8aa9: 0x8abb, 0x8ac7: 0x8ad9,
            }[address] - header)
        if address in (0x8a10, 0x8a13, 0x8ad9):
            state['complete'] = address != 0x8a10
            u.emu_stop()
    vm.hook_add(UC_HOOK_CODE, hook)
    def setup(key, scan=0):
        for r, v in [(UC_X86_REG_CS, 0), (UC_X86_REG_DS, 0x5000),
                     (UC_X86_REG_SS, 0x6000), (UC_X86_REG_BP, 0x8000), (UC_X86_REG_SP, 0x7e00)]:
            vm.reg_write(r, v)
        state.clear()
        state.update(key=key, scan=scan, reads=0)
    cases = []
    for length in range(17):
        for key in range(256):
            setup(key)
            vm.mem_write(0x5365e, struct.pack('<h', length))
            vm.mem_write(0x5367a, bytes([length]) + b'A' * length + bytes(255-length))
            vm.emu_start(0x88f0-header, 0x7ffff, count=10000)
            assert 'complete' in state
            size = vm.mem_read(0x5367a, 1)[0]
            cases.append(dict(length=length, key=key, scan=0,
                text=list(vm.mem_read(0x5367b, size)),
                counter=struct.unpack('<h', vm.mem_read(0x5365e, 2))[0],
                reads=state['reads'], complete=state['complete']))
        for scan in range(256):
            setup(0, scan)
            vm.mem_write(0x5365e, struct.pack('<h', length))
            vm.mem_write(0x5367a, bytes([length]) + b'A'*length + bytes(255-length))
            vm.emu_start(0x88f0-header, 0x7ffff, count=10000)
            assert 'complete' in state
            size = vm.mem_read(0x5367a, 1)[0]
            cases.append(dict(length=length, key=0, scan=scan,
                text=list(vm.mem_read(0x5367b, size)),
                counter=struct.unpack('<h', vm.mem_read(0x5365e, 2))[0],
                reads=state['reads'], complete=state['complete']))
    gender = []
    for key in range(256):
        setup(key)
        vm.mem_write(0x56548, b'\xff')
        vm.emu_start(0x8a88-header, 0x7ffff, count=10000)
        assert 'complete' in state
        gender.append(dict(key=key, complete=state['complete'],
            sex=vm.mem_read(0x56548, 1)[0] if state['complete'] else None))
    return dict(scope=__doc__, exeSha256=hashlib.sha256(exe).hexdigest(),
        fragments=[dict(start=a, end=z, sha256=hashlib.sha256(exe[a:z]).hexdigest()) for a,z in SPANS],
        cases=cases, gender=gender)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    if args.check:
        data = json.loads(OUT.read_text())
        assert data['exeSha256'] == hashlib.sha256(exe).hexdigest()
        assert data['scope'] == __doc__
        assert data['fragments'] == [dict(start=a,end=z,sha256=hashlib.sha256(exe[a:z]).hexdigest()) for a,z in SPANS]
        assert len(data['cases']) == 8704 and len(data['gender']) == 256
    else:
        OUT.write_text(json.dumps(build(),separators=(',',':'))+'\n')

if __name__ == '__main__':
    main()

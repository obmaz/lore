"""Original Main idle polling, extended-byte gate and Tab BIOS request.

KeyPressed/ReadKey and BIOS are supplied platform boundaries. Original set
membership, direction assignments and map26 face adjustment execute unchanged.
Not full keyboard FIFO, modal input, DAC pixels or whole Main tile dispatch.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'test/fixtures/dos_main_input_gates.json'


def build():
    from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_CODE, UC_HOOK_INTR
    from unicorn.x86_const import (
        UC_X86_REG_CS, UC_X86_REG_DS, UC_X86_REG_SS, UC_X86_REG_SP,
        UC_X86_REG_BP, UC_X86_REG_IP, UC_X86_REG_AX, UC_X86_REG_BX, UC_X86_REG_CX,
    )
    exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    header = struct.unpack_from('<H', exe, 8)[0] * 16
    base = 0x7940
    vm = Uc(UC_ARCH_X86, UC_MODE_16)
    vm.mem_map(0, 0x80000)
    vm.mem_write(0, exe[header:])
    ctx = {}

    def hook(u, address, size, data):
        offset = address + header
        if offset in (0x8020, 0x802c, 0x80c1):
            ctx['events'].append('poll' if offset == 0x8020 else 'read')
            u.reg_write(UC_X86_REG_AX, ctx['ready'] if offset == 0x8020 else ctx['byte'])
            u.reg_write(UC_X86_REG_IP, offset + 5 - base)
        if offset in ctx['ends']:
            ctx['end'] = offset
            u.emu_stop()

    def interrupt(u, number, data):
        ctx['events'].append([number, u.reg_read(UC_X86_REG_AX),
                              u.reg_read(UC_X86_REG_BX), u.reg_read(UC_X86_REG_CX)])

    vm.hook_add(UC_HOOK_CODE, hook)
    vm.hook_add(UC_HOOK_INTR, interrupt)

    def run(start, ends, byte=0, ready=0, position=0, map_id=1, face=3):
        ctx.update(events=[], ends=ends, byte=byte, ready=ready, end=None)
        for reg, value in [(UC_X86_REG_CS, (base-header)//16),
                           (UC_X86_REG_DS, 0x5000), (UC_X86_REG_SS, 0x6000),
                           (UC_X86_REG_BP, 0x8000), (UC_X86_REG_SP, 0x7f00)]:
            vm.reg_write(reg, value)
        vm.mem_write(0x5366a, bytes([byte if start != 0x80b2 else 0]))
        vm.mem_write(0x539b0, struct.pack('<hhB', 0, 0, 1))
        vm.mem_write(0x539bc, bytes([position]))
        vm.mem_write(0x53d9c, bytes([face]))
        vm.mem_write(0x564ca, bytes([map_id]))
        vm.emu_start(start-header, 0x7ffff, count=5000)
        assert ctx['end'] in ends
        dx, dy, ok = struct.unpack('<hhB', vm.mem_read(0x539b0, 5))
        return dict(events=list(ctx['events']), end=ctx['end'], dx=dx, dy=dy,
                    ok=bool(ok), face=vm.mem_read(0x53d9c, 1)[0],
                    c=vm.mem_read(0x5366a, 1)[0])

    polls = [dict(ready=ready, result=run(0x8011, {0x8034, 0x8463}, byte=77, ready=ready))
             for ready in [0, 1]]
    scans = [dict(scan=scan, position=position, mapId=map_id,
                  result=run(0x80b2, {0x816d}, byte=scan, position=position, map_id=map_id))
             for position in range(4) for map_id in [1, 26] for scan in range(256)]
    tabs = [dict(byte=byte, result=run(0x818d, {0x81a0}, byte=byte)) for byte in range(256)]
    face_wraps = [dict(scan=scan, face=face,
                       result=run(0x80b2, {0x816d}, byte=scan, map_id=26, face=face))
                  for face in [0, 3, 4, 55, 251, 255] for scan in [0, 71, 80]]
    spans = [(0x8011, 0x8034), (0x80b2, 0x816d), (0x818d, 0x81a0)]
    return dict(scope=__doc__, exeSha256=hashlib.sha256(exe).hexdigest(),
                fragments=[dict(start=a, end=z, sha256=hashlib.sha256(exe[a:z]).hexdigest())
                           for a, z in spans], polls=polls, scans=scans, tabs=tabs, faceWraps=face_wraps)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    if parser.parse_args().check:
        assert json.loads(OUT.read_text()) == build()
        print('Original Main poll, 2048 extended-key cases and 256 Tab gates matched')
    else:
        OUT.write_text(json.dumps(build(), separators=(',', ':')) + '\n')

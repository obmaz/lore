"""Original seven remains blink loops, Delay/PutImage arguments and final map store.

Only platform Delay/PutImage/message calls are supplied. Original coordinates,
loop counters, branch ordering and final map mutation execute unmodified.
BGI hardware pixels and the CPU's wall-clock delay implementation are excluded.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'test/fixtures/dos_remains_blink.json'
SPANS = [(827, 10, 14, 0x132bc, 0x1334b),
         (873, 10, 18, 0x13503, 0x13592),
         (909, 10, 30, 0x136e0, 0x1376f),
         (960, 21, 32, 0x13965, 0x139f4),
         (1009, 21, 22, 0x13bd2, 0x13c61),
         (1038, 21, 12, 0x13d51, 0x13de0),
         (1050, 8, 8, 0x13de3, 0x13e83)]
DELTAS = [(0, 1), (0, -1), (1, 0), (-1, 0), (-32768, 32767),
          (32767, -32768), (-32767, 32766), (32766, -32767),
          (-256, 255), (255, -256), (-100, 100), (100, -100), (0, 0), (-1, -1)]


def build():
    from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_CODE, UC_HOOK_MEM_WRITE
    from unicorn.x86_const import (UC_X86_REG_CS, UC_X86_REG_DS,
        UC_X86_REG_SS, UC_X86_REG_BP, UC_X86_REG_SP, UC_X86_REG_IP)
    exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    header = struct.unpack_from('<H', exe, 8)[0] * 16
    vm = Uc(UC_ARCH_X86, UC_MODE_16)
    vm.mem_map(0, 0x80000)
    vm.mem_write(0, exe[header:])
    trace = []
    pointer = 0

    def hook(u, address, size, _):
        offset = address + header
        if exe[offset:offset+1] != b'\x9a':
            return
        target, segment = struct.unpack_from('<HH', exe, offset + 1)
        sp = u.reg_read(UC_X86_REG_SP)
        assert u.mem_read(pointer, 1)[0] == 48, 'map changed before final store'
        if (segment, target) == (0x306b, 0x29c):
            milliseconds = struct.unpack('<H', u.mem_read(0x60000 + sp, 2))[0]
            trace.append(['delay', milliseconds])
            arguments = 2
        elif (segment, target) == (0x2d04, 0xe52):
            op, image, image_segment, y, x = struct.unpack('<5H', u.mem_read(0x60000 + sp, 10))
            assert image_segment == 0x7000 and image % 246 == 0
            signed = lambda n: (n + 32768) % 65536 - 32768
            trace.append(['draw', signed(x), signed(y), image // 246, op])
            arguments = 10
        elif (segment, target) == (0x2466, 0x48c):
            arguments = 6 # Default branch's non-blocking message adapter.
        else:
            raise AssertionError((offset, segment, target))
        u.reg_write(UC_X86_REG_SP, sp + arguments)
        u.reg_write(UC_X86_REG_IP, offset + 5 - header - 0x8000)

    def write(u, access, address, size, value, _):
        if address == pointer:
            assert size == 1 and value == 35
            trace.append(['write', 35])
    vm.hook_add(UC_HOOK_CODE, hook)
    vm.hook_add(UC_HOOK_MEM_WRITE, write)
    cases = []
    signed = lambda n: (n + 32768) % 65536 - 32768
    for line, tx, ty, start, end in SPANS:
        for dx, dy in DELTAS:
            for reg, value in [(UC_X86_REG_CS, 0x800), (UC_X86_REG_DS, 0x5000),
                               (UC_X86_REG_SS, 0x6000), (UC_X86_REG_BP, 0x8000),
                               (UC_X86_REG_SP, 0x7e00)]:
                vm.reg_write(reg, value)
            vm.mem_write(0x539ac, struct.pack('<hhhh', signed(tx-dx), signed(ty-dy), dx, dy))
            vm.mem_write(0x53da0, struct.pack('<HH', 0, 0x7000))
            pointer = 0x50000 + 0x3d43 + tx * 100 + ty
            vm.mem_write(pointer, bytes([48]))
            trace.clear()
            vm.emu_start(start - header, end - header, count=10000)
            assert 0x8000 + vm.reg_read(UC_X86_REG_IP) == end - header
            assert vm.reg_read(UC_X86_REG_SP) == 0x7e00
            assert len(trace) == 121 and trace[-1] == ['write', 35]
            assert vm.mem_read(pointer, 1)[0] == 35
            cases.append(dict(line=line, target=[tx, ty], dx=dx, dy=dy, trace=list(trace)))
    return dict(scope=__doc__, exeSha256=hashlib.sha256(exe).hexdigest(),
        fragments=[dict(line=l, start=a, end=z,
            sha256=hashlib.sha256(exe[a:z]).hexdigest()) for l, _, _, a, z in SPANS], cases=cases)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if args.check:
        data = json.loads(OUT.read_text())
        exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
        assert data['scope'] == __doc__ and data['exeSha256'] == hashlib.sha256(exe).hexdigest()
        assert data['fragments'] == [dict(line=l, start=a, end=z,
            sha256=hashlib.sha256(exe[a:z]).hexdigest()) for l, _, _, a, z in SPANS]
        assert len(data['cases']) == len(SPANS) * len(DELTAS)
    else:
        OUT.write_text(json.dumps(build(), separators=(',', ':')) + '\n')


if __name__ == '__main__':
    main()

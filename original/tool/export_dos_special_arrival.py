"""Execute original LORESPEC arrival loops; supply only Delay/PutImage.

BGI pixels and CPU wall-clock timing are excluded. Original loop counters,
branching, image-bank addressing and Pascal map reads execute unchanged.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'test/fixtures/dos_special_arrival.json'
SPANS = [('guardian', 0x1ef38, 0x1f081), ('final', 0x1f3ee, 0x1f720)]


def build():
    from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_CODE
    from unicorn.x86_const import (UC_X86_REG_CS, UC_X86_REG_DS,
        UC_X86_REG_SS, UC_X86_REG_BP, UC_X86_REG_SP, UC_X86_REG_IP)
    exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    header = struct.unpack_from('<H', exe, 8)[0] * 16
    vm = Uc(UC_ARCH_X86, UC_MODE_16)
    vm.mem_map(0, 0x90000)
    vm.mem_write(0, exe[header:])
    trace = []

    def hook(u, address, size, _):
        offset = address + header
        if exe[offset:offset+1] != b'\x9a':
            return
        target, segment = struct.unpack_from('<HH', exe, offset + 1)
        sp = u.reg_read(UC_X86_REG_SP)
        if (segment, target) == (0x306b, 0x29c):
            ms = struct.unpack('<H', u.mem_read(0x60000 + sp, 2))[0]
            trace.append(['delay', ms])
            arguments = 2
        elif (segment, target) == (0x2d04, 0xe52):
            op, image, bank, y, x = struct.unpack('<5H', u.mem_read(0x60000 + sp, 10))
            assert bank in (0x7000, 0x8000) and image % 246 == 0
            trace.append(['draw', 'font' if bank == 0x7000 else 'chara', x, y, image // 246, op])
            arguments = 10
        else:
            raise AssertionError((offset, segment, target))
        u.reg_write(UC_X86_REG_SP, sp + arguments)
        u.reg_write(UC_X86_REG_IP, offset + 5 - header - 0x18000)

    vm.hook_add(UC_HOOK_CODE, hook)
    cases = []
    for kind, start, end in SPANS:
        for x, y in ([(24,43),(25,43),(26,43),(27,43),(6,6),(94,94)]
                     if kind == 'guardian' else [(26,12),(27,12),(6,6),(94,94)]):
            for salt in (0, 7, 55):
                for reg, value in [(UC_X86_REG_CS, 0x1800), (UC_X86_REG_DS, 0x5000),
                        (UC_X86_REG_SS, 0x6000), (UC_X86_REG_BP, 0x8000), (UC_X86_REG_SP, 0x7e00)]:
                    vm.reg_write(reg, value)
                # Native fixed-stride map storage; every accessed cell is defined.
                data = bytearray(10202)
                for mx in range(1,101):
                    for my in range(1,101):
                        data[mx*100+my] = (mx*17+my*13+salt)%56
                vm.mem_write(0x53d43, bytes(data))
                # Pointer slots overlap the historical overallocated map region.
                vm.mem_write(0x539ac, struct.pack('<hh', x, y))
                vm.mem_write(0x53da0, struct.pack('<HHHH', 0,0x7000,0,0x8000))
                trace.clear()
                vm.emu_start(start-header, end-header, count=20000)
                assert 0x18000 + vm.reg_read(UC_X86_REG_IP) == end-header
                assert vm.reg_read(UC_X86_REG_SP) == 0x7e00
                cases.append(dict(kind=kind,x=x,y=y,salt=salt,trace=list(trace)))
    return dict(scope=__doc__,exeSha256=hashlib.sha256(exe).hexdigest(),
        fragments=[dict(kind=k,start=a,end=z,sha256=hashlib.sha256(exe[a:z]).hexdigest())
                   for k,a,z in SPANS],cases=cases)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    data = build()
    if args.check:
        assert json.loads(OUT.read_text()) == data, 'arrival fixture drift'
    else:
        OUT.write_text(json.dumps(data,separators=(',',':'))+'\n')


if __name__ == '__main__':
    main()

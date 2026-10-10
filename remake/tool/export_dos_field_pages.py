"""Original six lava strings/RNG and both swamp/lava message-page loops.

String assignment/comparison/concatenation, Str and RNG helpers execute unchanged.
SetActivePage/Print are supplied presentation boundaries, not equal BGI pixels.
Poison flags and named-slot masks are synthetic inputs at the closed page branch.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path
from audit_lorespec import decode

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'test/fixtures/dos_field_pages.json'


def build():
    from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_CODE
    from unicorn.x86_const import (UC_X86_REG_CS, UC_X86_REG_DS, UC_X86_REG_SS,
                                  UC_X86_REG_SP, UC_X86_REG_BP, UC_X86_REG_IP)
    exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    header = struct.unpack_from('<H', exe, 8)[0] * 16
    base = 0x7940
    vm = Uc(UC_ARCH_X86, UC_MODE_16)
    vm.mem_map(0, 0x80000)
    vm.mem_write(0, exe[header:])
    ctx = {}
    strings = []
    print_calls = {0x7b48, 0x7b54, 0x7bb0, 0x7cec, 0x7cf8, 0x7d57}

    def hook(u, address, size, data):
        offset = address + header
        sp = u.reg_read(UC_X86_REG_SP)
        if offset == 225719:
            if not ctx['bounds']:
                ctx['clearedBeforeFirstDraw'] = [u.mem_read(0x5377a+slot*51, 1)[0]
                                                for slot in range(1, 7)]
            ctx['bounds'].append(struct.unpack('<H', u.mem_read(0x60000 + sp + 4, 2))[0])
        if offset in {0x7b3c, 0x7ce0}:
            page = struct.unpack('<H', u.mem_read(0x60000 + sp, 2))[0]
            ctx['pages'].append(dict(page=page, lines=[]))
            u.reg_write(UC_X86_REG_SP, sp + 2)
            u.reg_write(UC_X86_REG_IP, offset + 5 - base)
        elif offset in print_calls:
            off, seg, color = struct.unpack('<HHH', u.mem_read(0x60000 + sp, 6))
            pointer = seg * 16 + off
            length = u.mem_read(pointer, 1)[0]
            text = decode(bytes(u.mem_read(pointer + 1, length)))
            if text not in strings:
                strings.append(text)
            ctx['pages'][-1]['lines'].append([color, strings.index(text)])
            u.reg_write(UC_X86_REG_SP, sp + 6)
            u.reg_write(UC_X86_REG_IP, offset + 5 - base)

    vm.hook_add(UC_HOOK_CODE, hook)

    def run(start, end):
        for reg, value in [(UC_X86_REG_CS, (base-header)//16),
                           (UC_X86_REG_DS, 0x5000), (UC_X86_REG_SS, 0x6000),
                           (UC_X86_REG_BP, 0x8000), (UC_X86_REG_SP, 0x7c00)]:
            vm.reg_write(reg, value)
        try:
            vm.emu_start(start-header, end-header, count=200000)
        except Exception as error:
            raise RuntimeError(f'fragment {start:x}: CS/IP={vm.reg_read(UC_X86_REG_CS):x}/{vm.reg_read(UC_X86_REG_IP):x}') from error
        assert base + vm.reg_read(UC_X86_REG_IP) == end

    def players(names, luck):
        for slot in range(1, 8):
            record = bytearray(55)
            name = f'MEM{slot}'.encode() if slot <= 6 and names & (1 << (slot-1)) else b''
            record[0] = len(name)
            record[1:1+len(name)] = name
            if slot <= 6:
                record[29] = luck[slot-1]
                record[30] = 7 if slot % 2 else 0
            vm.mem_write(0x564ff + slot*55, bytes(record))

    def poison():
        return [vm.mem_read(0x564ff + slot*55 + 30, 1)[0] for slot in range(1, 7)]

    swamp = []
    for names in range(64):
        for marks in range(64):
            players(names, [0]*6)
            for slot in range(1, 7):
                vm.mem_write(0x5377a + slot*51, b'\x01!' if marks & (1 << (slot-1)) else b'\x00?')
            initial_page = (names + marks) % 2
            vm.mem_write(0x59c10, bytes([initial_page]))
            ctx.update(pages=[], bounds=[])
            before = poison()
            run(0x7b11, 0x7bd8)
            swamp.append(dict(names=names, marks=marks, initialPage=initial_page,
                              beforePoison=before, afterPoison=poison(), pages=ctx['pages']))

    lava = []
    # A separate branch replay has its own caller CPU context and runtime data.
    vm = Uc(UC_ARCH_X86, UC_MODE_16)
    vm.mem_map(0, 0x80000)
    vm.mem_write(0, exe[header:])
    vm.hook_add(UC_HOOK_CODE, hook)
    for seed in [0, 1, 0xdeadbeef, 0xffffffff]:
        for luck in [[0]*6, [1, 5, 10, 20, 128, 255], [255]*6]:
            for stale in [b'', b'OLD', b'-32768', b'X'*50]:
                vm = Uc(UC_ARCH_X86, UC_MODE_16)
                vm.mem_map(0, 0x80000)
                vm.mem_write(0, exe[header:])
                vm.hook_add(UC_HOOK_CODE, hook)
                players(63, luck)
                vm.mem_write(0x5364c, struct.pack('<I', seed))
                for slot in range(1, 8):
                    vm.mem_write(0x5377a+slot*51, bytes([len(stale)])+stale+b'\xfe'*(50-len(stale)))
                scratch7 = bytes(vm.mem_read(0x5377a+7*51, 51)).hex()
                ctx.update(pages=[], bounds=[])
                run(0x7c47, 0x7cb5)
                texts = []
                for slot in range(1, 7):
                    pointer = 0x5377a+slot*51
                    length = vm.mem_read(pointer, 1)[0]
                    texts.append(bytes(vm.mem_read(pointer+1, length)).decode('ascii'))
                initial_page = seed % 2
                vm.mem_write(0x59c10, bytes([initial_page]))
                run(0x7cb5, 0x7d6d)
                assert bytes(vm.mem_read(0x5377a+7*51, 51)).hex() == scratch7
                lava.append(dict(seed=seed, luck=luck, stale=stale.decode(), texts=texts,
                                 clearedBeforeFirstDraw=ctx['clearedBeforeFirstDraw'],
                                 bounds=ctx['bounds'], afterSeed=struct.unpack('<I', vm.mem_read(0x5364c, 4))[0],
                                 initialPage=initial_page, pages=ctx['pages'], scratch7Preserved=True))
    spans = [(0x7b11, 0x7bd8), (0x7c47, 0x7d6d)]
    return dict(scope=__doc__, exeSha256=hashlib.sha256(exe).hexdigest(),
                fragments=[dict(start=a, end=z, sha256=hashlib.sha256(exe[a:z]).hexdigest())
                           for a, z in spans], strings=strings, swamp=swamp, lava=lava)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    if parser.parse_args().check:
        assert json.loads(OUT.read_text()) == build()
        print('Original swamp 4096 page branches and lava 48 scratch/RNG/page traces matched')
    else:
        OUT.write_text(json.dumps(build(), separators=(',', ':')) + '\n')

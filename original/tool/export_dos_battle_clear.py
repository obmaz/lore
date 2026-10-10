"""Original BattleMode k<>1 and DisplayEnemies clean callback traces.

Only the closed conditional fragments execute. Graph/Clear calls are observed
and supplied; glyphs, BGI pixels and the remainder of BattleMode are not proved.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'test/fixtures/dos_battle_clear.json'


def build():
    from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_CODE
    from unicorn.x86_const import (
        UC_X86_REG_CS, UC_X86_REG_DS, UC_X86_REG_SS,
        UC_X86_REG_SP, UC_X86_REG_BP, UC_X86_REG_IP,
    )
    exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    header = struct.unpack_from('<H', exe, 8)[0] * 16
    base = 0x207f0
    vm = Uc(UC_ARCH_X86, UC_MODE_16)
    vm.mem_map(0, 0x80000)
    vm.mem_write(0, exe[header:])
    events = []
    calls = {0x24c9e: ('Clear', 0), 0x20aac: ('SetFillStyle', 2),
             0x20abb: ('Bar', 4), 0x20ac4: ('SetFillStyle', 2)}

    def hook(u, address, size, data):
        offset = address + header
        if offset not in calls:
            return
        name, count = calls[offset]
        sp = u.reg_read(UC_X86_REG_SP)
        args = list(struct.unpack('<' + 'H' * count,
                                 u.mem_read(0x60000 + sp, count * 2))) if count else []
        events.append([name, list(reversed(args))])
        u.reg_write(UC_X86_REG_SP, sp + count * 2)
        u.reg_write(UC_X86_REG_IP, offset + 5 - base)

    vm.hook_add(UC_HOOK_CODE, hook)

    def run(start, end):
        events.clear()
        for reg, value in [(UC_X86_REG_CS, (base-header)//16),
                           (UC_X86_REG_DS, 0x5000), (UC_X86_REG_SS, 0x6000),
                           (UC_X86_REG_BP, 0x8000), (UC_X86_REG_SP, 0x7f00)]:
            vm.reg_write(reg, value)
        vm.emu_start(start-header, end-header, count=100)
        assert base + vm.reg_read(UC_X86_REG_IP) == end
        return list(events)

    commands = []
    for k in range(256):
        vm.mem_write(0x53662, struct.pack('<h', k))
        commands.append(dict(k=k, events=run(0x24c97, 0x24ca3)))
    displays = []
    for clean in [False, True]:
        vm.mem_write(0x68006, bytes([clean]))
        displays.append(dict(clean=clean, events=run(0x20aa2, 0x20ac9)))
    spans = [(0x24c97, 0x24ca3), (0x20aa2, 0x20ac9)]
    return dict(scope=__doc__, exeSha256=hashlib.sha256(exe).hexdigest(),
                fragments=[dict(start=a, end=z, sha256=hashlib.sha256(exe[a:z]).hexdigest())
                           for a, z in spans], commands=commands, displays=displays)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    if parser.parse_args().check:
        assert json.loads(OUT.read_text()) == build()
        print('Original battle Clear and backdrop callback traces matched')
    else:
        OUT.write_text(json.dumps(build(), indent=2) + '\n')

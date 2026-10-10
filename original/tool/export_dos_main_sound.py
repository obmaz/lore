#!/usr/bin/env python3
"""Execute original Main's shared-c SoundOn branch; synthetic byte inputs only."""
import argparse
import hashlib
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'test/fixtures/dos_main_sound.json'
START, END = 0x81a0, 0x81b4


def build():
    from unicorn import Uc, UC_ARCH_X86, UC_MODE_16
    from unicorn.x86_const import UC_X86_REG_CS, UC_X86_REG_DS
    exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    header = struct.unpack_from('<H', exe, 8)[0] * 16
    rows = []
    for key in (8, 13, 27, 32, 72):
        for enabled in (0, 1):
            u = Uc(UC_ARCH_X86, UC_MODE_16)
            u.mem_map(0, 0x80000)
            u.mem_write(0, exe[header:])
            u.reg_write(UC_X86_REG_CS, 0)
            u.reg_write(UC_X86_REG_DS, 0x5000)
            u.mem_write(0x5366a, bytes([key]))
            u.mem_write(0x539ba, bytes([enabled]))
            u.emu_start(START - header, END - header, count=100)
            after = u.mem_read(0x539ba, 1)[0]
            assert after == (1 - enabled if key == 8 else enabled)
            rows.append(dict(key=key, before=enabled, after=after))
    return dict(scope='Original Main SoundOn byte branch, synthetic c/SoundOn inputs; not full DOS audio/campaign replay.',
                executableSha256=hashlib.sha256(exe).hexdigest(),
                fragment=dict(start=START, end=END,
                              sha256=hashlib.sha256(exe[START:END]).hexdigest()),
                cases=rows)


def check():
    assert json.loads(OUT.read_text()) == build()
    print('Original Main shared-c Backspace/SoundOn branch: verified')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--check', action='store_true')
    if p.parse_args().check:
        check()
    else:
        OUT.write_text(json.dumps(build(), indent=2) + '\n')
        check()

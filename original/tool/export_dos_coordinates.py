"""Execute original at/on ADD, CMP, branches and boolean result instructions.

Synthetic globals and procedure arguments, stopping before RETF. Only the
prologue stack-space check is omitted; no map bounds or rendering is claimed.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'test/fixtures/dos_coordinates.json'
SPANS = [('at', 0x2c165, 0x2c18b), ('on', 0x2c19c, 0x2c1ba)]
VALUES = [-32768, -32767, -256, -100, -1, 0, 1, 8, 25, 26, 100, 255, 32766, 32767]

def build():
    from unicorn import Uc, UC_ARCH_X86, UC_MODE_16
    from unicorn.x86_const import UC_X86_REG_CS, UC_X86_REG_DS, UC_X86_REG_SS, UC_X86_REG_BP, UC_X86_REG_SP, UC_X86_REG_AX, UC_X86_REG_IP
    exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    header = struct.unpack_from('<H', exe, 8)[0] * 16
    vm = Uc(UC_ARCH_X86, UC_MODE_16)
    vm.mem_map(0, 0x80000)
    vm.mem_write(0, exe[header:])
    def signed(value):
        return (value + 32768) % 65536 - 32768
    def run(name, x, y, dx, dy, xx, yy):
        for reg, value in [(UC_X86_REG_CS, 0x2000), (UC_X86_REG_DS, 0x5000),
                           (UC_X86_REG_SS, 0x6000), (UC_X86_REG_BP, 0x8000),
                           (UC_X86_REG_SP, 0x7ffe)]:
            vm.reg_write(reg, value)
        vm.mem_write(0x539ac, struct.pack('<hhhh', x, y, dx, dy))
        vm.mem_write(0x68006, struct.pack('<hh', yy, xx))
        _, start, end = next(span for span in SPANS if span[0] == name)
        vm.emu_start(start-header, end-header, count=100)
        assert 0x20000 + vm.reg_read(UC_X86_REG_IP) == end-header
        return bool(vm.reg_read(UC_X86_REG_AX) & 255)
    at = []
    on = []
    for x in VALUES:
        for delta in VALUES:
            # Both axes overflow independently, with every combination of
            # matching and nonmatching comparison targets.
            y, dy = signed(-x-1), signed(-delta-1)
            for ox in [-1, 0, 1]:
                for oy in [-1, 0, 1]:
                    xx, yy = signed(x+delta+ox), signed(y+dy+oy)
                    at.append([x,y,delta,dy,xx,yy,run('at',x,y,delta,dy,xx,yy)])
                    xx, yy = signed(x+ox), signed(delta+oy)
                    on.append([x,delta,xx,yy,run('on',x,delta,32767,-32768,xx,yy)])
    return dict(scope=__doc__, exeSha256=hashlib.sha256(exe).hexdigest(),
        fragments=[dict(name=n,start=a,end=z,sha256=hashlib.sha256(exe[a:z]).hexdigest()) for n,a,z in SPANS],at=at,on=on)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if args.check:
        data = json.loads(OUT.read_text())
        exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
        assert data['scope'] == __doc__
        assert data['exeSha256'] == hashlib.sha256(exe).hexdigest()
        assert data['fragments'] == [dict(name=n,start=a,end=z,sha256=hashlib.sha256(exe[a:z]).hexdigest()) for n,a,z in SPANS]
        assert len(data['at']) == len(data['on']) == len(VALUES)**2*9
    else:
        OUT.write_text(json.dumps(build(), separators=(',',':'))+'\n')

if __name__ == '__main__':
    main()

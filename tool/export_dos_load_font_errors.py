"""Complete native Load to its nested ErrorMessage entry or successful return.

DOS file operations and stack guard are platform boundaries. Original Reset,
typed Read (including short-byte counts), Close, IOResult and Load conditions
execute. ErrorMessage argument capture stops before its separately replayed
text/Halt body; this fixture does not claim its UI or BGI pixel output.
Warm CHARA and unselected region files must never be opened.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path
from export_dos_load_phases import START, END, MAPS, players, party

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'test/fixtures/dos_load_font_errors.json'


def profiles():
    for map_id, selected in [(1, 'ground.fnt'), (6, 'town.fnt'), (14, 'den.fnt'), (21, 'keep.fnt')]:
        for mode in ['missing', 'truncated']:
            yield map_id, False, 'chara.fnt', mode
            yield map_id, True, 'chara.fnt', mode
            for warm in [False, True]:
                yield map_id, warm, selected, mode
                yield map_id, warm, ('den.fnt' if selected == 'ground.fnt' else 'ground.fnt'), mode


def build():
    from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_CODE, UC_HOOK_INTR
    from unicorn.x86_const import (UC_X86_REG_CS, UC_X86_REG_DS, UC_X86_REG_SS,
        UC_X86_REG_BP, UC_X86_REG_SP, UC_X86_REG_IP, UC_X86_REG_AX, UC_X86_REG_BX,
        UC_X86_REG_CX, UC_X86_REG_DX, UC_X86_REG_ES, UC_X86_REG_SI, UC_X86_REG_EFLAGS)
    root = ROOT / 'repo_source/LORE_1993_runtime'
    exe = (root / 'LORE.EXE').read_bytes()
    header = struct.unpack_from('<H', exe, 8)[0] * 16
    resources = {p.name.lower(): p.read_bytes() for p in root.glob('*.FNT')}
    cases = []
    for map_id, warm, target, mode in profiles():
        map_name = MAPS[map_id-1]
        canonical = (root / f'{map_name}.MAP').read_bytes()
        files = dict(resources, **{'party1.dat': party(map_id, 1000),
            'player1.dat': b''.join(players('FILE')[:6]), map_name.lower()+'.map': canonical})
        if mode == 'missing': del files[target]
        else: files[target] = files[target][:-1]
        vm = Uc(UC_ARCH_X86, UC_MODE_16)
        vm.mem_map(0, 0x80000)
        vm.mem_write(0, exe[header:])
        for reg, value in [(UC_X86_REG_CS, 0x2466), (UC_X86_REG_DS, 0x5000),
            (UC_X86_REG_SS, 0x6000), (UC_X86_REG_BP, 0x8000), (UC_X86_REG_SP, 0x7d00)]:
            vm.reg_write(reg, value)
        vm.mem_write(0x539b8, bytes([warm]))
        vm.mem_write(0x5366b, b'1')
        vm.mem_write(0x53da0, struct.pack('<HHHH', 0, 0x7000, 0, 0x7400))
        vm.mem_write(0x539be, struct.pack('<HHHH', 0x64d8, 0x5000, 0x64d9, 0x5000))
        vm.mem_write(0x564ca, party(map_id, 777))
        vm.mem_write(0x56536, b''.join(players('MEM')))
        vm.mem_write(0x74000, resources['chara.fnt'])
        handles = {}
        events = []
        errors = []
        dta = 0x78000

        def read_name(v, pointer):
            return bytes(v.mem_read(pointer, 256)).split(b'\0', 1)[0].decode('ascii').replace('\\', '/').split('/')[-1].lower()

        def result(v, ax, failed=False):
            v.reg_write(UC_X86_REG_AX, ax)
            flags = v.reg_read(UC_X86_REG_EFLAGS)
            v.reg_write(UC_X86_REG_EFLAGS, (flags | 1) if failed else (flags & ~1))

        def interrupt(v, num, user):
            nonlocal dta
            assert num == 0x21
            ah = v.reg_read(UC_X86_REG_AX) >> 8
            ds, dx = v.reg_read(UC_X86_REG_DS), v.reg_read(UC_X86_REG_DX)
            if ah == 0x3d:
                name = read_name(v, ds*16+dx)
                events.append(['openAttempt', name])
                if name not in files: result(v, 2, True); return
                handle = len(handles)+5
                handles[handle] = dict(name=name, position=0, readBytes=0, readCalls=0)
                result(v, handle)
            elif ah == 0x3f:
                row = handles[v.reg_read(UC_X86_REG_BX)]
                count = v.reg_read(UC_X86_REG_CX)
                raw = files[row['name']][row['position']:row['position']+count]
                if raw: v.mem_write(ds*16+dx, raw)
                row['position'] += len(raw)
                row['readBytes'] += len(raw)
                row['readCalls'] += 1
                result(v, len(raw))
            elif ah == 0x3e:
                row = handles[v.reg_read(UC_X86_REG_BX)]
                events.append(['close', row['name'], row['readBytes'], row['readCalls']])
                result(v, 0)
            elif ah == 0x43:
                name = read_name(v, ds*16+dx)
                events.append(['attr', name])
                if name in files: v.reg_write(UC_X86_REG_CX, 0x20); result(v, 0)
                else: result(v, 2, True)
            elif ah == 0x19: result(v, 2)
            elif ah == 0x47: v.mem_write(ds*16+v.reg_read(UC_X86_REG_SI), b'\0'); result(v, 0)
            elif ah == 0x2f: v.reg_write(UC_X86_REG_ES, dta//16); v.reg_write(UC_X86_REG_BX, dta % 16)
            elif ah == 0x1a: dta = ds*16+dx
            else: raise AssertionError(hex(ah))

        def hook(v, address, size, user):
            if address == 0x2ea0f-header:
                bp = v.reg_read(UC_X86_REG_BP)
                need, off, seg = struct.unpack('<HHH', v.mem_read(0x60000+bp+6, 6))
                raw = bytes(v.mem_read(seg*16+off, 256))
                errors.append(dict(need=bool(need), name=raw[1:1+raw[0]].decode('ascii')))
                v.emu_stop()
            elif address == 0x30cd0+0x4df:
                sp = v.reg_read(UC_X86_REG_SP)
                ip, cs = struct.unpack('<HH', v.mem_read(0x60000+sp, 4))
                v.reg_write(UC_X86_REG_SP, sp+4)
                v.reg_write(UC_X86_REG_CS, cs)
                v.reg_write(UC_X86_REG_IP, ip)

        vm.hook_add(UC_HOOK_INTR, interrupt)
        vm.hook_add(UC_HOOK_CODE, hook)
        vm.emu_start(START-header, END-header, count=2000000)
        if not errors:
            assert vm.reg_read(UC_X86_REG_CS) == 0x2466
            assert 0x24660+vm.reg_read(UC_X86_REG_IP) == END-header
            assert vm.reg_read(UC_X86_REG_SP) == 0x7d00
        cases.append(dict(mapId=map_id, warm=warm, target=target, mode=mode,
            events=events, error=errors[0] if errors else None,
            afterLoadFont=vm.mem_read(0x539b8, 1)[0]))
    return dict(scope=__doc__, exeSha256=hashlib.sha256(exe).hexdigest(),
        fragment=dict(start=START, end=END, sha256=hashlib.sha256(exe[START:END]).hexdigest()),
        resources={p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(root.iterdir())
            if p.suffix.upper() in ['.FNT', '.MAP']}, cases=cases)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if args.check:
        data = json.loads(OUT.read_text())
        root = ROOT / 'repo_source/LORE_1993_runtime'
        exe = (root / 'LORE.EXE').read_bytes()
        assert data['scope'] == __doc__
        assert data['exeSha256'] == hashlib.sha256(exe).hexdigest()
        assert data['fragment'] == dict(start=START, end=END, sha256=hashlib.sha256(exe[START:END]).hexdigest())
        assert data['resources'] == {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(root.iterdir())
            if p.suffix.upper() in ['.FNT', '.MAP']}
        assert len(data['cases']) == 48
    else: OUT.write_text(json.dumps(build(), separators=(',', ':'))+'\n')


if __name__ == '__main__': main()

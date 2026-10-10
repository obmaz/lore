"""Original SpecialCastAttack through JoinEnemy with explicit surrounding memory.

The invalid template zero reads the record immediately before enemydata[1].
Synthetic surrounding bytes demonstrate undefined-data dependency, not actual
canonical adjacent memory. Original RNG and append/reuse order are executed.
UI calls are not executed; defined templates use original FOEDATA.DAT.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'test/fixtures/dos_summon_bounds.json'
SPANS = [('SpecialCastAttack', 0x24513, 0x24622),
         ('JoinEnemy', 0x2c847, 0x2c9ab), ('Random', 225719, 225865)]

def build():
    from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_CODE
    from unicorn.x86_const import (UC_X86_REG_CS, UC_X86_REG_DS, UC_X86_REG_SS,
        UC_X86_REG_BP, UC_X86_REG_SP, UC_X86_REG_IP)
    exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    db = (ROOT / 'repo_source/LORE_1993_runtime/FOEDATA.DAT').read_bytes()
    header = struct.unpack_from('<H', exe, 8)[0] * 16
    cases = []
    for count in [1, 2, 6, 7]:
      for seed in [4, 5, 6, 13]:
       for marker in ['FAKE', 'OTHER']:
        u = Uc(UC_ARCH_X86, UC_MODE_16)
        u.mem_map(0, 0x80000); u.mem_write(0, exe[header:])
        for reg, value in [(UC_X86_REG_CS, 0x1000), (UC_X86_REG_DS, 0x5000),
            (UC_X86_REG_SS, 0x6000), (UC_X86_REG_BP, 0x8000), (UC_X86_REG_SP, 0x7e00)]:
            u.reg_write(reg, value)
        u.mem_write(0x566b8, db)
        u.mem_write(0x5364c, struct.pack('<I', seed))
        u.mem_write(0x53d9e, struct.pack('<h', 1))
        u.mem_write(0x56f37, bytes([count]))
        before = []
        for slot in range(1, 8):
            e = bytearray(35)
            e[0] = 20 if slot == 1 else 30
            e[1:3] = bytes([1, 64 + slot])
            e[28] = 1 if slot == 1 else 0
            e[29] = 1; e[34] = int(slot != 1)
            u.mem_write(0x56f15 + 35 * slot, bytes(e)); before.append(list(e))
        synthetic = bytearray(29)
        raw = marker.encode('ascii')
        synthetic[:1+len(raw)] = bytes([len(raw)]) + raw
        synthetic[17:] = bytes(range(10, 22))
        u.mem_write(0x5669b, bytes(synthetic))
        bounds, call, pre = [], [], []
        def hook(v, a, size, user):
            offset = a + header
            if offset == 225719:
                sp = v.reg_read(UC_X86_REG_SP)
                bounds.append(struct.unpack('<H', v.mem_read(0x60000 + sp + 4, 2))[0])
            if offset == 0x245d8:
                sp = v.reg_read(UC_X86_REG_SP)
                template, target = struct.unpack('<HH', v.mem_read(0x60000 + sp, 4))
                call.extend([target & 255, template & 255])
                pre.extend(list(v.mem_read(0x56f15 + 35 * slot, 35)) for slot in range(1,8))
            if offset == 0x245dd: v.emu_stop()
        u.hook_add(UC_HOOK_CODE, hook)
        u.emu_start(0x24513 - header, 0x7ffff, count=10000)
        assert call and bounds == [3, 3, 4]
        assert call[0] == (count + 1 if count < 7 else 2)
        cases.append(dict(count=count, seed=seed, marker=marker, call=call,
            bounds=bounds, before=before, beforeRead=pre,
            after=[list(u.mem_read(0x56f15+35*slot,35)) for slot in range(1,8)],
            afterCount=u.mem_read(0x56f37,1)[0],
            afterSeed=struct.unpack('<I',u.mem_read(0x5364c,4))[0]))
    return dict(scope=__doc__, exeSha256=hashlib.sha256(exe).hexdigest(),
        databaseSha256=hashlib.sha256(db).hexdigest(),
        fragments=[dict(name=n,start=s,end=e,sha256=hashlib.sha256(exe[s:e]).hexdigest()) for n,s,e in SPANS], cases=cases)

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args()
    if args.check:
        data=json.loads(OUT.read_text())
        exe=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
        db=(ROOT/'repo_source/LORE_1993_runtime/FOEDATA.DAT').read_bytes()
        assert data['scope']==__doc__ and data['exeSha256']==hashlib.sha256(exe).hexdigest()
        assert data['databaseSha256']==hashlib.sha256(db).hexdigest()
        assert data['fragments']==[dict(name=n,start=s,end=e,sha256=hashlib.sha256(exe[s:e]).hexdigest()) for n,s,e in SPANS]
        assert len(data['cases'])==32
    else: OUT.write_text(json.dumps(build(),separators=(',',':'))+'\n')

if __name__=='__main__':main()

"""Original six-slot DetectGameOver loop and original Exist predicate.

Only prologue stack-space check and GameOver UI are intercepted. The etc[6]
store is executed before the UI callback. Synthetic seventh slot is active
throughout and must never prevent a six-slot wipeout.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'test/fixtures/dos_detect_game_over.json'
START,END=0x2a5a8,0x2a5da
SPANS=[('DetectGameOver',START,END),('Exist',0x29cf8,0x29d41)]

def build():
    from unicorn import Uc,UC_ARCH_X86,UC_MODE_16,UC_HOOK_CODE
    from unicorn.x86_const import (UC_X86_REG_CS,UC_X86_REG_DS,UC_X86_REG_SS,
        UC_X86_REG_BP,UC_X86_REG_SP,UC_X86_REG_IP)
    exe=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    header=struct.unpack_from('<H',exe,8)[0]*16
    vm=Uc(UC_ARCH_X86,UC_MODE_16);vm.mem_map(0,0x80000);vm.mem_write(0,exe[header:])
    calls=[]
    def hook(v,address,size,user):
        if address not in [0x30cd0+0x4df,0x2a1eb-header]:return
        sp=v.reg_read(UC_X86_REG_SP);ip,cs=struct.unpack('<HH',v.mem_read(0x60000+sp,4))
        if address==0x2a1eb-header:
            assert v.mem_read(0x564d7,1)[0]==255;calls.append(255)
        v.reg_write(UC_X86_REG_SP,sp+4);v.reg_write(UC_X86_REG_CS,cs);v.reg_write(UC_X86_REG_IP,ip)
    vm.hook_add(UC_HOOK_CODE,hook)
    def run(records,etc6):
        calls.clear()
        for reg,value in [(UC_X86_REG_CS,0x2466),(UC_X86_REG_DS,0x5000),
            (UC_X86_REG_SS,0x6000),(UC_X86_REG_BP,0x8000),(UC_X86_REG_SP,0x7e00)]:vm.reg_write(reg,value)
        all_records=records+[dict(name='Seventh',hp=1,unconscious=0,dead=0)]
        raw=bytearray()
        for r in all_records:
            p=bytearray(55);name=r['name'].encode('ascii');p[:len(name)+1]=bytes([len(name)])+name
            struct.pack_into('<hhh',p,31,r['unconscious'],r['dead'],r['hp']);raw.extend(p)
        vm.mem_write(0x56536,bytes(raw));vm.mem_write(0x564d7,bytes([etc6]))
        vm.emu_start(START-header,END-header,count=10000)
        assert vm.reg_read(UC_X86_REG_CS)==0x2466 and 0x24660+vm.reg_read(UC_X86_REG_IP)==END-header
        assert bytes(vm.mem_read(0x56536,len(raw)))==bytes(raw)
        return dict(records=records,etc6=etc6,afterEtc6=vm.mem_read(0x564d7,1)[0],calls=list(calls))
    blank=dict(name='',hp=0,unconscious=0,dead=0)
    masks=[]
    for mask in range(64):
     for etc6 in [0,17,255]:
        records=[dict(name='P',hp=int(bool(mask&(1<<i))),unconscious=0,dead=0) for i in range(6)]
        masks.append(dict(mask=mask,**run(records,etc6)))
    predicates=[]
    for name in ['', 'Hero']:
     for hp in [-32768,-1,0,1,32767]:
      for unconscious in [-32768,-1,0,1,32767]:
       for dead in [-32768,-1,0,1,32767]:
        for slot in range(6):
            records=[dict(blank) for _ in range(6)]
            records[slot]=dict(name=name,hp=hp,unconscious=unconscious,dead=dead)
            predicates.append(dict(slot=slot+1,**run(records,17)))
    return dict(scope=__doc__,exeSha256=hashlib.sha256(exe).hexdigest(),
        fragments=[dict(name=n,start=s,end=e,sha256=hashlib.sha256(exe[s:e]).hexdigest()) for n,s,e in SPANS], masks=masks,predicates=predicates)

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args()
    if args.check:
        data=json.loads(OUT.read_text());exe=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
        assert data['scope']==__doc__ and data['exeSha256']==hashlib.sha256(exe).hexdigest()
        assert data['fragments']==[dict(name=n,start=s,end=e,sha256=hashlib.sha256(exe[s:e]).hexdigest()) for n,s,e in SPANS]
        assert len(data['masks'])==192 and len(data['predicates'])==1500
    else:OUT.write_text(json.dumps(build(),separators=(',',':'))+'\n')
if __name__=='__main__':main()

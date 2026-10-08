"""Original Load's default/saved map reads with original typed Read/IOCheck.

An opened byte file descriptor and DOS int21/AH3F data are supplied. Original
header reads, bounds, indices, fixed Pascal map[x,y] stride and memory copies
execute. Reset/Close and filesystem errors are outside this scope. Invalid
dimensions demonstrate empty loops or out-of-array writes; the port's explicit
FormatException policy is not invalid-map byte equivalence.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'test/fixtures/dos_map_reads.json'
SPANS=[('defaultMap',0x2f0d4,0x2f157),('savedMap',0x2f1d6,0x2f268),
       ('ReadTyped',0x374ad,0x374f2)]
DIMENSIONS=[(1,1),(2,3),(3,2),(9,9),(100,1),(1,100),(100,100),
            (0,0),(0,1),(1,0),(101,1),(1,101)]

def build():
    from unicorn import Uc,UC_ARCH_X86,UC_MODE_16,UC_HOOK_INTR
    from unicorn.x86_const import (UC_X86_REG_CS,UC_X86_REG_DS,UC_X86_REG_SS,
        UC_X86_REG_BP,UC_X86_REG_SP,UC_X86_REG_IP,UC_X86_REG_AX,UC_X86_REG_BX,
        UC_X86_REG_CX,UC_X86_REG_DX,UC_X86_REG_EFLAGS)
    exe=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    header=struct.unpack_from('<H',exe,8)[0]*16
    files=[(p.stem,p.read_bytes()) for p in sorted((ROOT/'repo_source/LORE_1993_runtime').glob('*.MAP'))]
    assert len(files)==25
    files += [(f'synthetic-{w}x{h}',bytes([w,h])+bytes((i*37+13)%256 for i in range(w*h))) for w,h in DIMENSIONS]
    cases=[]
    for name,payload in files:
     for branch,start,end in SPANS[:2]:
        vm=Uc(UC_ARCH_X86,UC_MODE_16);vm.mem_map(0,0x80000);vm.mem_write(0,exe[header:])
        for reg,value in [(UC_X86_REG_CS,0x2466),(UC_X86_REG_DS,0x5000),
            (UC_X86_REG_SS,0x6000),(UC_X86_REG_BP,0x8000),(UC_X86_REG_SP,0x7e00)]:vm.reg_write(reg,value)
        vm.mem_write(0x53b16,struct.pack('<HHH',7,0xd7b3,1))
        vm.mem_write(0x5365e,struct.pack('<hh',-12345,-23456))
        vm.mem_write(0x53da8,b'\xa5'*10000)
        guard=b'\xa5'*16
        vm.mem_write(0x53d98,guard);vm.mem_write(0x564b8,guard)
        position=0;trace=hashlib.sha256();targets=[]
        def interrupt(v,num,user):
            nonlocal position
            assert num==0x21 and v.reg_read(UC_X86_REG_AX)>>8==0x3f
            assert v.reg_read(UC_X86_REG_CX)==1 and v.reg_read(UC_X86_REG_BX)==7
            target=v.reg_read(UC_X86_REG_DS)*16+v.reg_read(UC_X86_REG_DX)
            expected=0x53d96+position if position<2 else 0x53d43+((position-2)%payload[0]+1)*100+((position-2)//payload[0]+1)
            assert target==expected and position<len(payload)
            value=payload[position];v.mem_write(target,bytes([value]))
            trace.update(struct.pack('<IIB',position,target,value));targets.append(target);position+=1
            v.reg_write(UC_X86_REG_AX,1);v.reg_write(UC_X86_REG_EFLAGS,v.reg_read(UC_X86_REG_EFLAGS)&~1)
        vm.hook_add(UC_HOOK_INTR,interrupt)
        vm.emu_start(start-header,end-header,count=2000000)
        assert vm.reg_read(UC_X86_REG_CS)==0x2466 and 0x24660+vm.reg_read(UC_X86_REG_IP)==end-header
        assert vm.reg_read(UC_X86_REG_SP)==0x7e00 and position==len(payload)
        w,h=payload[:2];valid=1<=w<=100 and 1<=h<=100
        output=bytes(vm.mem_read(0x53d43+x*100+y,1)[0] for y in range(1,h+1) for x in range(1,w+1))
        assert output==payload[2:]
        assert bytes(vm.mem_read(0x53d98,16))==guard
        changed_after=bytes(vm.mem_read(0x564b8,16))!=guard
        if valid:assert not changed_after
        cases.append(dict(name=name,branch=branch,width=w,height=h,valid=valid,
            fileSha256=hashlib.sha256(payload).hexdigest(),payloadHex=payload.hex(),
            nativeTilesHex=output.hex(),readCount=position,traceSha256=trace.hexdigest(),
            firstTargets=targets[:3],lastTarget=targets[-1],
            afterGuardChanged=changed_after,
            finalIndices=list(struct.unpack('<hh',vm.mem_read(0x5365e,4)))))
    return dict(scope=__doc__,exeSha256=hashlib.sha256(exe).hexdigest(),
        fragments=[dict(name=n,start=s,end=e,sha256=hashlib.sha256(exe[s:e]).hexdigest()) for n,s,e in SPANS],cases=cases)

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args()
    if args.check:
        data=json.loads(OUT.read_text());exe=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
        assert data['scope']==__doc__ and data['exeSha256']==hashlib.sha256(exe).hexdigest()
        assert data['fragments']==[dict(name=n,start=s,end=e,sha256=hashlib.sha256(exe[s:e]).hexdigest()) for n,s,e in SPANS]
        assert len(data['cases'])==74
        for row in data['cases']:
            payload=bytes.fromhex(row['payloadHex'])
            assert row['fileSha256']==hashlib.sha256(payload).hexdigest()
            if not row['name'].startswith('synthetic-'):
                assert payload==(ROOT/'repo_source/LORE_1993_runtime'/f"{row['name']}.MAP").read_bytes()
    else:OUT.write_text(json.dumps(build(),separators=(',',':'))+'\n')
if __name__=='__main__':main()

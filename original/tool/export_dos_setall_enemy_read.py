"""Original Set_All's 75 typed enemy reads, including original Read/IOCheck.

The opened typed-file descriptor is supplied and DOS int21/AH3F reads are the
platform boundary. Original array address, loop, record-size/error checks and
all memory copies execute. Reset/Close, file errors and Set_All pixels are not
claimed. Sentinel bytes before/after the 75-record table must remain unchanged.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'test/fixtures/dos_setall_enemy_read.json'
START,END=0x2f785,0x2f7b5
SPANS=[('SetAllRead',START,END),('ReadTyped',0x374ad,0x374f2)]

def build():
    from unicorn import Uc,UC_ARCH_X86,UC_MODE_16,UC_HOOK_INTR
    from unicorn.x86_const import (UC_X86_REG_CS,UC_X86_REG_DS,UC_X86_REG_SS,
        UC_X86_REG_BP,UC_X86_REG_SP,UC_X86_REG_IP,UC_X86_REG_AX,UC_X86_REG_BX,
        UC_X86_REG_CX,UC_X86_REG_DX,UC_X86_REG_EFLAGS)
    exe=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    data=(ROOT/'repo_source/LORE_1993_runtime/FOEDATA.DAT').read_bytes()
    header=struct.unpack_from('<H',exe,8)[0]*16
    vm=Uc(UC_ARCH_X86,UC_MODE_16);vm.mem_map(0,0x80000);vm.mem_write(0,exe[header:])
    for reg,value in [(UC_X86_REG_CS,0x2466),(UC_X86_REG_DS,0x5000),
        (UC_X86_REG_SS,0x6000),(UC_X86_REG_BP,0x8000),(UC_X86_REG_SP,0x7e00)]:vm.reg_write(reg,value)
    vm.mem_write(0x53d16,struct.pack('<HHH',7,0xd7b3,29))
    before=bytes(range(29));after=bytes(range(30,59))
    vm.mem_write(0x5669b,before);vm.mem_write(0x566b8+len(data),after)
    reads=[];position=0
    def interrupt(v,num,user):
        nonlocal position
        assert num==0x21 and v.reg_read(UC_X86_REG_AX)>>8==0x3f
        count=v.reg_read(UC_X86_REG_CX)
        target=v.reg_read(UC_X86_REG_DS)*16+v.reg_read(UC_X86_REG_DX)
        assert v.reg_read(UC_X86_REG_BX)==7 and count==29
        assert target==0x566b8+position and position+count<=len(data)
        reads.append(dict(index=position//29+1,target=target,length=count,fileOffset=position))
        v.mem_write(target,data[position:position+count]);position+=count
        v.reg_write(UC_X86_REG_AX,count);v.reg_write(UC_X86_REG_EFLAGS,v.reg_read(UC_X86_REG_EFLAGS)&~1)
    vm.hook_add(UC_HOOK_INTR,interrupt)
    vm.emu_start(START-header,END-header,count=100000)
    assert vm.reg_read(UC_X86_REG_CS)==0x2466 and 0x24660+vm.reg_read(UC_X86_REG_IP)==END-header
    assert vm.reg_read(UC_X86_REG_SP)==0x7e00
    assert len(reads)==75 and position==len(data)==2175
    assert bytes(vm.mem_read(0x566b8,len(data)))==data
    assert bytes(vm.mem_read(0x5669b,29))==before and bytes(vm.mem_read(0x566b8+len(data),29))==after
    assert struct.unpack('<h',vm.mem_read(0x5365e,2))[0]==75
    assert struct.unpack('<H',vm.mem_read(0x5364a,2))[0]==0
    return dict(scope=__doc__,exeSha256=hashlib.sha256(exe).hexdigest(),
        databaseSha256=hashlib.sha256(data).hexdigest(),
        fragments=[dict(name=n,start=s,end=e,sha256=hashlib.sha256(exe[s:e]).hexdigest()) for n,s,e in SPANS],
        reads=reads,records=[list(vm.mem_read(0x566b8+i*29,29)) for i in range(75)],
        finalIndex=75,ioResult=0,beforeSentinel=list(before),afterSentinel=list(after))

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args()
    if args.check:
        data=json.loads(OUT.read_text());exe=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
        db=(ROOT/'repo_source/LORE_1993_runtime/FOEDATA.DAT').read_bytes()
        assert data['scope']==__doc__ and data['exeSha256']==hashlib.sha256(exe).hexdigest()
        assert data['databaseSha256']==hashlib.sha256(db).hexdigest()
        assert data['fragments']==[dict(name=n,start=s,end=e,sha256=hashlib.sha256(exe[s:e]).hexdigest()) for n,s,e in SPANS]
        assert len(data['reads'])==len(data['records'])==75
    else:OUT.write_text(json.dumps(build(),separators=(',',':'))+'\n')
if __name__=='__main__':main()

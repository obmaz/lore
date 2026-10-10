"""Original Save/Load player[1..6] record transfer loops, excluding scratch 7.

Typed I/O is supplied at original call sites; all original loop, pointer and
array-index instructions run unchanged. No DOS file/error/startup parity.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path
from check_dos_new_game import records

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'test/fixtures/dos_save_party.json'
SPANS = [('save',0x2f5bb,0x2f5eb),('load',0x2ece7,0x2ed12)]

def build():
    from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_CODE
    from unicorn.x86_const import UC_X86_REG_CS, UC_X86_REG_DS, UC_X86_REG_SS, UC_X86_REG_BP, UC_X86_REG_SP, UC_X86_REG_IP, UC_X86_REG_DI
    exe=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    header=struct.unpack_from('<H',exe,8)[0]*16
    vm=Uc(UC_ARCH_X86,UC_MODE_16)
    vm.mem_map(0,0x80000)
    vm.mem_write(0,exe[header:])
    state={}
    def hook(u,address,size,_):
        offset=address+header
        if offset in [0x2f5d7,0x2ed03]:
            pointer=0x50000+u.reg_read(UC_X86_REG_DI)
            state['pointers'].append(pointer)
            if offset==0x2f5d7:
                state['records'].append(bytes(u.mem_read(pointer,55)))
            else:
                u.mem_write(pointer,state['records'][len(state['pointers'])-1])
            # Runtime RETF pops four argument bytes; caller pops four more.
            u.reg_write(UC_X86_REG_SP,u.reg_read(UC_X86_REG_SP)+4)
            u.reg_write(UC_X86_REG_IP,offset+5-header)
        elif offset==0x2f5df: # successful typed Write error check
            u.reg_write(UC_X86_REG_IP,0x2f5e4-header)
    vm.hook_add(UC_HOOK_CODE,hook)
    def run(name,initial,inputs=None):
        for reg,value in [(UC_X86_REG_CS,0x2000),(UC_X86_REG_DS,0x5000),(UC_X86_REG_SS,0x6000),(UC_X86_REG_BP,0x8000),(UC_X86_REG_SP,0x7e00)]:
            vm.reg_write(reg,value)
        vm.mem_write(0x56536,b''.join(initial))
        state.clear()
        state.update(records=[] if inputs is None else inputs,pointers=[])
        _,a,z=next(span for span in SPANS if span[0]==name)
        vm.emu_start(a-header,z-header,count=1000)
        assert 0x20000+vm.reg_read(UC_X86_REG_IP)==z-header
        assert state['pointers']==[0x56536+i*55 for i in range(6)]
        return list(state['records']),bytes(vm.mem_read(0x56536,7*55))
    values=[0,1,127,128,254,255]
    signed=[-32768,-32767,-1,0,32766,32767]
    xp=[-2147483648,-1,0,1,2147483646,2147483647]
    cases=[]
    def decode7(rows):
        return records(b''.join(rows[:6]))+[records(rows[6]+bytes(5*55))[0]]
    for mask in range(64):
        for shift in range(6):
            initial=[]
            for slot in range(7):
                r=bytearray(55)
                name=f'Slot{slot+1}'.encode() if slot==6 or mask & (1<<slot) else b''
                r[:1+len(name)]=bytes([len(name)])+name
                r[18]=slot%2
                r[19]=[0,1,2,7,9,10][(slot+shift)%6]
                for index in list(range(20,31))+list(range(41,45))+list(range(49,55)):
                    r[index]=values[(slot+shift+index)%6]
                for index in range(5):
                    struct.pack_into('<h',r,31+index*2,signed[(slot+shift+index)%6])
                struct.pack_into('<i',r,45,xp[(slot+shift)%6])
                initial.append(bytes(r))
            saved,after_save=run('save',initial)
            assert saved==initial[:6] and after_save==b''.join(initial)
            scratch=bytes([255])*55
            _,loaded=run('load',[bytes(55)]*6+[scratch],saved)
            assert loaded[:6*55]==b''.join(saved) and loaded[6*55:]==scratch
            cases.append(dict(mask=mask,shift=shift,inputs=decode7(initial),saved=records(b''.join(saved)),loadScratchUnchanged=True))
    return dict(scope=__doc__,exeSha256=hashlib.sha256(exe).hexdigest(),fragments=[dict(name=n,start=a,end=z,sha256=hashlib.sha256(exe[a:z]).hexdigest()) for n,a,z in SPANS],cases=cases)

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--check',action='store_true')
    args=parser.parse_args()
    if args.check:
        data=json.loads(OUT.read_text())
        exe=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
        assert data['scope']==__doc__ and data['exeSha256']==hashlib.sha256(exe).hexdigest()
        assert data['fragments']==[dict(name=n,start=a,end=z,sha256=hashlib.sha256(exe[a:z]).hexdigest()) for n,a,z in SPANS]
        assert len(data['cases'])==384
    else:
        OUT.write_text(json.dumps(build(),separators=(',',':'))+'\n')

if __name__=='__main__':
    main()

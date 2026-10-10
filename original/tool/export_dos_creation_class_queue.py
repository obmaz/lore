"""Original Third KeyPressed/ReadKey queue drain and class selection.

Queued bytes are supplied to original call sites. No CRT polling duration,
palette frames, sound or platform event-to-frame grouping is claimed.
"""
import argparse
import hashlib
import itertools
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'test/fixtures/dos_creation_class_queue.json'
START, END = 0xa971, 0xa9d2

def build():
    from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_CODE
    from unicorn.x86_const import UC_X86_REG_CS, UC_X86_REG_DS, UC_X86_REG_SS, UC_X86_REG_BP, UC_X86_REG_SP, UC_X86_REG_IP, UC_X86_REG_AX
    exe = (ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    header = struct.unpack_from('<H',exe,8)[0]*16
    vm = Uc(UC_ARCH_X86,UC_MODE_16)
    vm.mem_map(0,0x80000)
    vm.mem_write(0,exe[header:])
    state = {}
    def hook(u,address,size,_):
        offset = address+header
        if offset == 0xa971:
            u.reg_write(UC_X86_REG_AX, int(state['read'] < len(state['keys'])))
            u.reg_write(UC_X86_REG_IP,0xa976-header)
        elif offset == 0xa97a:
            u.reg_write(UC_X86_REG_AX,state['keys'][state['read']])
            state['read'] += 1
            u.reg_write(UC_X86_REG_IP,0xa97f-header)
        elif offset == 0xa9b5:
            u.reg_write(UC_X86_REG_IP,0xa9c8-header)
        elif offset in [0xa91e,END]:
            state['complete'] = offset == END
            u.emu_stop()
    vm.hook_add(UC_HOOK_CODE,hook)
    def run(keys,mask):
        for reg,value in [(UC_X86_REG_CS,0),(UC_X86_REG_DS,0x5000),(UC_X86_REG_SS,0x6000),(UC_X86_REG_BP,0x8000),(UC_X86_REG_SP,0x7e00)]:
            vm.reg_write(reg,value)
        vm.mem_write(0x53654,bytes([*(int(mask & (1<<i) != 0) for i in range(7)),1]))
        vm.mem_write(0x56549,b'\xff')
        vm.mem_write(0x539b4,b'\x00')
        state.clear()
        state.update(keys=keys,read=0)
        vm.emu_start(START-header,0x7ffff,count=1000)
        assert state['read'] == len(keys) and 'complete' in state
        return [vm.mem_read(0x56549,1)[0] if state['complete'] else None,state['read']]
    cases = [[key,mask,*run([50,key],mask)] for key,mask in itertools.product(range(256),range(128))]
    mixed = []
    for key,mask in itertools.product(range(256),[0,127]):
        for keys in [[key,0,72,50,56],[key,50,0,75],[key,56,27]]:
            mixed.append([keys,mask,*run(keys,mask)])
    return dict(scope=__doc__,exeSha256=hashlib.sha256(exe).hexdigest(),fragment=dict(start=START,end=END,sha256=hashlib.sha256(exe[START:END]).hexdigest()),cases=cases,mixed=mixed)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check',action='store_true')
    args = parser.parse_args()
    if args.check:
        data=json.loads(OUT.read_text())
        exe=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
        assert data['scope']==__doc__ and data['exeSha256']==hashlib.sha256(exe).hexdigest()
        assert data['fragment']==dict(start=START,end=END,sha256=hashlib.sha256(exe[START:END]).hexdigest())
        assert len(data['cases'])==32768 and len(data['mixed'])==1536
    else:
        OUT.write_text(json.dumps(build(),separators=(',',':'))+'\n')

if __name__=='__main__':
    main()

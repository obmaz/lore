"""Original LORESUB.join full 55-byte stores at all level/cast byte bounds.
Synthetic destination/template records; no original UI or DOS startup claimed.
"""
import argparse, hashlib, json, struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'test/fixtures/dos_join_bounds.json'
START,END=0x2c4c4,0x2c843

def build():
    from unicorn import Uc,UC_ARCH_X86,UC_MODE_16
    from unicorn.x86_const import UC_X86_REG_CS,UC_X86_REG_DS,UC_X86_REG_SS,UC_X86_REG_BP,UC_X86_REG_SP,UC_X86_REG_IP
    exe=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes();header=struct.unpack_from('<H',exe,8)[0]*16
    vm=Uc(UC_ARCH_X86,UC_MODE_16);vm.mem_map(0,0x80000);vm.mem_write(0,exe[header:]);rows=[]
    inputs={(level,cast,previous) for level in range(256) for cast in [0,1,85,86,255] for previous in [-2147483648,-1,0,2147483647]}
    inputs|={(level,cast,123456) for level in [0,1,20,30,31,255] for cast in range(256)}
    for level,cast,previous in sorted(inputs):
        for r,v in [(UC_X86_REG_CS,0x2000),(UC_X86_REG_DS,0x5000),(UC_X86_REG_SS,0x6000),(UC_X86_REG_BP,0x8000),(UC_X86_REG_SP,0x7f00)]:vm.reg_write(r,v)
        vm.mem_write(0x67ffc,struct.pack('<HH',0x100,0x5000));vm.mem_write(0x68008,b'\x01')
        template=bytearray(29);template[:9]=b'\x08Template';template[17:]=bytes([30,255,255,255,18,19,20,7,2,cast,1,level])
        vm.mem_write(0x566b8,bytes(template));player=bytearray(55);struct.pack_into('<i',player,45,previous);vm.mem_write(0x50100,bytes(player))
        vm.emu_start(START-header,END-header,count=10000)
        assert 0x20000+vm.reg_read(UC_X86_REG_IP)==END-header
        rows.append(dict(level=level,cast=cast,previousExperience=previous,record=list(vm.mem_read(0x50100,55))))
    return dict(scope=__doc__,exeSha256=hashlib.sha256(exe).hexdigest(),fragment=dict(start=START,end=END,sha256=hashlib.sha256(exe[START:END]).hexdigest()),cases=rows)
def main():
    p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');args=p.parse_args()
    if args.check:
        data=json.loads(OUT.read_text());exe=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
        assert data['exeSha256']==hashlib.sha256(exe).hexdigest()
        assert data['fragment']==dict(start=START,end=END,sha256=hashlib.sha256(exe[START:END]).hexdigest())
        assert len(data['cases'])==6656
    else:OUT.write_text(json.dumps(build(),separators=(',',':'))+'\n')
if __name__=='__main__':main()

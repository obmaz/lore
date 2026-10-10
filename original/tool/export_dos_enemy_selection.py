"""SelectEnemy cursor and colour instructions; BGI is bypassed before pushes.
All input bytes/scans at every cursor/count, signed HP words and status masks.
"""
import argparse, hashlib, json, struct
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'test/fixtures/dos_enemy_selection.json'
SPANS = [(0x2a5f4, 0x2a67e), (0x2a6df, 0x2a79b)]

def build():
    from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_CODE
    from unicorn.x86_const import UC_X86_REG_CS, UC_X86_REG_DS, UC_X86_REG_SS, UC_X86_REG_SP, UC_X86_REG_BP, UC_X86_REG_IP, UC_X86_REG_AX
    exe = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    header = struct.unpack_from('<H', exe, 8)[0] * 16
    vm = Uc(UC_ARCH_X86, UC_MODE_16); vm.mem_map(0, 0x80000); vm.mem_write(0, exe[header:])
    context = {}
    def jump(address): vm.reg_write(UC_X86_REG_IP, address - header - 0x20000)
    def hook(u, a, size, _):
        a += header
        if a == 0x2a6e6:
            u.reg_write(UC_X86_REG_AX, context['scan']); jump(0x2a6eb)
        elif a == 0x2a728: jump(0x2a76b)
        elif a == 0x2a791: u.emu_stop()
    vm.hook_add(UC_HOOK_CODE, hook)
    def setup(number=1):
        for r,v in [(UC_X86_REG_CS,0x2000),(UC_X86_REG_DS,0x5000),(UC_X86_REG_SS,0x6000),(UC_X86_REG_SP,0x7f00),(UC_X86_REG_BP,0x8000)]: vm.reg_write(r,v)
        vm.mem_write(0x67ffc, struct.pack('<h', number))
    keys = []
    for count in range(1,8):
        vm.mem_write(0x56f37, bytes([count]))
        for number in range(1,count+1):
            for extended in [False,True]:
                for value in range(256):
                    setup(number); context['scan'] = value if extended else 0
                    vm.mem_write(0x5366a, bytes([0 if extended else value]))
                    vm.mem_write(0x539b4, b'\x00'); vm.mem_write(0x67ff8,b'\x00\x00\x00')
                    vm.emu_start(0x2a6df-header, 0x2a79b-header, count=1000)
                    assert 0x20000+vm.reg_read(UC_X86_REG_IP)==0x2a791-header
                    keys.append(dict(count=count,number=number,key=0 if extended else value,scan=context['scan'],after=struct.unpack('<h',vm.mem_read(0x67ffc,2))[0],accepted=bool(vm.mem_read(0x539b4,1)[0])))
    colours=[]
    for hp in range(-32768,32768):
        setup(); record=bytearray(35); struct.pack_into('<h',record,30,hp)
        vm.mem_write(0x56f38,bytes(record)); vm.emu_start(0x2a5f4-header,0x2a67e-header,count=100)
        colours.append(struct.unpack('<h',vm.mem_read(0x67ffa,2))[0])
    # All independent boolean fields; only dead affects SelectEnemy colour.
    states=[]
    for hp in [-32768,-1,0,1,19,20,49,50,99,100,199,200,299,300,32767]:
        for flags in range(8):
            setup(); record=bytearray(35);struct.pack_into('<h',record,30,hp);record[32:35]=bytes([(flags>>i)&1 for i in range(3)])
            vm.mem_write(0x56f38,bytes(record));vm.emu_start(0x2a5f4-header,0x2a67e-header,count=100)
            color=struct.unpack('<h',vm.mem_read(0x67ffa,2))[0]
            states.append(dict(hp=hp,flags=flags,color=color,highlight=7 if color==0 else color))
    return dict(scope=__doc__,exeSha256=hashlib.sha256(exe).hexdigest(),fragments=[dict(start=a,end=b,sha256=hashlib.sha256(exe[a:b]).hexdigest()) for a,b in SPANS],keys=keys,colours=colours,states=states)

def main():
    p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');args=p.parse_args()
    if args.check:
        data=json.loads(OUT.read_text());exe=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
        assert data['exeSha256']==hashlib.sha256(exe).hexdigest()
        assert data['fragments']==[dict(start=a,end=b,sha256=hashlib.sha256(exe[a:b]).hexdigest()) for a,b in SPANS]
        assert len(data['keys'])==14336 and len(data['colours'])==65536
    else: OUT.write_text(json.dumps(build(),separators=(',',':'))+'\n')
if __name__=='__main__': main()

"""Original BattleMode manual command stores; SelectEnemy and Clear are stubs.
Numeric input fixtures include synthetic out-of-menu results, not ReturnMagic UI.
"""
import argparse, hashlib, json, struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'test/fixtures/dos_battle_commands.json'
STARTS={1:0x24e98,2:0x24f87,3:0x25099,4:0x2519e,6:0x2524e}
END=0x252bf

def build():
    from unicorn import Uc,UC_ARCH_X86,UC_MODE_16,UC_HOOK_CODE
    from unicorn.x86_const import UC_X86_REG_CS,UC_X86_REG_DS,UC_X86_REG_SS,UC_X86_REG_SP,UC_X86_REG_BP,UC_X86_REG_IP,UC_X86_REG_AX
    exe=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes();header=struct.unpack_from('<H',exe,8)[0]*16
    vm=Uc(UC_ARCH_X86,UC_MODE_16);vm.mem_map(0,0x80000);vm.mem_write(0,exe[header:]);ctx={}
    def hook(u,a,size,_):
        a+=header
        if a in {0x24fa9,0x251c0,0x25269}:
            ctx['asked']=True;u.reg_write(UC_X86_REG_AX,ctx['target']);u.reg_write(UC_X86_REG_IP,a+5-header-0x10000)
        elif a in {0x24fb1,0x251c8,0x25271}:
            u.reg_write(UC_X86_REG_IP,a+5-header-0x10000)
    vm.hook_add(UC_HOOK_CODE,hook)
    def run(how,level,k,target,flags,weapon=0,maxsum=5):
        person=(level%6)+1
        for r,v in [(UC_X86_REG_CS,0x1000),(UC_X86_REG_DS,0x5000),(UC_X86_REG_SS,0x6000),(UC_X86_REG_BP,0x8000),(UC_X86_REG_SP,0x7f00),(UC_X86_REG_AX,k)]:vm.reg_write(r,v)
        vm.mem_write(0x53d9e,struct.pack('<h',person))
        vm.mem_write(0x53660,struct.pack('<h',target if how==1 else maxsum))
        vm.mem_write(0x56530+55*person,bytes([weapon]))
        for n in range(1,8):
            rec=bytearray(35);rec[33:35]=bytes([flags&1,(flags>>1)&1]);vm.mem_write(0x56f15+35*n,bytes(rec))
        address=0x564b5+3*person;vm.mem_write(address,bytes([how,99,88]));ctx.update(target=target,asked=False)
        vm.emu_start(STARTS[how]-header,END-header,count=1000)
        assert 0x10000+vm.reg_read(UC_X86_REG_IP)==END-header
        return dict(how=how,level=level,k=k,target=target,flags=flags,weapon=weapon,maxsum=maxsum,person=person,command=list(vm.mem_read(address,3)),asked=ctx['asked'])
    menus=json.loads((ROOT/'test/fixtures/dos_battle_menus.json').read_text())['cases']
    rows=[]
    for m in menus:
        for k in range(8):
            for target in [1,7]:
                for flags in range(4):rows.append(run(m['how'],m['level'],k,target,flags,maxsum=m['maxsum']))
    for k in range(256):
        for target in range(1,8):
            for flags in range(4):rows.append(run(6,1,k,target,flags))
    for weapon in range(256):
        for target in range(8):rows.append(run(1,weapon,0,target,0,weapon=weapon))
    return dict(scope=__doc__,exeSha256=hashlib.sha256(exe).hexdigest(),fragments=[dict(how=h,start=a,end=END,sha256=hashlib.sha256(exe[a:END]).hexdigest()) for h,a in STARTS.items()],cases=rows)
def main():
    p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');args=p.parse_args()
    if args.check:
        data=json.loads(OUT.read_text());exe=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
        assert data['exeSha256']==hashlib.sha256(exe).hexdigest()
        assert data['fragments']==[dict(how=h,start=a,end=END,sha256=hashlib.sha256(exe[a:END]).hexdigest()) for h,a in STARTS.items()]
        assert len(data['cases'])==58368
    else:OUT.write_text(json.dumps(build(),separators=(',',':'))+'\n')
if __name__=='__main__':main()

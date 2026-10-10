#!/usr/bin/env python3
"""Execute shipped WeaponAttack damage/defence and actual target word stores.
Unicorn is needed to generate; --check verifies immutable original EXE fragments.
Target selection/RNG results are synthetic, not a full DOS RNG/battle replay.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUTPUT=ROOT/'test/fixtures/dos_weapon_arithmetic.json'
FRAGMENTS=[('attack',0x22c57,0x22c7c),('defence',0x22d26,0x22d5b),('stores',0x22dd2,0x22e37)]


def build():
    from unicorn import Uc,UC_ARCH_X86,UC_MODE_16
    from unicorn.x86_const import (UC_X86_REG_AX,UC_X86_REG_CS,UC_X86_REG_DS,
        UC_X86_REG_SS,UC_X86_REG_SP,UC_X86_REG_BP,UC_X86_REG_IP)
    exe=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    header=struct.unpack_from('<H',exe,8)[0]*16
    cases=[]
    scenarios=[('active-zero',0,1,0,30000,0,0),
               ('active-wrap-zero',128,128,3,30000,0,0),
               ('active-wrap-small',255,26,9,30000,0,0),
               ('active-large',255,255,9,30000,0,0),
               ('dead-store',0,1,0,0,32760,0),
               ('unconscious-store',0,1,0,0,0,32760)]
    for strength,level in [(20,20),(255,255),(255,128),(128,128),(20,200),(1,1)]:
        for attack_roll in [0,3,9]:
            for name,ac,player_level,defence_roll,hp,dead,unconscious in scenarios:
                vm=Uc(UC_ARCH_X86,UC_MODE_16);vm.mem_map(0,0x80000);vm.mem_write(0,exe[header:])
                for r,v in [(UC_X86_REG_CS,0x1000),(UC_X86_REG_DS,0x5000),(UC_X86_REG_SS,0x6000),
                            (UC_X86_REG_SP,0xff00),(UC_X86_REG_BP,0x8000),(UC_X86_REG_AX,attack_roll)]:vm.reg_write(r,v)
                vm.mem_write(0x67ff4,struct.pack('<HH',0x100,0x5000))
                enemy=bytearray(35);enemy[18],enemy[29]=strength,level;vm.mem_write(0x50100,bytes(enemy))
                vm.mem_write(0x67ffc,struct.pack('<h',1)) # local selected party index
                player=bytearray(55);player[41],player[44]=player_level,ac
                struct.pack_into('<hhh',player,31,unconscious,dead,hp)
                vm.mem_write(0x56536,bytes(player)) # player[1] = 64ff +55
                def run(start,end,count):
                    vm.emu_start(start-header,end-header,count=count)
                    assert vm.reg_read(UC_X86_REG_CS)==0x1000 and 0x10000+vm.reg_read(UC_X86_REG_IP)==end-header
                run(0x22c57,0x22c7c,50)
                base=struct.unpack('<h',vm.mem_read(0x67ffe,2))[0]
                active=hp>0 and dead==0 and unconscious==0
                if active:
                    vm.reg_write(UC_X86_REG_AX,defence_roll)
                    run(0x22d26,0x22d5b,60)
                net=struct.unpack('<h',vm.mem_read(0x67ffe,2))[0]
                if net>0:run(0x22dd2,0x22e37,200)
                after_unconscious,after_dead,after_hp=struct.unpack('<hhh',vm.mem_read(0x56555,6))
                cases.append(dict(scenario=name,strength=strength,level=level,attackRoll=attack_roll,
                    ac=ac,playerLevel=player_level,defenceRoll=defence_roll,hp=hp,dead=dead,
                    unconscious=unconscious,active=active,baseDamage=base,netDamage=net,
                    afterHp=after_hp,afterDead=after_dead,afterUnconscious=after_unconscious))
    return dict(source='Unmodified WeaponAttack two MUL/unsigned DIV10 fragments, defence subtraction and original conditional target word ADD/SUB/stores executed by Unicorn x86-16. Synthetic enemy/player memory and selected target/random values; executable unchanged.',
        executableSha256=hashlib.sha256(exe).hexdigest(),
        fragments=[dict(name=n,startFileOffset=a,endFileOffset=b,codeHex=exe[a:b].hex()) for n,a,b in FRAGMENTS],
        cases=cases,scope='Native arithmetic/store instruction evidence, including inactive target stores and positive integer counter overflow. Selection/resistance branches use source-directed inputs in Dart tests, not an original random seed or full DOS battle/save/UI replay. Enemy magic remains a separate gate.')


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--check',action='store_true');a=p.parse_args()
    if a.check:
        f=json.loads(OUTPUT.read_text());exe=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
        assert hashlib.sha256(exe).hexdigest()==f['executableSha256']
        assert [(x['name'],x['startFileOffset'],x['endFileOffset']) for x in f['fragments']]==FRAGMENTS
        for x in f['fragments']:assert exe[x['startFileOffset']:x['endFileOffset']].hex()==x['codeHex']
        print('Original WeaponAttack arithmetic and stores are current')
    else:OUTPUT.write_text(json.dumps(build(),ensure_ascii=False,indent=2)+'\n')


if __name__=='__main__':main()

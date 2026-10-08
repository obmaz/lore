#!/usr/bin/env python3
"""Original Fourth ascending selection compaction, preset copies and common init.

Synthetic pre-Fourth flags/hero records; character constants are parsed from
Pascal, not Dart assets. Original string copy and all game-state stores execute.
UI, cold-start memory and key timing are outside this fixture.
"""
import argparse
import hashlib
import itertools
import json
import struct
from pathlib import Path
from export_lore_cret import load_lines, parse_characters

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'test/fixtures/dos_creation_fourth.json'
START, END = 0xae49, 0xb14d


def build():
    from unicorn import Uc, UC_ARCH_X86, UC_MODE_16
    from unicorn.x86_const import UC_X86_REG_CS, UC_X86_REG_DS, UC_X86_REG_SS, UC_X86_REG_BP, UC_X86_REG_SP, UC_X86_REG_IP
    exe = (ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    source = (ROOT/'repo_source/LORE_1993_src/LORECRET.PAS').read_bytes()
    header = struct.unpack_from('<H',exe,8)[0]*16
    characters = parse_characters(load_lines())
    vm=Uc(UC_ARCH_X86,UC_MODE_16);vm.mem_map(0,0x80000);vm.mem_write(0,exe[header:])
    for c in characters:
        name=c['name'].encode('ascii');vm.mem_write(0x518f0+c['id']*18,bytes([len(name)])+name+bytes(17-len(name)))
        fields=[int(c['sex']=='female'),c['class'],*[c[k] for k in ['strength','mentality','concentration','endurance','resistance','agility','accuracy','luck']]]
        vm.mem_write(0x519ac+c['id']*10,bytes(fields))
    def run(selected,cls,accuracy):
        for r,v in [(UC_X86_REG_CS,0),(UC_X86_REG_DS,0x5000),(UC_X86_REG_SS,0x6000),(UC_X86_REG_BP,0x8000),(UC_X86_REG_SP,0x7f00)]:vm.reg_write(r,v)
        vm.mem_write(0x53654,bytes(int(i in selected) for i in range(1,11)))
        hero=bytearray(55);hero[:2]=b'\x01H';hero[18:31]=bytes([accuracy%2,cls,accuracy,20,21,22,23,24,accuracy,254,255,25,255])
        struct.pack_into('<hhhhh',hero,31,-32768,32767,22,20,21)
        hero[41:55]=bytes([255]*14)
        vm.mem_write(0x56536,bytes(hero));vm.mem_write(0x5656d,bytes(55*5))
        vm.emu_start(START-header,END-header,count=10000)
        assert vm.reg_read(UC_X86_REG_CS)==0 and vm.reg_read(UC_X86_REG_IP)==END-header
        return dict(selected=list(selected),classId=cls,accuracy=accuracy,beforeHero=list(hero),
                    afterParty=[list(vm.mem_read(0x564ff+55*n,55)) for n in range(1,7)])
    rows=[run(ids,8,20) for ids in itertools.combinations(range(1,11),4)]
    rows.extend(run([1,3,5,7],cls,acc) for cls,acc in itertools.product(range(11),range(256)))
    return dict(scope=__doc__,exeSha256=hashlib.sha256(exe).hexdigest(),sourceSha256=hashlib.sha256(source).hexdigest(),
                fragment=dict(start=START,end=END,sha256=hashlib.sha256(exe[START:END]).hexdigest()),cases=rows)


def main():
    p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');args=p.parse_args()
    if args.check:
        data=json.loads(OUT.read_text());exe=(ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
        assert data['exeSha256']==hashlib.sha256(exe).hexdigest()
        assert data['sourceSha256']==hashlib.sha256((ROOT/'repo_source/LORE_1993_src/LORECRET.PAS').read_bytes()).hexdigest()
        assert data['fragment']==dict(start=START,end=END,sha256=hashlib.sha256(exe[START:END]).hexdigest())
        assert data['scope']==__doc__
    else:
        data=build();rows=data.pop('cases');head=json.dumps(data,indent=2)[:-2]
        OUT.write_text(head+',\n  "cases": [\n'+',\n'.join('    '+json.dumps(r,separators=(',',':')) for r in rows)+'\n  ]\n}\n')


if __name__=='__main__':main()

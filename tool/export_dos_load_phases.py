"""Original complete Load with original DOS file/string/read helpers.

DOS open/read/close/attributes/current-directory and stack-space guard are
platform boundaries in one supplied directory. All defined Load instructions
execute, including cold records, map-source choice, font copy, pointer
counter bounds and weather. Missing-file/FNT failure, sound playback and pixels
are outside this fixture. The supplied seventh player is retained, not assumed
to be the actual startup memory value.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'test/fixtures/dos_load_phases.json'
START,END=0x2ebfc,0x2f4ca
MAPS=['GROUND1','GROUND2','WATER','SWAMP','LAVA','TOWN1','TOWN2','TOWN3','TOWN4','TOWN5',
      'T_DEN1','T_DEN2','DEN4','DEN1','DEN2','DEN3','DEN4','DEN5','DEN6','DEN7',
      'KEEP1','KEEP2','KEEP3','K_DEN1','K_DEN2','K_DEN2','PYRAMID1']

def players(prefix):
    rows=[]
    for i in range(1,8):
        r=bytearray(55);name=f'{prefix}{i}'.encode('ascii');r[:len(name)+1]=bytes([len(name)])+name
        r[18]=i%2;r[19]=min(i,6);r[20:30]=bytes([20+i]*10)
        struct.pack_into('<hhh',r,35,100+i,60+i,10+i);r[41:45]=bytes([3,4,5,6])
        struct.pack_into('<i',r,45,12000+i);r[49:55]=bytes([1,1,1,5,6,7]);rows.append(bytes(r))
    return rows

def party(map_id,gold):
    r=bytearray(108);r[:4]=bytes([map_id,5,6,20]);struct.pack_into('<i',r,4,gold)
    for i in range(100):r[8+i]=(i*3)%256
    r[8+6]=219;r[8+7]=1;r[8+11]=2
    return bytes(r)

def build():
    from unicorn import Uc,UC_ARCH_X86,UC_MODE_16,UC_HOOK_CODE,UC_HOOK_INTR
    from unicorn.x86_const import (UC_X86_REG_CS,UC_X86_REG_DS,UC_X86_REG_SS,
        UC_X86_REG_BP,UC_X86_REG_SP,UC_X86_REG_IP,UC_X86_REG_AX,UC_X86_REG_BX,
        UC_X86_REG_CX,UC_X86_REG_DX,UC_X86_REG_ES,UC_X86_REG_SI,UC_X86_REG_EFLAGS)
    root=ROOT/'repo_source/LORE_1993_runtime';exe=(root/'LORE.EXE').read_bytes()
    header=struct.unpack_from('<H',exe,8)[0]*16
    resources={p.name.lower():p.read_bytes() for p in root.glob('*.FNT')}
    memory_players=players('MEM');file_players=players('FILE')
    cases=[];map_records=[];map_ids={}
    for map_id,map_name in enumerate(MAPS,1):
     for warm in [False,True]:
      for saved in [False,True]:
        vm=Uc(UC_ARCH_X86,UC_MODE_16);vm.mem_map(0,0x80000);vm.mem_write(0,exe[header:])
        for reg,value in [(UC_X86_REG_CS,0x2466),(UC_X86_REG_DS,0x5000),
            (UC_X86_REG_SS,0x6000),(UC_X86_REG_BP,0x8000),(UC_X86_REG_SP,0x7d00)]:vm.reg_write(reg,value)
        vm.mem_write(0x539b8,bytes([warm]));vm.mem_write(0x5366b,b'1')
        vm.mem_write(0x53da0,struct.pack('<HHHH',0,0x7000,0,0x7400))
        vm.mem_write(0x539be,struct.pack('<HHHH',0x64d8,0x5000,0x64d9,0x5000))
        vm.mem_write(0x564ca,party(map_id,777))
        vm.mem_write(0x56536,b''.join(memory_players));vm.mem_write(0x74000,resources['chara.fnt'])
        canonical=(root/f'{map_name}.MAP').read_bytes();snapshot=bytearray(canonical);snapshot[2]=42;snapshot[-1]=44
        files=dict(resources,**{'party1.dat':party(map_id,1000),'player1.dat':b''.join(file_players[:6]),map_name.lower()+'.map':canonical})
        if saved:files['save1.map']=bytes(snapshot)
        handles={};events=[];dta=0x78000
        def read_name(v,pointer):
            return bytes(v.mem_read(pointer,256)).split(b'\0',1)[0].decode('ascii').replace('\\','/').split('/')[-1].lower()
        def result(v,ax,failed=False):
            v.reg_write(UC_X86_REG_AX,ax);flags=v.reg_read(UC_X86_REG_EFLAGS)
            v.reg_write(UC_X86_REG_EFLAGS,(flags|1) if failed else(flags&~1))
        def interrupt(v,num,user):
            nonlocal dta
            assert num==0x21
            ah=v.reg_read(UC_X86_REG_AX)>>8;ds=v.reg_read(UC_X86_REG_DS);dx=v.reg_read(UC_X86_REG_DX)
            if ah==0x3d:
                name=read_name(v,ds*16+dx);assert name in files,name
                handle=len(handles)+5;handles[handle]=dict(name=name,position=0,readBytes=0,readCalls=0)
                events.append(['open',name]);result(v,handle)
            elif ah==0x3f:
                handle=v.reg_read(UC_X86_REG_BX);count=v.reg_read(UC_X86_REG_CX);row=handles[handle]
                raw=files[row['name']][row['position']:row['position']+count];assert len(raw)==count
                v.mem_write(ds*16+dx,raw);row['position']+=count;row['readBytes']+=count;row['readCalls']+=1;result(v,count)
            elif ah==0x3e:
                row=handles[v.reg_read(UC_X86_REG_BX)];events.append(['close',row['name'],row['readBytes'],row['readCalls']]);result(v,0)
            elif ah==0x43:
                name=read_name(v,ds*16+dx);events.append(['attr',name])
                if name in files:v.reg_write(UC_X86_REG_CX,0x20);result(v,0)
                else:result(v,2,True)
            elif ah==0x19:result(v,2)
            elif ah==0x47:v.mem_write(ds*16+v.reg_read(UC_X86_REG_SI),b'\0');result(v,0)
            elif ah==0x2f:v.reg_write(UC_X86_REG_ES,dta//16);v.reg_write(UC_X86_REG_BX,dta%16)
            elif ah==0x1a:dta=ds*16+dx
            else:raise AssertionError(hex(ah))
        def hook(v,address,size,user):
            if address==0x30cd0+0x4df:
                sp=v.reg_read(UC_X86_REG_SP);ip,cs=struct.unpack('<HH',v.mem_read(0x60000+sp,4))
                v.reg_write(UC_X86_REG_SP,sp+4);v.reg_write(UC_X86_REG_CS,cs);v.reg_write(UC_X86_REG_IP,ip)
        vm.hook_add(UC_HOOK_INTR,interrupt);vm.hook_add(UC_HOOK_CODE,hook)
        vm.emu_start(START-header,END-header,count=2000000)
        assert vm.reg_read(UC_X86_REG_CS)==0x2466 and 0x24660+vm.reg_read(UC_X86_REG_IP)==END-header
        assert vm.reg_read(UC_X86_REG_SP)==0x7d00
        chosen=bytes(snapshot) if saved and not warm else canonical
        tiles=bytes(vm.mem_read(0x53d43+x*100+y,1)[0] for y in range(1,chosen[1]+1) for x in range(1,chosen[0]+1))
        assert tiles==chosen[2:]
        signature=hashlib.sha256(chosen).hexdigest()
        if signature not in map_ids:map_ids[signature]=len(map_records);map_records.append(dict(width=chosen[0],height=chosen[1],tilesHex=tiles.hex()))
        expected_players=memory_players if warm else file_players[:6]+memory_players[6:]
        after_players=[list(vm.mem_read(0x56536+i*55,55)) for i in range(7)]
        assert after_players==[list(r) for r in expected_players]
        assert bytes(vm.mem_read(0x74000,len(resources['chara.fnt'])))==resources['chara.fnt']
        cases.append(dict(mapId=map_id,mapName=map_name,warm=warm,saved=saved,events=events,
            beforeParty=list(party(map_id,777)),fileParty=list(party(map_id,1000)),
            afterParty=list(vm.mem_read(0x564ca,108)),afterPlayers=after_players,
            mapRecord=map_ids[signature],afterLoadFont=vm.mem_read(0x539b8,1)[0],
            position=vm.mem_read(0x539bc,1)[0]))
    return dict(scope=__doc__,exeSha256=hashlib.sha256(exe).hexdigest(),
        fragment=dict(start=START,end=END,sha256=hashlib.sha256(exe[START:END]).hexdigest()),
        resources={name:hashlib.sha256(data).hexdigest() for name,data in sorted(resources.items())},
        memoryPlayers=[list(r) for r in memory_players],filePlayers=[list(r) for r in file_players[:6]],
        mapRecords=map_records,cases=cases)

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args()
    if args.check:
        data=json.loads(OUT.read_text());root=ROOT/'repo_source/LORE_1993_runtime';exe=(root/'LORE.EXE').read_bytes()
        assert data['scope']==__doc__ and data['exeSha256']==hashlib.sha256(exe).hexdigest()
        assert data['fragment']==dict(start=START,end=END,sha256=hashlib.sha256(exe[START:END]).hexdigest())
        assert data['resources']=={p.name.lower():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(root.glob('*.FNT'))}
        assert len(data['cases'])==108
        assert data['memoryPlayers']==[list(r) for r in players('MEM')]
        assert data['filePlayers']==[list(r) for r in players('FILE')[:6]]
        for row in data['cases']:
            chosen=bytearray((root/f"{row['mapName']}.MAP").read_bytes())
            if row['saved'] and not row['warm']:chosen[2]=42;chosen[-1]=44
            assert data['mapRecords'][row['mapRecord']]==dict(width=chosen[0],height=chosen[1],tilesHex=chosen[2:].hex())
            assert row['beforeParty']==list(party(row['mapId'],777))
            assert row['fileParty']==list(party(row['mapId'],1000))
    else:OUT.write_text(json.dumps(build(),separators=(',',':'))+'\n')
if __name__=='__main__':main()

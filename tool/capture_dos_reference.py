#!/usr/bin/env python3
"""Prepare an isolated source DOS reference run, without modifying repo_source.

Usage: python3 tool/capture_dos_reference.py /tmp/lore-dos-runtime
Then: dosbox -conf /tmp/lore-dos-runtime/reference.conf
Ctrl-F5 captures a native 640x350 frame into the runtime's captures directory.
The seed is synthetic verification data, not a user save or new game fixture.
"""
import argparse
from pathlib import Path
import shutil
import struct

ROOT = Path(__file__).resolve().parents[1]

def prepare(destination, scenario="town"):
    destination = destination.resolve()
    source = ROOT / 'repo_source/LORE_1993_runtime'
    if destination == source or source in destination.parents:
        raise ValueError('Reference output must be outside the original runtime')
    shutil.copytree(source, destination, dirs_exist_ok=True)
    # /g skips Title_Menu; avoid launching the optional ISA init driver.
    (destination / 'INIT.CMD').unlink(missing_ok=True)
    etc = bytearray(100)
    etc[0], etc[6], etc[7] = 1, 2, 5
    if scenario == 'madjoe-reentry':
        etc[49] = 2
    if scenario == 'lorehunter-reentry':
        etc[37] = 0xa9
    if scenario.startswith('terrain-'):
        if scenario == 'terrain-swamp': etc[2] = 1
    if scenario.startswith('waterlord-'):
        etc[14] = 2 if scenario == 'waterlord-hidra' else 4
    map_id = 10 if scenario == 'lorehunter-reentry' or scenario.startswith('waterlord-') else 6
    coords = (40, 57) if scenario == 'lorehunter-reentry' else (87, 13) if scenario in ('hospital-overflow', 'hospital-wound-overflow') else (40, 16) if scenario == 'madjoe-reentry' else (51, 31)
    if scenario.startswith('waterlord-'):
        coords = (25, 19)
    if scenario == 'training-growth':
        coords = (21, 11)
    if scenario == 'battle-rewards':
        coords = (51, 13)
        etc[49] = 2
    (destination / 'PARTY1.DAT').write_bytes(
        struct.pack('<4Bi', map_id, *coords, 100, 10000) + etc)
    name = b'Hero'
    player = (bytes([len(name)]) + name + bytes(17 - len(name))
              + bytes([0, 1] + [20] * 10 + [0])
              + struct.pack('<5h', 0, 0, 100, 100, 100)
              + bytes([1, 1, 1, 0]) + struct.pack('<i', 0)
              + bytes([0, 0, 0, 1, 0, 0]))
    assert len(player) == 55
    if scenario.startswith('waterlord-'):
        hero = bytearray(player)
        struct.pack_into('<i', hero, 45, 2147483548)
        dead = bytearray(player)
        dead[1:5] = b'Mate'
        struct.pack_into('<h', dead, 33, 5)
        struct.pack_into('<h', dead, 35, 0)
        struct.pack_into('<i', dead, 45, 1000)
        empty = bytearray(55)
        struct.pack_into('<i', empty, 45, 1234)
        players = bytes(hero) + bytes(dead) + bytes(empty) + bytes(55) * 3
    elif scenario == 'rest-overflow':
        def member(name, *, hp=20, dead=0, unconscious=0, poison=0, sex=0,
                   endurance=20, level=1, magic=1, esp=1, power=20, sp=0, ep=0):
            record = bytearray(player)
            record[0:18] = bytes([len(name)]) + name.encode() + bytes(17-len(name))
            record[18], record[21], record[22], record[23], record[30] = sex, power, power, endurance, poison
            record[41:44] = bytes([level, magic, esp])
            struct.pack_into('<5h', record, 31, unconscious, dead, hp, sp, ep)
            return bytes(record)
        players = (member('Hero', hp=32639, endurance=255, level=128, magic=255, esp=255, power=255) +
                   member('Mate') + member('Dead', hp=100, dead=1, magic=255, esp=255, power=255) +
                   member('Poison', hp=5, poison=1, sex=1, sp=3, ep=4) +
                   member('Faint', hp=0, unconscious=1) +
                   member('', hp=0, dead=1, unconscious=1, sp=123, ep=124))
        party = bytearray((destination / 'PARTY1.DAT').read_bytes())
        party[3] = 255
        party[8:12] = bytes([2,3,4,5])
        (destination / 'PARTY1.DAT').write_bytes(party)
        terrain = bytearray((destination / 'TOWN1.MAP').read_bytes())
        terrain[2 + (31-1)*terrain[0] + (51-1)] = 1  # blocked current cell isolates Rest from Main's subsequent tile dispatch
        (destination / 'TOWN1.MAP').write_bytes(terrain)
        (destination / 'SAVE1.MAP').unlink(missing_ok=True)
    elif scenario.startswith('terrain-'):
        def member(name, poison=0, hp=100, unconscious=0, dead=0, luck=20,
                   endurance=20, level=1):
            record = bytearray(player)
            record[0:18] = bytes([len(name)]) + name.encode() + bytes(17-len(name))
            record[23], record[29], record[30], record[41] = endurance, luck, poison, level
            struct.pack_into('<3h', record, 31, unconscious, dead, hp)
            return bytes(record)
        if scenario == 'terrain-lava':
            players = (member('Hero', luck=0) +
                       member('Mate', hp=32760, luck=255, endurance=255, level=128) +
                       member('Faint', hp=0, unconscious=32640, luck=0, endurance=255, level=128) +
                       member('Dead', hp=0, unconscious=1, dead=32767, luck=0) +
                       member('', luck=0) + member('Down', hp=50, unconscious=1, luck=0))
        else:
            players = (member('Hero', poison=255) + member('Mate', poison=10, dead=99) +
                       member('Dead', poison=10, dead=100) +
                       member('Faint', poison=10, hp=0, unconscious=32767, dead=100) +
                       member('', poison=10) + member('Live', poison=11))
        terrain = bytearray((destination / 'TOWN1.MAP').read_bytes())
        terrain[2 + (31-1)*terrain[0] + (52-1)] = {'terrain-move':44, 'terrain-swamp':25, 'terrain-lava':26}[scenario]
        (destination / 'TOWN1.MAP').write_bytes(terrain)
        (destination / 'SAVE1.MAP').unlink(missing_ok=True)
    elif scenario.startswith('cure-'):
        hero = bytearray(player)
        hero[19] = 2
        hero[42] = 255 if scenario == 'cure-heal-overflow' else 6 if scenario == 'cure-conscious-overflow' else 8
        struct.pack_into('<h', hero, 35, 20)
        struct.pack_into('<h', hero, 37, 1000 if scenario == 'cure-heal-overflow' else 100)
        mate = bytearray(player)
        mate[0:5] = bytes([4]) + b'Mate'
        mate[23] = 255  # keep the synthetic unconscious value below max HP
        mate[41] = 128
        if scenario == 'cure-heal-overflow':
            struct.pack_into('<h', mate, 35, 32639)
        else:
            struct.pack_into('<h', mate, 35, 0)
            struct.pack_into('<h', mate, 31 if scenario == 'cure-conscious-overflow' else 33,
                             3277 if scenario == 'cure-conscious-overflow' else 30000)
        players = bytes(hero) + bytes(mate) + bytes(55) * 4
    elif scenario == 'battle-rewards':
        records = []
        for slot, exp in enumerate([2147483646,2147483647,0,-2147483648,100,200]):
            name = ['Hero','Mage','Dead','','Faint',''][slot]
            record = bytearray(player)
            record[0:18] = bytes([len(name)]) + name.encode() + bytes(17-len(name))
            record[19] = 1 if slot == 0 else 2
            record[24], record[26], record[27] = 255, 20, 20
            record[41] = 20 if slot == 0 else 1
            record[52] = 20 if slot == 0 else 1
            struct.pack_into('<h',record,35,100 if slot == 0 else 20)
            struct.pack_into('<h',record,37,0)
            if slot == 2:
                struct.pack_into('<3h',record,31,1,1,0)
            if slot == 4:
                struct.pack_into('<3h',record,31,1,0,0)
            struct.pack_into('<i',record,45,exp)
            records.append(bytes(record))
        players = b''.join(records)
        party = bytearray((destination / 'PARTY1.DAT').read_bytes())
        struct.pack_into('<i',party,4,2147483647)
        (destination / 'PARTY1.DAT').write_bytes(party)
    elif scenario == 'training-growth':
        records = []
        for name, cls in [('Fighter',1), ('Ninja',6), ('Hunter',7), ('Mage',2), ('Esper',3), ('Monk',5)]:
            record = bytearray(player)
            record[0:18] = bytes([len(name)]) + name.encode() + bytes(17-len(name))
            record[19] = cls
            record[25] = 255
            record[29] = 255 if cls in (1,6,7) else 0
            struct.pack_into('<i',record,45,50000)
            records.append(bytes(record))
        players = b''.join(records)
    elif scenario == 'hospital-wound-overflow':
        records = []
        for name, hp in [('Hero',32128), ('Mate',32127), ('Last',32129)]:
            record = bytearray(player)
            record[0:18] = bytes([len(name)]) + name.encode() + bytes(17-len(name))
            record[23], record[41] = 255, 128
            struct.pack_into('<h',record,35,hp)
            records.append(bytes(record))
        players = b''.join(records) + bytes(55)*3
    elif scenario == 'hospital-overflow':
        dead = bytearray(player)
        struct.pack_into('<h', dead, 33, 400)
        mate = bytes([4]) + b'Mate' + player[5:]
        players = bytes(dead) + mate + bytes(55) * 4
    elif scenario == 'madjoe-reentry':
        name = b'SlotSix'
        mate = bytes([len(name)]) + name + bytes(17 - len(name)) + player[18:]
        players = player + bytes(55) * 4 + mate
    else:
        players = player + bytes(55) * 5
    (destination / 'PLAYER1.DAT').write_bytes(players)
    captures = destination / 'captures'
    captures.mkdir(exist_ok=True)
    config = destination / 'reference.conf'
    config.write_text(f"""[sdl]
fullscreen=false
output=surface
[dosbox]
machine=vgaonly
captures={captures}
[cpu]
core=normal
cycles=3000
[midi]
mpu401=none
[sblaster]
sbtype=none
oplmode=none
[speaker]
pcspeaker=false
[autoexec]
mount c "{destination}"
c:
lore /g
""")
    return config

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('destination', type=Path)
    parser.add_argument('--scenario', choices=['town', 'hospital-overflow', 'madjoe-reentry', 'lorehunter-reentry', 'waterlord-hidra', 'waterlord-dragon', 'cure-heal-overflow', 'cure-conscious-overflow', 'cure-revitalize-overflow', 'terrain-move', 'terrain-swamp', 'terrain-lava', 'rest-overflow', 'hospital-wound-overflow', 'training-growth', 'battle-rewards'], default='town')
    args = parser.parse_args()
    print(prepare(args.destination, args.scenario))

#!/usr/bin/env python3
"""Check preserved cold-start DOS save bytes, not regenerate DOS observations.

These checks connect the decoded Flutter fixture to captured 55-byte records.
They do not replay DOS input, native RNG or an entire campaign.
"""
import hashlib
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]


def records(data):
    assert len(data) == 6 * 55
    result = []
    for start in range(0, len(data), 55):
        r = data[start:start + 55]
        member = {'name': r[1:1 + r[0]].decode('ascii')}
        for offset, key in enumerate((
            'sex', 'classId', 'strength', 'mentality', 'concentration',
            'endurance', 'resistance', 'agility', 'accArms', 'accMagic',
            'accEsp', 'luck', 'poison',
        ), 18):
            member[key] = r[offset]
        member.update(zip(('unconscious', 'dead', 'hp', 'sp', 'esp'),
                          struct.unpack('<5h', r[31:41])))
        member.update(zip(('battleLevel', 'magicLevel', 'espLevel', 'ac'), r[41:45]))
        member['experience'] = struct.unpack('<i', r[45:49])[0]
        member.update(zip(('weapon', 'shield', 'armor', 'weaPower', 'shiPower',
                           'armPower'), r[49:55]))
        result.append(member)
    return result


def party(data):
    assert len(data) == 108
    result = dict(zip(('mapId', 'x', 'y', 'food', 'gold'),
                      struct.unpack('<4Bi', data[:8])))
    result['etc'] = list(data[8:])
    return result


def check():
    fixture = json.loads((ROOT / 'test/fixtures/dos_new_game.json').read_text())
    executable = (ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
    assert hashlib.sha256(executable).hexdigest() == fixture['executableSha256']
    for observation in (fixture, fixture['firstQuest']):
        files = observation['files']
        for captured in files.values():
            assert hashlib.sha256(bytes.fromhex(captured['hex'])).hexdigest() == captured['sha256']
        assert records(bytes.fromhex(files['PLAYER1.DAT']['hex'])) == observation['records']
        assert party(bytes.fromhex(files['PARTY1.DAT']['hex'])) == observation['party']
    for slot in range(2, 5):
        for prefix in ('PLAYER', 'PARTY'):
            assert fixture['files'][f'{prefix}{slot}.DAT'] == fixture['files'][f'{prefix}1.DAT']
    saved_map = bytes.fromhex(fixture['firstQuest']['files']['SAVE1.MAP']['hex'])
    assert saved_map == (ROOT / 'repo_source/LORE_1993_runtime/TOWN1.MAP').read_bytes()
    assert saved_map[:2] == bytes([100, 100])
    print('Cold-start four DOS saves and first Lord Ahn checkpoint bytes: verified')


if __name__ == '__main__':
    check()

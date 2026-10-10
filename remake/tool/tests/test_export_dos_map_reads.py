import hashlib
import json
import struct
import unittest
import export_dos_map_reads as e

class MapReadsTest(unittest.TestCase):
    def test_native_read_addresses_data_and_geometry_policy(self):
        data=json.loads(e.OUT.read_text())
        self.assertEqual(len(data['cases']),74)
        for row in data['cases']:
            payload=bytes.fromhex(row['payloadHex']);w,h=payload[:2]
            digest=hashlib.sha256()
            for pos,value in enumerate(payload):
                target=0x53d96+pos if pos<2 else 0x53d43+((pos-2)%w+1)*100+((pos-2)//w+1)
                digest.update(struct.pack('<IIB',pos,target,value))
            self.assertEqual(row['traceSha256'],digest.hexdigest())
            self.assertEqual(row['readCount'],2+w*h)
            self.assertEqual(bytes.fromhex(row['nativeTilesHex']),payload[2:])
            if row['valid']:self.assertFalse(row['afterGuardChanged'])
            if w==101:self.assertTrue(row['afterGuardChanged'])

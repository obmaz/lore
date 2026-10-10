import hashlib
import json
import unittest
import export_dos_setall_enemy_read as e

class SetAllEnemyReadTest(unittest.TestCase):
    def test_native_read_order_and_complete_table(self):
        data=json.loads(e.OUT.read_text())
        db=(e.ROOT/'repo_source/LORE_1993_runtime/FOEDATA.DAT').read_bytes()
        self.assertEqual(data['databaseSha256'],hashlib.sha256(db).hexdigest())
        self.assertEqual(data['finalIndex'],75);self.assertEqual(data['ioResult'],0)
        self.assertEqual(bytes(v for row in data['records'] for v in row),db)
        for i,r in enumerate(data['reads']):
            self.assertEqual(r,dict(index=i+1,target=0x566b8+i*29,length=29,fileOffset=i*29))

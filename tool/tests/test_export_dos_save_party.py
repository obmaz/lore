import hashlib
import json
import unittest

import export_dos_save_party as exporter

class SavePartyTest(unittest.TestCase):
    def test_native_six_record_scope_and_full_named_masks(self):
        data=json.loads(exporter.OUT.read_text())
        exe=(exporter.ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
        self.assertEqual(data['exeSha256'],hashlib.sha256(exe).hexdigest())
        self.assertEqual(data['fragments'],[dict(name=n,start=a,end=z,sha256=hashlib.sha256(exe[a:z]).hexdigest()) for n,a,z in exporter.SPANS])
        self.assertEqual({(r['mask'],r['shift']) for r in data['cases']},set((m,s) for m in range(64) for s in range(6)))
        for row in data['cases']:
            self.assertEqual(len(row['saved']),6)
            self.assertEqual(row['saved'],row['inputs'][:6])
            self.assertTrue(row['loadScratchUnchanged'])
            self.assertEqual(row['inputs'][6]['name'],'Slot7')

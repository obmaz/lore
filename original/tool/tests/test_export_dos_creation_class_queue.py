import hashlib
import json
import unittest

import export_dos_creation_class_queue as exporter

class CreationClassQueueTest(unittest.TestCase):
    def test_native_queue_domain_and_consumption(self):
        data=json.loads(exporter.OUT.read_text())
        exe=(exporter.ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
        self.assertEqual(data['exeSha256'],hashlib.sha256(exe).hexdigest())
        self.assertEqual(data['fragment'],dict(start=exporter.START,end=exporter.END,sha256=hashlib.sha256(exe[exporter.START:exporter.END]).hexdigest()))
        self.assertEqual(len(data['cases']),32768)
        self.assertEqual({(r[0],r[1]) for r in data['cases']},set((k,m) for k in range(256) for m in range(128)))
        self.assertTrue(all(r[3]==2 for r in data['cases']))
        self.assertEqual(len(data['mixed']),1536)
        self.assertTrue(all(r[3]==len(r[0]) for r in data['mixed']))
        self.assertTrue(all(r[2] is None for r in data['mixed'] if r[0][-1] in [27,75]))

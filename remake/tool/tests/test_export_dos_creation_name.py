import hashlib
import json
import unittest
import export_dos_creation_name as exporter

class CreationNameTest(unittest.TestCase):
    def test_native_fingerprint_and_full_byte_domains(self):
        data = json.loads(exporter.OUT.read_text())
        exe = (exporter.ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
        self.assertEqual(data['exeSha256'],hashlib.sha256(exe).hexdigest())
        self.assertEqual(data['fragments'],[dict(start=a,end=z,sha256=hashlib.sha256(exe[a:z]).hexdigest()) for a,z in exporter.SPANS])
        self.assertEqual(len(data['cases']),8704)
        for length in range(17):
            rows = [r for r in data['cases'] if r['length'] == length]
            self.assertEqual({r['key'] for r in rows},set(range(256)))
            self.assertEqual({r['scan'] for r in rows if r['key'] == 0},set(range(256)))
        self.assertEqual({r['key'] for r in data['gender']},set(range(256)))
        self.assertEqual([r['key'] for r in data['gender'] if r['complete']],[70,77,102,109])

import hashlib,json,unittest
import export_dos_join_bounds as exporter
class JoinBoundsTest(unittest.TestCase):
    def test_fingerprint_and_all_byte_axes(self):
        data=json.loads(exporter.OUT.read_text())
        exe=(exporter.ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
        self.assertEqual(data['exeSha256'],hashlib.sha256(exe).hexdigest())
        self.assertEqual(data['fragment'],dict(start=exporter.START,end=exporter.END,sha256=hashlib.sha256(exe[exporter.START:exporter.END]).hexdigest()))
        self.assertEqual(len(data['cases']),6656)
        self.assertEqual({r['level'] for r in data['cases']},set(range(256)))
        self.assertEqual({r['cast'] for r in data['cases']},set(range(256)))

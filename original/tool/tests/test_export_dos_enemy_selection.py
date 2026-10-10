import hashlib
import json
import unittest
import export_dos_enemy_selection as exporter

class EnemySelectionTest(unittest.TestCase):
    def test_fingerprints_and_complete_input_domain(self):
        data = json.loads(exporter.OUT.read_text())
        exe = (exporter.ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
        self.assertEqual(data['exeSha256'], hashlib.sha256(exe).hexdigest())
        self.assertEqual(data['fragments'], [dict(start=a, end=b, sha256=hashlib.sha256(exe[a:b]).hexdigest()) for a, b in exporter.SPANS])
        self.assertEqual(len(data['keys']), 14336)
        self.assertEqual(len(data['colours']), 65536)
        self.assertEqual({(r['count'], r['number']) for r in data['keys']}, {(c,n) for c in range(1,8) for n in range(1,c+1)})

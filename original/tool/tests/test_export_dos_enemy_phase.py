import unittest
import export_dos_enemy_phase as exporter

class EnemyPhaseTest(unittest.TestCase):
    def test_native_fragment_fingerprint_and_domain(self):
        import json, hashlib
        data = json.loads(exporter.OUT.read_text())
        exe = (exporter.ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
        self.assertEqual(data['exeSha256'], hashlib.sha256(exe).hexdigest())
        self.assertEqual(len(data['cases']), 66048)
        self.assertEqual({r['hp'] for r in data['cases'][:65536]}, set(range(-32768, 32768)))

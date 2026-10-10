import hashlib, json, unittest
import export_dos_battle_commands as exporter

class BattleCommandsTest(unittest.TestCase):
    def test_fingerprints_and_manual_domains(self):
        data=json.loads(exporter.OUT.read_text())
        exe=(exporter.ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
        self.assertEqual(data['exeSha256'],hashlib.sha256(exe).hexdigest())
        self.assertEqual(data['fragments'],[dict(how=h,start=a,end=exporter.END,sha256=hashlib.sha256(exe[a:exporter.END]).hexdigest()) for h,a in exporter.STARTS.items()])
        self.assertEqual(len(data['cases']),58368)
        self.assertEqual({r['how'] for r in data['cases']},{1,2,3,4,6})

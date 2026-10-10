import hashlib
import json
import unittest
import export_dos_load_errors as e

class LoadErrorsTest(unittest.TestCase):
    def test_native_need_branch_and_nonreturning_halt(self):
        data=json.loads(e.OUT.read_text())
        exe=(e.ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
        self.assertEqual(data['exeSha256'],hashlib.sha256(exe).hexdigest())
        self.assertEqual(len(data['cases']),len(e.NAMES)*2)
        for row in data['cases']:
            self.assertEqual(row['events'][:3],[['mode',3],['clear'],['color',12]])
            self.assertEqual(row['events'][-1],['halt',0])
            texts=[r[1] for r in row['events'] if r[0]=='write']
            self.assertEqual(texts,['"'+row['name']+'" not found.']+
                (['You need to CREATE CHARACTER.'] if row['need'] else []))

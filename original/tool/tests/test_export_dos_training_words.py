import hashlib
import json
import unittest

import export_dos_training_words as e


class TrainingWordsTest(unittest.TestCase):
    def test_complete_case_word_spaces_and_unassigned_stack_marker(self):
        data = json.loads(e.OUT.read_text())
        exe = (e.ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
        self.assertEqual(data['exeSha256'], hashlib.sha256(exe).hexdigest())
        self.assertEqual(data['fragment'], dict(start=e.START, end=e.END,
            sha256=hashlib.sha256(exe[e.START:e.END]).hexdigest()))
        self.assertEqual(len(data['negativeWords']), 65536)
        self.assertEqual(len(data['quotientWords']), 65536)
        self.assertEqual(len(data['smallXp']), 20000)
        self.assertEqual(set(data['negativeWords']), {1, 2, 3, -32768})
        self.assertEqual(data['negativeWords'].count(-32768), 45536)
        self.assertEqual(set(data['quotientWords']), set(range(4, 21)))
        self.assertEqual(len(data['retention']), 48)
        self.assertTrue(all(r['result'] == r['previous'] for r in data['retention'] if r['xp'] in [-32768, -1]))

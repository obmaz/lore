import hashlib
import json
import unittest

import export_dos_return_magic as e


class ReturnMagicTest(unittest.TestCase):
    def test_original_helpers_full_integer_scope_and_distinct_result_buffers(self):
        data = json.loads(e.OUT.read_text())
        exe = (e.ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
        self.assertEqual(data['exeSha256'], hashlib.sha256(exe).hexdigest())
        self.assertEqual(data['fragments'], [dict(name=n, start=a, end=z,
            sha256=hashlib.sha256(exe[a:z]).hexdigest()) for n, a, z in e.SPANS])
        self.assertEqual(data['checkedInputs'], 65536)
        self.assertEqual(data['unassignedInputs'], 65491)
        self.assertEqual([r['magic'] for r in data['defined']], list(range(1, 46)))
        self.assertEqual(len(data['grammarByLowByte']), 256)
        self.assertTrue(all(r['unchanged'] and r['name'] == r['seed'] for r in data['unassigned']))
        self.assertEqual({r['seed'] for r in data['unassigned']}, {'JUNK', 'Old result', ''})

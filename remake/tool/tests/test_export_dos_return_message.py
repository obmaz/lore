import hashlib
import json
import unittest

import export_dos_return_message as e


class ReturnMessageTest(unittest.TestCase):
    def test_native_case_profiles_names_and_unsafe_pointer_scope(self):
        data = json.loads(e.OUT.read_text())
        exe = (e.ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
        self.assertEqual(data['scope'], e.__doc__)
        self.assertEqual(data['exeSha256'], hashlib.sha256(exe).hexdigest())
        self.assertEqual(data['fragments'], [dict(name=n, start=a, end=z,
            sha256=hashlib.sha256(exe[a:z]).hexdigest()) for n, a, z in e.SPANS])
        self.assertEqual(len(data['cases']), 10010)
        self.assertEqual({r['who'] for r in data['cases']}, set(range(1, 8)))
        self.assertEqual({r['how'] for r in data['cases'] if 1 <= r['how'] <= 7}, set(range(1, 8)))
        self.assertEqual({r['weapon'] for r in data['cases'] if r['how'] == 1}, set(range(256)))
        self.assertEqual(len(data['outOfArrayReads']), 4)
        self.assertTrue(all('OtherMemory' in r['text'] for r in data['outOfArrayReads']))

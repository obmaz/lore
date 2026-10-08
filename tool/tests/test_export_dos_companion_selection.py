import json
import unittest
from unittest.mock import patch
from export_dos_companion_selection import OUT,main


class CompanionSelectionNativeTest(unittest.TestCase):
    def test_fingerprints(self):
        with patch('sys.argv',['export_dos_companion_selection','--check']):main()

    def test_complete_domain(self):
        rows=json.loads(OUT.read_text())['cases']
        self.assertEqual({r['mask'] for r in rows},{n for n in range(1024) if n.bit_count()<=3})
        self.assertEqual({r['key'] for r in rows},set(range(256)))
        self.assertEqual({r['scan'] for r in rows if not r['pending'] and r['key']==0},set(range(256)))
        self.assertEqual({r['afterPending'] for r in rows},{False,True})
        self.assertTrue(any(r['complete'] for r in rows))
        self.assertTrue(any(r['profiles'] for r in rows))

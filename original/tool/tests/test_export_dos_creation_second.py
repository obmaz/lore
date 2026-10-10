import json
import unittest
from unittest.mock import patch
from export_dos_creation_second import OUT,main,configs


class CreationSecondNativeTest(unittest.TestCase):
    def test_fingerprints(self):
        with patch('sys.argv',['export_dos_creation_second','--check']):main()

    def test_complete_input_domain(self):
        rows=list(configs())
        self.assertEqual(len(rows),54006)
        self.assertEqual({r['key'] for r in rows},set(range(256)))
        self.assertEqual({r['scan'] for r in rows if r['key']==0},set(range(256)))
        self.assertEqual({tuple(r['values']) for r in rows},
                         {(a,b,c) for a in range(21) for b in range(21) for c in range(21) if a+b+c<=40})

    def test_actual_native_exit_and_rollback(self):
        rows=json.loads(OUT.read_text())['cases']
        self.assertEqual({r['finished'] for r in rows},{False,True})
        self.assertTrue(any(r['scan']==77 and r['afterValues']==r['values'] for r in rows))
        self.assertTrue(any(r['scan']==75 and r['afterValues']==r['values'] for r in rows))

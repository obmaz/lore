import json
import unittest
from unittest.mock import patch
from export_dos_enemy_colors import OUT,main


class EnemyColorsNativeTest(unittest.TestCase):
    def test_fingerprint(self):
        with patch('sys.argv',['export_dos_enemy_colors','--check']):main()

    def test_native_scope(self):
        data=json.loads(OUT.read_text());rows=data['cases']
        self.assertEqual({r['hp'] for r in rows},set(range(-32768,32768)))
        self.assertEqual({r['count'] for r in rows},set(range(8)))
        self.assertEqual({(r['unconscious'],r['dead']) for r in rows},{(False,False),(False,True),(True,False),(True,True)})
        self.assertTrue(all(len(r['printed'])==r['count'] for r in rows))

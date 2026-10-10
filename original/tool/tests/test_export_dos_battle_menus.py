import itertools
import json
import unittest
from unittest.mock import patch
from export_dos_battle_menus import OUT,main


class BattleMenusNativeTest(unittest.TestCase):
    def test_fingerprints(self):
        with patch('sys.argv',['export_dos_battle_menus','--check']):main()

    def test_all_levels_and_classes(self):
        data=json.loads(OUT.read_text())
        self.assertEqual({(r['how'],r['level']) for r in data['cases']},set(itertools.product([2,3,4],range(256))))
        self.assertEqual({r['maxsum'] for r in data['cases']},set(range(1,8)))

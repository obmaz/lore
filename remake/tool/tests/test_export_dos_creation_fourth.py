import itertools
import json
import unittest
from unittest.mock import patch
from export_dos_creation_fourth import OUT, main


class CreationFourthNativeTest(unittest.TestCase):
    def test_fingerprints(self):
        with patch('sys.argv',['export_dos_creation_fourth','--check']): main()

    def test_all_companion_combinations(self):
        data=json.loads(OUT.read_text())
        self.assertEqual({tuple(r['selected']) for r in data['cases']},set(itertools.combinations(range(1,11),4)))
        self.assertEqual({(r['classId'],r['accuracy']) for r in data['cases'] if r['selected']==[1,3,5,7]},set(itertools.product(range(11),range(256))))

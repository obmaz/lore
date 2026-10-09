import json
import unittest
from export_dos_fill_patterns import build, OUT


class FillPatternTests(unittest.TestCase):
    def test_actual_driver_reproduces_every_fill_row(self):
        data=build()
        self.assertEqual(data,json.loads(OUT.read_text()))
        self.assertEqual(len(data['patterns']),12)
        self.assertEqual(data['patterns'][0],[0]*8)
        self.assertEqual(data['patterns'][1],[255]*8)


if __name__=='__main__':
    unittest.main()

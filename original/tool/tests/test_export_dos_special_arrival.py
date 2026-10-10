import json
import unittest
from export_dos_special_arrival import build, OUT


class SpecialArrivalTests(unittest.TestCase):
    def test_original_fragments_reproduce_complete_fixture(self):
        data = build()
        self.assertEqual(data, json.loads(OUT.read_text()))
        self.assertEqual(len(data['cases']), 30)
        for case in data['cases']:
            delays = [op[1] for op in case['trace'] if op[0] == 'delay']
            self.assertEqual(delays, [2000]*3 if case['kind']=='guardian'
                             else [1000]*6+[2000]*5)


if __name__ == '__main__':
    unittest.main()

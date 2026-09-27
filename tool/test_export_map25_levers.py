import json
import unittest

import export_map25_levers


class Map25LeverTest(unittest.TestCase):
    def test_both_levers_and_saved_states_are_current(self):
        expected = export_map25_levers.fixture()
        saved = json.loads(export_map25_levers.OUTPUT.read_text())
        self.assertEqual(saved, expected)
        self.assertEqual(expected['levers'], 2)
        self.assertEqual(len(expected['cases']), 8)
        self.assertEqual({case['setBit'] for case in expected['cases']}, {7, 8})


if __name__ == '__main__':
    unittest.main()

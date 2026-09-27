import json
import unittest

import export_map12_replay


class Map12ReplayTest(unittest.TestCase):
    def test_door_and_seal_branches_are_current(self):
        expected = export_map12_replay.fixture()
        saved = json.loads(export_map12_replay.OUTPUT.read_text())
        self.assertEqual(saved, expected)
        self.assertEqual(len(expected['cases']), 8)
        self.assertEqual({case['line'] for case in expected['cases']}, {573, 585})


if __name__ == '__main__':
    unittest.main()

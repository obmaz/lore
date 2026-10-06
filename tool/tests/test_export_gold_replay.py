import json
import unittest

import export_gold_replay


class GoldReplayTest(unittest.TestCase):
    def test_source_gold_caches_are_current(self):
        expected = export_gold_replay.fixture()
        saved = json.loads(export_gold_replay.OUTPUT.read_text())
        self.assertEqual(saved, expected)
        self.assertEqual(expected['caches'], 11)
        self.assertEqual(len(expected['cases']), 22)
        self.assertEqual(
            {case['map'] for case in expected['cases']}, {9, 14},
        )


if __name__ == '__main__':
    unittest.main()

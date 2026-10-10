import json
import unittest

import export_entrance_replay


class EntranceReplayTest(unittest.TestCase):
    def test_source_loads_and_portal_variants_are_current(self):
        expected = export_entrance_replay.fixture()
        saved = json.loads(export_entrance_replay.OUTPUT.read_text())
        self.assertEqual(saved, expected)
        self.assertEqual(expected['loads'], 27)
        self.assertEqual(len(expected['cases']), 41)
        self.assertEqual(len({case['line'] for case in expected['cases']}), 27)


if __name__ == '__main__':
    unittest.main()

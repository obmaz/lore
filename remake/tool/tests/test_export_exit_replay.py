import json
import unittest

import export_exit_replay


class ExitReplayTest(unittest.TestCase):
    def test_all_source_exit_destinations_are_current(self):
        expected = export_exit_replay.fixture()
        saved = json.loads(export_exit_replay.OUTPUT.read_text())
        self.assertEqual(saved, expected)
        self.assertEqual(expected['exits'], 21)
        self.assertEqual(
            {case['map'] for case in expected['cases']},
            set(range(6, 26)) | {27},
        )


if __name__ == '__main__':
    unittest.main()

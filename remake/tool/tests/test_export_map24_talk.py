import json
import unittest

import export_map24_talk


class Map24TalkTest(unittest.TestCase):
    def test_programmer_conversation_effect_is_current(self):
        expected = export_map24_talk.fixture()
        saved = json.loads(export_map24_talk.OUTPUT.read_text())
        self.assertEqual(saved, expected)
        self.assertEqual(expected['map'], 24)
        self.assertEqual(expected['sourceFlag'], [43, 4])


if __name__ == '__main__':
    unittest.main()

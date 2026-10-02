import json
import unittest

from audit_loretalk import DIALOGUES, FACILITIES, SCRIPTS, providers, source_coordinates


class LoreTalkAuditTest(unittest.TestCase):
    def test_all_literal_talk_coordinates_have_an_active_provider(self):
        coordinates = source_coordinates()
        scripts = json.loads(SCRIPTS.read_text(encoding="utf-8"))["scripts"]
        facilities = json.loads(FACILITIES.read_text(encoding="utf-8"))["facilities"]
        dialogues = json.loads(DIALOGUES.read_text(encoding="utf-8"))["dialogues"]
        self.assertEqual(len(coordinates), 148)
        self.assertEqual(
            [entry for entry in coordinates if not providers(entry, scripts, facilities, dialogues)],
            [],
        )

    def test_disabled_rule_does_not_count_as_ported_talk(self):
        entry = (6, 9, 64, 18)
        disabled = [{"map": 6, "x": 9, "y": 64, "trigger": "talk", "disabled": True}]
        self.assertEqual(providers(entry, disabled, [], []), [])
        self.assertEqual(providers(entry, disabled, [], [{"map": 6, "x": 9, "y": 64}]), ["dialogue"])


if __name__ == "__main__":
    unittest.main()

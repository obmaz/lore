import json
import unittest

from audit_loretalk import FACILITIES, SCRIPTS, direct_providers, providers, source_coordinates


class LoreTalkAuditTest(unittest.TestCase):
    def test_all_literal_talk_coordinates_have_an_active_provider(self):
        coordinates = source_coordinates()
        scripts = json.loads(SCRIPTS.read_text(encoding="utf-8"))["scripts"]
        facilities = json.loads(FACILITIES.read_text(encoding="utf-8"))["facilities"]
        self.assertEqual(len(coordinates), 148)
        self.assertEqual(
            [entry for entry in coordinates if not providers(entry, scripts, facilities)],
            [],
        )

    def test_direct_madjoe_provider_counts_with_the_old_json_copy_disabled(self):
        self.assertEqual(direct_providers()[(6, 40, 15)], 'LoreTalkProcedures.madJoeRecruit')
        self.assertEqual(providers((6, 40, 15, 191), [], []), ['dart-procedure'])

    def test_registered_async_procedure_counts_with_all_json_stages_disabled(self):
        self.assertEqual(direct_providers()[(10, 25, 18)], 'LoreTalkProcedure.waterFieldLord')
        self.assertEqual(providers((10, 25, 18, 640), [], []), ['dart-procedure'])

    def test_disabled_rule_does_not_count_as_ported_talk(self):
        entry = (6, 9, 64, 18)
        disabled = [{"map": 6, "x": 9, "y": 64, "trigger": "talk", "disabled": True}]
        self.assertEqual(providers(entry, disabled, []), ['dart-procedure'])


if __name__ == "__main__":
    unittest.main()

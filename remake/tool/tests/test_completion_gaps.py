"""Completion review must distinguish absent links from verified behavior."""
import unittest
import report_completion_gaps as gaps


class CompletionGapsTest(unittest.TestCase):
    def test_platform_and_partial_sites_are_not_reported_as_verified(self):
        ledger = {
            "control_sites": [
                {"id": "game:a", "routine": "game:a", "classification": "unclassified"},
                {"id": "game:b", "routine": "game:b", "classification": "common-rule", "verification_status": "partial"},
                {"id": "platform", "routine": "platform", "classification": "platform"},
            ],
            "linked_contracts": [],
            "map_writes": [{"id": "write", "status": "unmapped"}],
        }
        data = gaps.summarize(ledger)
        self.assertEqual(data["summary"], {
            "game_control_sites": 2, "unclassified": 1, "partial": 1,
            "verified": 0, "unmapped_map_writes": 1,
        })
        self.assertEqual([s["id"] for s in data["unclassified_sites"]], ["game:a"])
        self.assertEqual(data["unmapped_map_writes"], ledger["map_writes"])

    def test_native_evidence_candidates_distinguish_notes_and_explicit_links(self):
        ledger = {"control_sites": [], "map_writes": [], "linked_contracts": [
            {"id": "explicit", "test": "test/ending_view_test.dart", "note": "partial",
             "supporting_evidence": ["test/fixtures/dos_final_ending_completion.json"]},
            {"id": "mentioned", "test": "test/ending_view_test.dart",
             "note": "dos_ending_input.json is bounded synthetic input evidence"},
        ]}
        data = gaps.summarize(ledger)
        by_path = {f["path"]: f for f in data["native_fixture_candidates"]}
        final = by_path["test/fixtures/dos_final_ending_completion.json"]
        self.assertEqual(final["explicit_contracts"], ["explicit"])
        self.assertIn("test/final_battle_native_dos_test.dart", final["test_candidates"])
        keys = by_path["test/fixtures/dos_ending_input.json"]
        self.assertEqual(keys["explicit_contracts"], [])
        self.assertEqual(keys["note_mentions"], ["mentioned"])
        self.assertEqual(data["summary"]["verified"], 0)


if __name__ == "__main__":
    unittest.main()

import copy
import json
import unittest

import jsonschema

from validate_story_authoring import ROOT, validate


class StoryAuthoringTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sample = json.loads((ROOT / "authoring/drafts/prologue.json").read_text())
        cls.catalog = json.loads((ROOT / "materials/scripts.json").read_text())

    def setUp(self):
        self.doc = copy.deepcopy(self.sample)

    def check(self):
        return validate(self.doc, self.catalog)

    def test_outline_valid_but_not_complete(self):
        report = self.check()
        self.assertEqual(report["nodes"], 6)
        self.assertEqual(report["coverage"], "partial")
        self.assertGreater(report["unaccounted_scoped_literals"], 0)
        self.assertFalse(report["condition_paths_verified"])

    def test_unknown_target(self):
        self.doc["nodes"][0]["choices"][0]["target"] = "missing"
        with self.assertRaisesRegex(ValueError, "unknown target"):
            self.check()

    def test_duplicate_node(self):
        self.doc["nodes"].append(copy.deepcopy(self.doc["nodes"][0]))
        with self.assertRaisesRegex(ValueError, "duplicate node"):
            self.check()

    def test_changed_original_quote(self):
        self.doc["nodes"][1]["blocks"][0]["text"] += "!"
        with self.assertRaisesRegex(ValueError, "source quote changed"):
            self.check()

    def test_changed_original_choice(self):
        self.doc["nodes"][3]["choices"][0]["label"] = "그래요"
        with self.assertRaisesRegex(ValueError, "source quote changed"):
            self.check()

    def test_unknown_state(self):
        self.doc["nodes"][1]["choices"][1]["when"]["state"] = "unknown"
        with self.assertRaisesRegex(ValueError, "unknown state"):
            self.check()

    def test_bad_effect_type(self):
        self.doc["nodes"][3]["choices"][0]["effects"][0]["value"] = 9
        with self.assertRaisesRegex(ValueError, "type mismatch"):
            self.check()

    def test_quest_local_state_cannot_carry(self):
        self.doc["nodes"][-1]["handoff"]["carry_states"].append("event.prison_visited")
        with self.assertRaisesRegex(ValueError, "invalid carry state"):
            self.check()

    def test_source_claim_needs_evidence(self):
        self.doc["nodes"][0]["provenance"]["source_refs"] = []
        with self.assertRaisesRegex(ValueError, "requires evidence"):
            self.check()

    def test_cannot_mark_partial_outline_complete(self):
        self.doc["coverage"]["status"] = "complete"
        self.doc["coverage"]["deferred_source_refs"] = []
        with self.assertRaisesRegex(ValueError, "unaccounted source literals"):
            self.check()

    def test_cannot_approve_unresolved_work(self):
        self.doc["meta"]["status"] = "approved"
        with self.assertRaisesRegex(ValueError, "unresolved work"):
            self.check()

    def test_unknown_metadata_is_not_silently_accepted(self):
        self.doc["meta"]["typo_field"] = True
        with self.assertRaises(jsonschema.ValidationError):
            self.check()

    def test_structural_trap(self):
        self.doc["nodes"][1]["choices"] = [self.doc["nodes"][1]["choices"][1]]
        with self.assertRaisesRegex(ValueError, "no structural route"):
            self.check()

    def test_nested_predicates(self):
        self.doc["nodes"][4]["blocks"][0]["when"] = {
            "all": [{"state": "knowledge.missing_squad", "op": "eq", "value": True},
                    {"not": {"state": "relationship.lord_trust", "op": "gte", "value": 2}}]}
        self.check()


if __name__ == "__main__":
    unittest.main()

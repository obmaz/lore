import unittest
from unittest.mock import patch
from story_continuity import CANON, DEFAULT, context, input_hashes, read, validate


class ContinuityTest(unittest.TestCase):
    def setUp(self):
        self.story = read(DEFAULT)
        self.continuity = read(DEFAULT.with_name("prologue.continuity.json"))
        self.canon = read(CANON)

    def packet(self, *choices):
        return context(self.story, self.continuity, self.canon, list(choices))

    def test_direct_path_knows_no_optional_testimony(self):
        result = self.packet("enter_courtyard", "visit_lord")
        self.assertEqual(result["knowledge"]["protagonist"], [])
        self.assertEqual(result["state"]["companions.optional_recruits"], [])
        self.assertNotIn("audience_joe", [b["id"] for b in result["visible_blocks"]])
        self.assertEqual(result["committed_events"], [])

    def test_accept_and_decline_share_knowledge_not_party(self):
        a = self.packet("enter_courtyard", "visit_prison", "accept_joe", "visit_lord")
        b = self.packet("enter_courtyard", "visit_prison", "decline_joe", "visit_lord")
        self.assertEqual(a["knowledge"]["protagonist"], b["knowledge"]["protagonist"])
        self.assertEqual(a["state"]["companions.optional_recruits"], ["mad_joe"])
        self.assertEqual(b["state"]["companions.optional_recruits"], [])
        self.assertNotIn("joe_accepted", [e["id"] for e in b["proposed_events"]])

    def test_optional_visits_can_happen_in_either_order(self):
        a = self.packet("enter_courtyard", "visit_tavern", "remember_veteran", "visit_prison", "accept_joe", "visit_lord")
        b = self.packet("enter_courtyard", "visit_prison", "accept_joe", "visit_tavern", "remember_veteran", "visit_lord")
        self.assertEqual(a["state"], b["state"])
        self.assertEqual(a["knowledge"], b["knowledge"])
        self.assertNotEqual(a["history"], b["history"])

    def test_hidden_visit_cannot_repeat(self):
        with self.assertRaisesRegex(ValueError, "unavailable"):
            self.packet("enter_courtyard", "visit_tavern", "remember_veteran", "visit_tavern")

    def test_knowledge_requirement(self):
        self.continuity["contracts"]["audience"]["knowledge_required"] = [{"character_id": "protagonist", "fact_id": "veteran_story"}]
        with self.assertRaisesRegex(ValueError, "lacks knowledge"):
            self.packet("enter_courtyard", "visit_lord")
        self.packet("enter_courtyard", "visit_tavern", "remember_veteran", "visit_lord")

    def test_forbidden_mutation(self):
        self.continuity["contracts"]["prison"]["allowed_state_changes"] = []
        with self.assertRaisesRegex(ValueError, "undeclared state mutation"):
            self.packet()

    def test_postcondition(self):
        self.continuity["contracts"]["arrival"]["after"] = False
        with self.assertRaisesRegex(ValueError, "postcondition"):
            self.packet("enter_courtyard")

    def test_required_block_hidden(self):
        self.story["nodes"][0]["blocks"][0]["when"] = False
        with self.assertRaisesRegex(ValueError, "required block hidden"):
            self.packet()

    def test_event_prerequisite(self):
        self.continuity["event_templates"][0]["requires_events"] = ["heard_veteran"]
        with self.assertRaisesRegex(ValueError, "before its prerequisite"):
            self.packet("enter_courtyard")

    def test_changed_fact_marks_dependent_scenes(self):
        self.canon["facts"][1]["revision"] += 1
        result = self.packet()
        self.assertTrue(any("tavern" in issue for issue in result["needs_review"]))
        self.assertTrue(any("audience" in issue for issue in result["needs_review"]))

    def test_unattributed_testimony(self):
        self.canon["facts"][1]["attributed_to"] = None
        with self.assertRaisesRegex(ValueError, "must name its owner"):
            self.packet()

    def test_approval_pins_content(self):
        self.story["meta"]["status"] = "approved"
        review = self.continuity["review"]
        review.update(status="approved", issues=[], approved_story_revision=1, approved_canon_revision=1)
        for event in self.continuity["event_templates"]: event["approval"] = "approved"
        review["approved_input_hashes"] = input_hashes(self.story, self.continuity, self.canon)
        # Isolate the hash gate; the real outline must also pass source completeness.
        with patch("story_continuity.validate_story"):
            validate(self.story, self.continuity, self.canon)
            self.story["nodes"][0]["blocks"][0]["text"] += " changed"
            with self.assertRaisesRegex(ValueError, "input content changed"):
                validate(self.story, self.continuity, self.canon)

    def test_story_revision(self):
        self.story["meta"]["revision"] += 1
        with self.assertRaisesRegex(ValueError, "story revision changed"):
            self.packet()

    def test_boundary_preserves_story_memory_not_local_visit(self):
        result = self.packet("enter_courtyard", "visit_prison", "accept_joe", "visit_lord", "trust_lord")
        handoff = result["handoff_packet"]
        self.assertEqual(handoff["state"]["companions.optional_recruits"], ["mad_joe"])
        self.assertNotIn("event.prison_visited", handoff["state"])
        self.assertIn("prisoner_testimony", handoff["knowledge"]["protagonist"])
        self.assertTrue(handoff["provisional"])

    def test_fresh_clone_without_generated_catalog(self):
        from validate_story_authoring import validate as validate_authoring
        with patch("validate_story_authoring.CATALOG") as catalog:
            catalog.exists.return_value = False
            self.assertEqual(validate_authoring(self.story)["nodes"], 6)


if __name__ == "__main__": unittest.main()

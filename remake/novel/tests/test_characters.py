import copy
import unittest

from characters import load_characters, validate_registry
from materials import load_materials
from story_continuity import CANON, DEFAULT, context, input_hashes, read, validate


class CharacterReferenceTest(unittest.TestCase):
    def setUp(self):
        self.profiles = load_characters()

    def test_roster_includes_ten_initial_candidates(self):
        characters = self.profiles["characters"]
        self.assertEqual(len(characters), 24)
        self.assertEqual(sum(c["kind"] == "initial_candidate" for c in characters.values()), 10)
        self.assertEqual(characters["initial_merlin"]["canonical_name"]["value"], "Merlin")

    def test_source_name_cannot_change_silently(self):
        self.profiles["characters"]["mad_joe"]["canonical_name"]["value"] = "Joe Smith"
        with self.assertRaisesRegex(ValueError, "source character name changed"):
            validate_registry(self.profiles)

    def test_authored_trait_cannot_become_source_fact(self):
        profile = self.profiles["characters"]["protagonist"]
        trait = copy.deepcopy(profile["writing"]["traits"][0])
        trait["status"] = "confirmed"
        profile["source_facts"].append(trait)
        with self.assertRaisesRegex(ValueError, "source facts cannot contain"):
            validate_registry(self.profiles)

    def test_relationship_must_point_to_known_character(self):
        self.profiles["characters"]["lord_ahn"]["relationships"][0]["target"] = "missing"
        with self.assertRaisesRegex(ValueError, "unknown relationship"):
            validate_registry(self.profiles)

    def test_approved_character_cannot_have_proposed_traits(self):
        self.profiles["characters"]["protagonist"]["writing"]["status"] = "approved"
        with self.assertRaisesRegex(ValueError, "unresolved proposals"):
            validate_registry(self.profiles)

    def test_changed_personality_marks_dependent_scenes(self):
        story, canon = read(DEFAULT), read(CANON)
        continuity = read(DEFAULT.with_name("prologue.continuity.json"))
        self.profiles["characters"]["mad_joe"]["revision"] += 1
        self.profiles["revision"] += 1
        result = context(story, continuity, canon, [], self.profiles)
        self.assertTrue(any("prison: character mad_joe changed" in item for item in result["needs_review"]))
        self.assertTrue(any("audience: character mad_joe changed" in item for item in result["needs_review"]))
        self.assertFalse(any("tavern: character" in item for item in result["needs_review"]))

    def test_absent_character_cannot_speak(self):
        story, canon = read(DEFAULT), read(CANON)
        continuity = read(DEFAULT.with_name("prologue.continuity.json"))
        story["nodes"][1]["blocks"][0]["speaker"] = "mad_joe"
        with self.assertRaisesRegex(ValueError, "speaker absent"):
            context(story, continuity, canon, ["enter_courtyard"], self.profiles)

    def test_identity_registry_is_part_of_approval_fingerprint(self):
        story, canon = read(DEFAULT), read(CANON)
        continuity = read(DEFAULT.with_name("prologue.continuity.json"))
        before = input_hashes(story, continuity, canon, self.profiles)
        self.profiles["characters"]["protagonist"]["writing"]["traits"][0]["value"] = "수정한 성향 후보"
        after = input_hashes(story, continuity, canon, self.profiles)
        self.assertNotEqual(before["characters"], after["characters"])


if __name__ == "__main__": unittest.main()

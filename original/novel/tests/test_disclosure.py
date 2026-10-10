import copy
import json
import unittest

import jsonschema
from characters import load_characters, validate_registry
from disclosure import project_character, public_ids, remap_ids
from story_continuity import CANON, DEFAULT, context, input_hashes, read, validate


class DisclosureTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.master = load_characters()

    def project(self,key,*events):
        return project_character(self.master,key,events)

    def test_original_relationship_pairs_and_reverse_directions(self):
        p = self.master["characters"]
        child = next(r for r in p["jr_antares"]["relationships"] if r["relation_type"]=="child")
        parent = next(r for r in p["red_antares"]["relationships"] if r["relation_type"]=="parent")
        self.assertEqual((child["target"],parent["target"]),("red_antares","jr_antares"))
        self.assertEqual(child["claimant"],"jr_antares")
        self.assertEqual(child["truth_type"],"testimony")

    def test_master_contains_35_analyzed_relationships_and_48_directed_links(self):
        links = [r for p in self.master["characters"].values() for r in p["relationships"]]
        self.assertEqual(len(links),48)
        self.assertEqual(len([r for r in links if not r["id"].endswith(":reverse")]),35)

    def test_named_marriage_has_an_unnamed_spouse_card(self):
        spouse = self.master["characters"]["hunter_spouse"]
        self.assertIsNone(spouse["canonical_name"]["value"])
        self.assertIsNone(spouse["biography"]["gender"]["value"])
        relation = spouse["relationships"][0]
        self.assertEqual(relation["target"],"lore_hunter")
        self.assertEqual(relation["truth_type"],"testimony")

    def test_friendship_is_attributed_not_unconditional_world_truth(self):
        relation = next(r for r in self.master["characters"]["lord_ahn"]["relationships"] if r["id"]=="reported_friendship")
        self.assertEqual(relation["claimant"],"prisoner")
        self.assertEqual(relation["truth_type"],"testimony")
        self.assertEqual(relation["disclosure"]["spoiler"],"major")

    def test_prophecy_answer_is_hidden_in_all_duplicate_card_locations(self):
        for key in ("protagonist","lord_ahn","ancient_evil"):
            text = json.dumps(self.project(key,"castle_arrival","lord_briefing"),ensure_ascii=False)
            self.assertNotIn("prophecy_testimony",text)
            self.assertNotIn("창조했다고",text)
            self.assertNotIn('"relation_type": "creator"',text)
            self.assertNotIn("original_statement",text)
            self.assertNotIn("source_excerpts\": [{",text)

    def test_hints_do_not_include_secret_relation_id_target_or_type(self):
        view = self.project("protagonist","castle_arrival")
        self.assertEqual(view["relationships"],[])
        self.assertTrue(view["foreshadowing"])
        hint = json.dumps(view["foreshadowing"],ensure_ascii=False)
        for word in ("ancient_evil","created_by","protagonist_creation","world_prophecy","창조"):
            self.assertNotIn(word,hint)
        self.assertTrue(view["foreshadowing"][0]["metadata"]["addition"])

    def test_disclosure_releases_only_that_relation_not_future_events(self):
        view = self.project("lord_ahn","prisoner_account")
        relations = {r["id"] for r in view["relationships"]}
        self.assertIn("reported_friendship",relations)
        self.assertNotIn("prophecy_balance",relations)
        self.assertNotIn("joint_guides",relations)
        self.assertEqual(view["source_excerpts"],[])

    def test_released_prophecy_retains_document_claim_and_no_free_knowledge(self):
        view = self.project("protagonist","world_prophecy")
        relation = next(r for r in view["relationships"] if r["relation_type"]=="created_by")
        self.assertEqual(relation["truth_type"],"document_claim")
        self.assertFalse(relation["metadata"]["addition"])
        self.assertTrue(any(f["field"]=="prophecy_testimony" for f in view["source_facts"]))
        packet = context(read(DEFAULT),read(DEFAULT.with_name("prologue.continuity.json")),read(CANON),["enter_courtyard"])
        self.assertEqual(packet["knowledge"]["protagonist"],[])

    def test_fake_identity_does_not_leak_through_id_title_template_or_notes(self):
        events = ["illusion_encounter"]
        ids = public_ids(self.master,events)
        packet = remap_ids({"false_necromancer":self.project("false_necromancer",*events)},ids)
        self.assertEqual(list(packet),["fortress_mage"])
        text = json.dumps(packet,ensure_ascii=False)
        for word in ("false_necromancer","사칭자","사칭했","enemy_70","ArchiDraconian","숨이 끊어"):
            self.assertNotIn(word,text)
        self.assertEqual(packet["fortress_mage"]["display_name"],"네크로맨서")

    def test_false_identity_becomes_visible_after_actual_reveal(self):
        view = self.project("false_necromancer","fortress_identity_revealed")
        self.assertIn("사칭자",view["display_name"])
        self.assertTrue(view["relationships"])
        self.assertEqual(view["relationships"][0]["target"],"necromancer")

    def test_custom_hidden_real_name_cannot_bypass_display_name_policy(self):
        master = copy.deepcopy(self.master)
        d = master["characters"]["necromancer"]["disclosure"]
        d.update(public_id="mystery_traveler",public_display_name="낯선 여행자")
        view = project_character(master,"necromancer")
        self.assertIsNone(view["original_name"])
        self.assertIsNone(view["korean_name"])

    def test_spouse_handle_and_title_do_not_reveal_marriage_early(self):
        view = self.project("hunter_spouse")
        self.assertEqual(public_ids(self.master,[])["hunter_spouse"],"lastditch_resident")
        self.assertNotIn("남편",json.dumps(view,ensure_ascii=False))
        self.assertNotIn("배우자",view["display_name"])

    def test_joe_can_foreshadow_without_disclosing_departure(self):
        view = self.project("mad_joe","joe_request")
        text = json.dumps(view,ensure_ascii=False)
        for word in ("joe_departure","conditional_departure","도망","도주","배신"):
            self.assertNotIn(word,text)
        self.assertTrue(view["foreshadowing"])

    def test_conditional_companion_is_not_unconditional_membership(self):
        relation = next(r for r in self.project("mad_joe","joe_request")["relationships"] if r["id"]=="joe_offer")
        self.assertIn("수락한 경로",relation["branch_condition"])
        departed = self.project("mad_joe","prison_guard_confrontation")
        self.assertTrue(any(r["id"]=="joe_departure" and "player[6]" in r["branch_condition"] for r in departed["relationships"]))

    def test_gorgon_coappearance_does_not_invent_mythological_siblings(self):
        relation = self.master["characters"]["stheno"]["relationships"][0]
        self.assertEqual(relation["relation_type"],"battle_companion")
        self.assertIn("추가하지 않는다",relation["description"])

    def test_undefined_checkpoints_are_errors_not_implicit_publication(self):
        with self.assertRaisesRegex(ValueError,"unknown disclosure"):
            self.project("lord_ahn","chapter_999")
        master = copy.deepcopy(self.master)
        master["characters"]["lord_ahn"]["relationships"][0]["disclosure"]["after_events"]=["missing"]
        with self.assertRaisesRegex(ValueError,"unknown disclosure"):
            validate_registry(master)

    def test_missing_spoiler_policy_and_missing_claimant_are_rejected(self):
        master = copy.deepcopy(self.master)
        del master["characters"]["lord_ahn"]["relationships"][0]["disclosure"]
        with self.assertRaises(jsonschema.ValidationError):
            validate_registry(master)
        master = copy.deepcopy(self.master)
        master["characters"]["jr_antares"]["relationships"][0]["claimant"]=None
        with self.assertRaisesRegex(ValueError,"testimony needs claimant"):
            validate_registry(master)

    def test_public_alias_collision_and_invalid_milestone_are_rejected(self):
        master = copy.deepcopy(self.master)
        master["characters"]["false_necromancer"]["disclosure"]["public_id"]="lord_ahn"
        with self.assertRaisesRegex(ValueError,"public character ID"):
            validate_registry(master)
        master = copy.deepcopy(self.master)
        master["disclosure_checkpoints"]["world_prophecy"]["value"]["milestone_id"]="nonexistent"
        with self.assertRaisesRegex(ValueError,"checkpoint milestone"):
            validate_registry(master)

    def test_unknown_new_source_fields_are_sealed_by_default(self):
        master = copy.deepcopy(self.master)
        profile = master["characters"]["mad_joe"]
        profile["source_facts"].append(dict(copy.deepcopy(profile["source_facts"][0]),field="future_secret",value="새 비밀"))
        self.assertNotIn("새 비밀",json.dumps(project_character(master,"mad_joe",["joe_request"]),ensure_ascii=False))

    def test_ordinary_context_contains_only_occurred_disclosures(self):
        story, canon = read(DEFAULT),read(CANON)
        continuity = read(DEFAULT.with_name("prologue.continuity.json"))
        direct = context(story,continuity,canon,["enter_courtyard","visit_lord"])
        self.assertEqual(direct["disclosed_events"],["castle_arrival"])
        self.assertTrue(direct["disclosures_are_provisional"])
        self.assertEqual(direct["character_profiles"]["lord_ahn"]["relationships"],[])
        self.assertNotIn("hunter_spouse",direct["knowledge"])
        self.assertNotIn("false_necromancer",json.dumps(direct,ensure_ascii=False))
        accepted = context(story,continuity,canon,["enter_courtyard","visit_prison","accept_joe","visit_lord"])
        self.assertIn("joe_request",accepted["disclosed_events"])
        self.assertNotIn("prisoner_account",accepted["disclosed_events"])

    def test_reveal_cannot_attach_to_unrelated_event_without_source_evidence(self):
        story, canon = read(DEFAULT),read(CANON)
        continuity = read(DEFAULT.with_name("prologue.continuity.json"))
        continuity["event_templates"][0]["reveals"].append("world_prophecy")
        with self.assertRaisesRegex(ValueError,"lacks checkpoint source"):
            validate(story,continuity,canon)

    def test_policy_edit_invalidates_approval_hash(self):
        story, canon = read(DEFAULT),read(CANON)
        continuity = read(DEFAULT.with_name("prologue.continuity.json"))
        before = input_hashes(story,continuity,canon,self.master)
        changed = copy.deepcopy(self.master)
        changed["characters"]["lord_ahn"]["relationships"][0]["disclosure"]["after_events"]=["world_prophecy"]
        after = input_hashes(story,continuity,canon,changed)
        self.assertNotEqual(before["characters"],after["characters"])


if __name__=="__main__": unittest.main()

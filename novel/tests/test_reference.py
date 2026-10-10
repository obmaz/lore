import copy
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import jsonschema
from characters import load_characters, validate_registry
from materials import ROOT, read
from reference import load_references, validate_catalog
from story_continuity import CANON, DEFAULT, context, input_hashes


class AuthorReferenceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.profiles = load_characters()
        cls.refs = load_references()

    def test_korean_names_are_phonetic_separate_labels(self):
        cards = self.profiles["characters"]
        self.assertEqual(cards["necromancer"]["canonical_name"]["value"], "Necromancer")
        self.assertEqual(cards["necromancer"]["korean_name"]["value"], "네크로맨서")
        self.assertEqual(cards["skeleton"]["korean_name"]["value"], "스켈레톤")
        self.assertEqual(cards["skeleton"]["korean_name"]["metadata"]["kind"], "transliteration")

    def test_missing_ages_are_not_invented_from_levels(self):
        for p in self.profiles["characters"].values():
            age = p["biography"]["age"]
            self.assertIsNone(age["value"])
            self.assertEqual(age["origin"], "unknown")
            self.assertEqual(set(p["biography"]), {"age","gender","species","occupation","appearance","alignment"})

    def test_source_classes_and_gender_are_preserved(self):
        cards = self.profiles["characters"]
        self.assertEqual(cards["spica"]["biography"]["gender"]["value"], "female")
        self.assertEqual(cards["spica"]["biography"]["occupation"]["value"], "에스퍼 / 수도자")
        self.assertEqual(cards["initial_merlin"]["biography"]["occupation"]["value"], "마법사")

    def test_personality_analysis_is_not_an_original_fact(self):
        trait = self.profiles["characters"]["lore_hunter"]["writing"]["traits"][-1]
        self.assertEqual((trait["origin"],trait["status"]), ("inferred","proposed"))
        self.assertTrue(trait["metadata"]["addition"])
        self.assertTrue(trait["evidence"])

    def test_prophecy_is_preserved_without_automatic_character_knowledge(self):
        for key in ("protagonist","lord_ahn","ancient_evil"):
            claims = [c for c in self.profiles["characters"][key]["source_facts"] if c["field"]=="prophecy_testimony"]
            self.assertEqual(len(claims),1)
            self.assertIn("예언서",claims[0]["value"])
            self.assertEqual(claims[0]["metadata"]["knowledge_policy"],"author_reference_not_character_knowledge")
        packet = context(read(DEFAULT),read(DEFAULT.with_name("prologue.continuity.json")),read(CANON),[],self.profiles)
        self.assertNotIn("prophecy_testimony",packet["knowledge"]["protagonist"])

    def test_missing_addition_metadata_fails_schema(self):
        profiles = copy.deepcopy(self.profiles)
        del profiles["characters"]["protagonist"]["writing"]["traits"][0]["metadata"]
        with self.assertRaises(jsonschema.ValidationError):
            validate_registry(profiles)

    def test_added_age_cannot_hide_as_unknown_or_transliteration(self):
        profiles = copy.deepcopy(self.profiles)
        age = profiles["characters"]["protagonist"]["biography"]["age"]
        age["value"] = 25
        with self.assertRaisesRegex(ValueError,"unknown must remain"):
            validate_registry(profiles)
        age.update(origin="authored",status="confirmed")
        age["metadata"].update(addition=True,kind="transliteration",note="고유 설정")
        with self.assertRaisesRegex(ValueError,"only for Korean name"):
            validate_registry(profiles)
        age.update(status="proposed")
        age["metadata"]["kind"] = "new_setting"
        validate_registry(profiles)

    def test_fake_and_real_necromancer_are_distinct(self):
        cards = self.profiles["characters"]
        self.assertEqual(cards["false_necromancer"]["resource_refs"]["enemy_templates"],["enemy_70"])
        self.assertEqual(cards["necromancer"]["resource_refs"]["enemy_templates"],["enemy_75"])
        fake = next(c["value"] for c in cards["false_necromancer"]["source_facts"] if c["field"]=="story_role")
        real = next(c["value"] for c in cards["necromancer"]["source_facts"] if c["field"]=="story_role")
        self.assertIn("죽는다",fake)
        self.assertIn("탈출",real)
        self.assertIn("사망으로 단정하지 않는다",real)

    def test_template_aliases_do_not_merge_characters(self):
        self.assertEqual(self.profiles["characters"]["sphinx"]["resource_refs"]["enemy_templates"],["enemy_35"])
        self.assertEqual(self.refs["bestiary"]["items"]["enemy_35"]["original_name"]["value"],"Sprite")
        self.assertEqual(self.profiles["characters"]["hidra"]["canonical_name"]["value"],"Hidra")
        self.assertEqual(self.refs["bestiary"]["items"]["enemy_49"]["original_name"]["value"],"Hydra")

    def test_complete_catalog_counts(self):
        self.assertEqual({k:len(v["items"]) for k,v in self.refs.items()}, {"equipment":24,"abilities":45,"bestiary":75})
        self.assertEqual(sum(p["kind"]=="initial_candidate" for p in self.profiles["characters"].values()),14)

    def test_original_enemy_bytes_can_be_reconstructed_without_game(self):
        data = read(ROOT / "materials/enemy_templates.json")
        raw = b"".join(bytes.fromhex(r["original_record_hex"]) for r in data["records"])
        self.assertEqual(len(raw),75*29)
        self.assertEqual(hashlib.sha256(raw).hexdigest(),data["sha256"])
        fields = ["strength","mentality","endurance","resistance","agility","accuracy_arms","accuracy_magic","armor_class","special","cast_level","special_cast_level","level"]
        for r in data["records"]:
            record = bytes.fromhex(r["original_record_hex"])
            self.assertEqual(record[1:1+record[0]].decode("ascii"),r["name"])
            self.assertEqual(dict(zip(fields,record[17:])),r["fields"])

    def test_original_stats_and_names_cannot_silently_change(self):
        document = copy.deepcopy(self.refs["bestiary"])
        document["items"]["enemy_19"]["claims"][0]["value"]["level"] = 99
        with self.assertRaisesRegex(ValueError,"parameters changed"):
            validate_catalog(document)
        document = copy.deepcopy(self.refs["bestiary"])
        document["items"]["enemy_19"]["original_name"]["value"] = "Skeleton King"
        with self.assertRaisesRegex(ValueError,"name changed"):
            validate_catalog(document)

    def test_field_magic_costs_are_source_backed(self):
        items = self.refs["abilities"]["items"]
        costs = [next(c["value"] for c in items[f"magic_{i}"]["claims"] if c["field"]=="sp_cost") for i in range(33,41)]
        self.assertEqual(costs,[1,5,10,20,25,30,50,30])
        self.assertEqual(items["magic_33"]["original_name"]["value"],"마법의 햇불")

    def test_weapon_name_does_not_invent_fire_damage(self):
        flame = self.refs["equipment"]["items"]["weapon_9"]
        self.assertEqual(next(c["value"] for c in flame["claims"] if c["field"]=="base_weapon_power"),50)
        self.assertIsNone(next(c["value"] for c in flame["claims"] if c["field"]=="elemental_effect"))

    def test_reference_documents_are_in_approval_hash_and_context(self):
        story, canon = read(DEFAULT),read(CANON)
        continuity = read(DEFAULT.with_name("prologue.continuity.json"))
        self.assertIn("references",input_hashes(story,continuity,canon,self.profiles))
        packet = context(story,continuity,canon,["enter_courtyard","visit_prison","accept_joe","visit_lord"],self.profiles)
        self.assertIn("weapon_0",packet["writing_references"]["equipment"])
        self.assertNotIn("enemy_75",packet["writing_references"]["bestiary"])

    def test_reference_change_invalidates_content_fingerprint(self):
        story, canon = read(DEFAULT),read(CANON)
        continuity = read(DEFAULT.with_name("prologue.continuity.json"))
        before = input_hashes(story,continuity,canon,self.profiles)
        changed = copy.deepcopy(self.refs)
        changed["equipment"]["items"]["weapon_9"]["claims"].append({"value":"검토할 새 창작 효과"})
        with patch("story_continuity.load_references",return_value=changed):
            after = input_hashes(story,continuity,canon,self.profiles)
        self.assertNotEqual(before["references"],after["references"])

    def test_gold_treasure_names_are_not_new_magic_items(self):
        items = self.refs["equipment"]["items"]
        for key, label in (("shield_5","황금의 방패"),("armor_5","황금의 갑옷")):
            names = [c for c in items[key]["claims"] if c["field"]=="script_display_name"]
            self.assertEqual(names[0]["value"],label)
            self.assertEqual(names[0]["origin"],"source_exact")
            self.assertFalse(names[0]["metadata"]["addition"])


class GeneratedReferenceTest(unittest.TestCase):
    def test_standalone_regeneration_is_idempotent_and_protects_manual_edits(self):
        with tempfile.TemporaryDirectory(prefix="lore-reference-") as temp:
            root = Path(temp)/"novel"
            shutil.copytree(ROOT,root,ignore=shutil.ignore_patterns("__pycache__","*.pyc"))
            env = dict(os.environ)
            env.pop("PYTHONPATH",None)
            paths = read(root/"reference/generated_manifest.json")["artifacts"]
            before = {p:(root/p).read_bytes() for p in paths}
            run = lambda: subprocess.run([sys.executable,"tools/build_reference.py"],cwd=root,env=env,capture_output=True,text=True)
            result = run()
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertEqual(before,{p:(root/p).read_bytes() for p in paths})
            target = root/"reference/equipment.json"
            target.write_bytes(target.read_bytes()+b" ")
            edited = target.read_bytes()
            result = run()
            self.assertNotEqual(result.returncode,0)
            self.assertIn("refusing overwrite",result.stderr)
            self.assertEqual(target.read_bytes(),edited)


if __name__ == "__main__": unittest.main()

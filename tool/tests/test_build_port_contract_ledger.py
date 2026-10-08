"""Guard the baseline's scope without treating registration as parity proof."""

import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import build_port_contract_ledger as ledger


class ContractLedgerTest(unittest.TestCase):
    def test_creation_rule_verification_excludes_input_and_palette_loops(self):
        sites = ledger.build()["control_sites"]
        closed = [s for s in sites if "test/source_creation_rules_test.dart"
                  in s["behavioral_evidence"]]
        self.assertEqual(len(closed), 46)
        self.assertTrue(all(s["verification_status"] == "verified" for s in closed))
        self.assertTrue(all(
            (s["routine"] == "LORECRET.PAS:erase:1" and 215 <= s["line"] <= 359)
            or (s["routine"] == "LORECRET.PAS:third:1" and 478 <= s["line"] <= 515)
            for s in closed))
        untouched = [s for s in sites if s["routine"] == "LORECRET.PAS:erase:1"
                     and s["line"] in {206, 390, 394}]
        self.assertEqual(len(untouched), 3)
        self.assertTrue(all(s["verification_status"] == "partial" for s in untouched))

    def test_all_original_and_port_resources_are_registered(self):
        data = ledger.build()
        self.assertEqual(len(data["source_files"]), 14)
        self.assertEqual(len(data["source_catalog"]), 25)
        self.assertEqual(len(data["map_registry"]), 27)
        self.assertEqual(len(data["runtime_assets"]), 50)
        self.assertEqual(
            len({site["inventory_id"] for site in data["control_sites"]}),
            len(data["control_sites"]),
        )
        self.assertTrue(all(site["routine"] != "<program-or-unit-init>"
                            for site in data["control_sites"]))

    def test_dynamic_entries_and_prior_evidence_remain_visible(self):
        data = ledger.build()
        writes = data["map_writes"]
        self.assertTrue(any(w["file"] == "LORESPEC.PAS" and
                            w["index"] == "i,12" and w["value"] == "54"
                            for w in writes))
        self.assertTrue(any(w["file"] == "LORESPEC.PAS" and
                            w["index"] == "25,27" and w["value"] == "54"
                            for w in writes))
        evidence = data["existing_evidence"]
        self.assertTrue(any(e["path"] == "test/portal_reconciliation_test.dart"
                            for e in evidence))
        self.assertTrue(any(e["path"] == "test/fixtures/source_entrance_replay.json"
                            and e["test_users"] for e in evidence))
        linked = [site for site in data["control_sites"]
                  if site["behavioral_evidence"]]
        self.assertEqual(len(linked), 1848)
        self.assertEqual(data["baseline_gaps"]["unmapped_behavior_sites"], 0)
        self.assertEqual(data["baseline_gaps"]["unverified_behavior_sites"], 420)
        self.assertTrue(all(site["verification_status"] in {"partial", "verified"}
                            for site in linked))
        linked_cases = {site["id"] for site in linked if site["kind"] == "case"}
        self.assertLessEqual(
            {f"LOREMAIN.PAS:main:1:case:{number}" for number in range(3, 7)},
            linked_cases,
        )
        reviewed = json.loads(ledger.EVIDENCE.read_text(encoding="utf-8"))
        supplemental_routines = {
            "LORECRET.PAS:erase:1", "LORECRET.PAS:fourth:1",
            "LORECRET.PAS:third:1", "LORECRET.PAS:second:1",
            "LORECRET.PAS:name:1", "LORECRET.PAS:whatclass:1",
            "LORECRET.PAS:which:1", "LORECRET.PAS:profile:1",
            "LORECRET.PAS:createcharacter:1",
            "LOREENT.PAS:entermode:1", "LOREENT.PAS:sign:1",
            "LORESUB.PAS:simplediscond:1",
            "LORESUB.PAS:display_condition:1",
            "LORESUB.PAS:displaycondition:1",
            "LORESUB.PAS:displayhp:1", "LORESUB.PAS:displaysp:1",
            "LORESUB.PAS:displayesp:1",
        }
        supplemental_files = {
            "LORE.PAS", "LORECRET.PAS", "LOREHELP.PAS", "LORESPEC.PAS",
            "LOREMAIN.PAS", "LORETALK.PAS", "LORESUB.PAS",
        }
        supplemental_ids = {
            site["id"] for site in linked
            if site["file"] in supplemental_files or
            site["routine"] in supplemental_routines
        }
        self.assertEqual(
            linked_cases - supplemental_ids,
            ({row["id"] for row in reviewed["contracts"] if row["kind"] == "case"}
             - supplemental_ids),
        )
        self.assertTrue(all(
            site["port_handler"] and site["reviewed_scope"]
            for site in linked
        ))
        supplemental = {
            site["id"] for site in linked
            if site["routine"] in {
                "LORECRET.PAS:erase:1", "LOREENT.PAS:entermode:1",
                "LORESUB.PAS:simplediscond:1",
            }
        }
        self.assertTrue(supplemental)
        self.assertTrue(all(site["verification_status"] in {"partial", "verified"}
                            for site in linked
                            if site["id"] in supplemental))

    def test_evidence_link_rejects_source_line_drift(self):
        rows = json.loads(ledger.EVIDENCE.read_text(encoding="utf-8"))
        rows["contracts"][0]["line"] += 1
        _, sites, _ = ledger.source_contracts(ledger.inventory())
        with tempfile.TemporaryDirectory() as directory:
            candidate = Path(directory) / "evidence.json"
            candidate.write_text(json.dumps(rows), encoding="utf-8")
            with patch.object(ledger, "EVIDENCE", candidate):
                with self.assertRaisesRegex(ValueError, "source moved"):
                    ledger.link_contract_evidence(sites)

    def test_enemy_magic_target_verification_is_limited_to_closed_dispatch(self):
        data = ledger.build()
        targets = [site for site in data["control_sites"]
                   if "test/source_enemy_magic_target_test.dart" in
                   site["behavioral_evidence"]]
        self.assertEqual(len(targets), 19)
        self.assertTrue(all(site["routine"] == "LOREBATT.PAS:castattack:1"
                            and 688 <= site["line"] <= 719
                            for site in targets))
        self.assertTrue(all(site["verification_status"] == "verified"
                            for site in targets))

    def test_seeded_enemy_ai_verification_excludes_effect_continuations(self):
        data = ledger.build()
        targets = [site for site in data["control_sites"]
                   if "test/enemy_ai_dispatch_dos_test.dart" in
                   site["behavioral_evidence"] and site["kind"] != "case"]
        self.assertEqual(len(targets), 43)
        closed = [site for site in targets
                  if site["line"] not in {758, 772, 781, 783, 786, 797}]
        self.assertEqual(len(closed), 36)
        self.assertTrue(all(site["verification_status"] == "verified" for site in closed))
        for site in targets:
            if site in closed:
                continue
            effect_test = ("test/enemy_armor_effects_dos_test.dart"
                           if site["line"] in {781, 783, 786}
                           else "test/enemy_cure_continuation_dos_test.dart")
            self.assertIn(effect_test, site["behavioral_evidence"])
            self.assertEqual(site["verification_status"], "verified")
        self.assertTrue(all(site["routine"] == "LOREBATT.PAS:castattack:1"
                            and 724 <= site["line"] <= 815 for site in targets))

    def test_castattack_selector_does_not_promote_unrelated_battle_effects(self):
        sites = ledger.build()["control_sites"]
        selector = [s for s in sites if s["routine"] == "LOREBATT.PAS:castattack:1"]
        self.assertEqual(len(selector), 63)
        self.assertTrue(all(s["verification_status"] == "verified" for s in selector))
        effects = [s for s in sites if s["routine"] in
                   {"LOREBATT.PAS:specialcastattack:1", "LOREBATT.PAS:battleesp:1"}]
        self.assertTrue(effects)
        self.assertTrue(all(s["verification_status"] == "partial" for s in effects))

    def test_native_special_and_spell_scope_is_exactly_42_contracts(self):
        sites = ledger.build()["control_sites"]
        special = [s for s in sites if "test/enemy_special_attack_dos_test.dart"
                   in s["behavioral_evidence"]]
        spells = [s for s in sites if "test/enemy_spell_dispatch_dos_test.dart"
                  in s["behavioral_evidence"]]
        self.assertEqual(len(special), 39)
        self.assertEqual(len(spells), 3)
        self.assertTrue(all(s["routine"] == "LOREBATT.PAS:specialattack:1" for s in special))
        self.assertTrue(all(s["routine"] in {"LOREBATT.PAS:castattackone:1",
                                             "LOREBATT.PAS:castattackall:1"} for s in spells))
        self.assertTrue(all(s["verification_status"] == "verified" for s in special + spells))

    def test_supporting_evidence_is_retained_without_promoting_verification(self):
        rows = json.loads(ledger.EVIDENCE.read_text(encoding="utf-8"))
        row = rows["contracts"][0]
        row["supporting_evidence"] = ["tool/check_dos_final_completion.py"]
        _, sites, _ = ledger.source_contracts(ledger.inventory())
        with tempfile.TemporaryDirectory() as directory:
            candidate = Path(directory) / "evidence.json"
            candidate.write_text(json.dumps(rows), encoding="utf-8")
            with patch.object(ledger, "EVIDENCE", candidate):
                ledger.link_contract_evidence(sites)
        site = next(site for site in sites if site["id"] == row["id"])
        self.assertEqual(site["behavioral_evidence"],
                         [row["test"], "tool/check_dos_final_completion.py"])
        self.assertEqual(site["verification_status"], row["verification"])

    def test_missing_supporting_evidence_is_rejected(self):
        rows = json.loads(ledger.EVIDENCE.read_text(encoding="utf-8"))
        rows["contracts"][0]["supporting_evidence"] = ["missing/native.json"]
        _, sites, _ = ledger.source_contracts(ledger.inventory())
        with tempfile.TemporaryDirectory() as directory:
            candidate = Path(directory) / "evidence.json"
            candidate.write_text(json.dumps(rows), encoding="utf-8")
            with patch.object(ledger, "EVIDENCE", candidate):
                with self.assertRaisesRegex(ValueError, "Supporting contract evidence"):
                    ledger.link_contract_evidence(sites)


if __name__ == "__main__":
    unittest.main()

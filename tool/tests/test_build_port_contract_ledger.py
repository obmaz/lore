"""Guard the baseline's scope without treating registration as parity proof."""

import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import build_port_contract_ledger as ledger


class ContractLedgerTest(unittest.TestCase):
    def test_typed_read_scope_is_only_enemy_and_default_map_loops(self):
        sites = ledger.build()['control_sites']
        reviewed = json.loads(ledger.EVIDENCE.read_text())['contracts']
        for test, expected in {
            'test/setall_enemy_read_dos_test.dart': ('LORESUB.PAS:set_all:1', 1804),
            'test/map_reads_dos_test.dart': ('LORESUB.PAS:load:1', 1712),
        }.items():
            ids = {r['id'] for r in reviewed if r.get('test') == test
                   and r.get('verification') == 'verified'}
            actual = [s for s in sites if s['id'] in ids]
            self.assertEqual(len(actual), 1)
            self.assertEqual((actual[0]['routine'], actual[0]['line']), expected)
        map_note = next(r['note'] for r in reviewed if r.get('test') == 'test/map_reads_dos_test.dart')
        self.assertIn('FormatException', map_note)
        self.assertIn('not invalid-memory byte equivalence', map_note)

    def test_load_record_error_scope_closes_only_required_record_failures(self):
        sites = ledger.build()['control_sites']
        evidence = json.loads(ledger.EVIDENCE.read_text())['contracts']
        ids = {r['id'] for r in evidence if r.get('test') ==
               'test/load_record_errors_dos_test.dart' and r.get('verification') == 'verified'}
        actual = [s for s in sites if s['id'] in ids]
        self.assertEqual(len(actual), 2)
        self.assertEqual({(s['routine'], s['line']) for s in actual},
                         {('LORESUB.PAS:load:1', 1661), ('LORESUB.PAS:load:1', 1666)})
        note = next(r['note'] for r in evidence if r['id'] in ids)
        self.assertIn('not partial DOS pre-Halt memory writes', note)
        self.assertIn('not truncated DOS IO', note)

    def test_load_font_error_scope_does_not_close_party_player_or_bgi(self):
        sites = ledger.build()['control_sites']
        evidence = json.loads(ledger.EVIDENCE.read_text())['contracts']
        ids = {r['id'] for r in evidence if r.get('test') ==
               'test/load_font_errors_dos_test.dart' and r.get('verification') == 'verified'}
        actual = [s for s in sites if s['id'] in ids]
        self.assertEqual(len(actual), 2)
        self.assertEqual({(s['routine'], s['line']) for s in actual},
                         {('LORESUB.PAS:load:1', 1671), ('LORESUB.PAS:load:1', 1752)})

    def test_saved_header_scope_keeps_legacy_and_invalid_memory_adapters_explicit(self):
        sites = ledger.build()['control_sites']
        evidence = json.loads(ledger.EVIDENCE.read_text())['contracts']
        closed = {r['id'] for r in evidence if r.get('test') ==
                  'test/saved_map_header_test.dart' and r.get('verification') == 'verified'}
        self.assertEqual([(s['routine'], s['line']) for s in sites if s['id'] in closed],
                         [('LORESUB.PAS:load:1', 1675)])
        note = next(r['note'] for r in evidence if r['id'] in closed)
        self.assertIn('legacy base-dimension adapter', note)
        self.assertIn('not invalid-memory equivalence', note)

    def test_load_phases_scope_is_only_successful_cold_warm_initialization(self):
        sites = ledger.build()['control_sites']
        evidence = json.loads(ledger.EVIDENCE.read_text())['contracts']
        closed = {r['id'] for r in evidence if r.get('test') ==
                  'test/load_phases_dos_test.dart' and r.get('verification') == 'verified'}
        self.assertEqual([(s['routine'], s['line']) for s in sites if s['id'] in closed],
                         [('LORESUB.PAS:load:1', 1655)])
        note = next(r['note'] for r in evidence if r['id'] in closed)
        self.assertIn('Legacy headerless saves require canonical base dimensions', note)

    def test_load_error_scope_is_only_need_message_not_file_io(self):
        sites = ledger.build()['control_sites']
        reviewed = json.loads(ledger.EVIDENCE.read_text())['contracts']
        closed = {r['id'] for r in reviewed if r.get('test') ==
                  'test/load_errors_dos_test.dart' and r.get('verification') == 'verified'}
        actual = [s for s in sites if s['id'] in closed]
        self.assertEqual(len(actual), 1)
        self.assertEqual((actual[0]['routine'], actual[0]['line']),
                         ('LORESUB.PAS:load:1', 1650))

    def test_detect_game_over_scope_is_only_six_slot_loop(self):
        sites = ledger.build()['control_sites']
        reviewed = json.loads(ledger.EVIDENCE.read_text())['contracts']
        closed = {r['id'] for r in reviewed if r.get('test') ==
                  'test/detect_game_over_dos_test.dart' and r.get('verification') == 'verified'}
        actual = [s for s in sites if s['id'] in closed]
        self.assertEqual(len(actual), 1)
        self.assertEqual((actual[0]['routine'], actual[0]['line']),
                         ('LORESUB.PAS:detectgameover:1', 553))
        self.assertEqual(actual[0]['verification_status'], 'verified')

    def test_training_word_scope_preserves_uninitialized_local_policy(self):
        sites = ledger.build()['control_sites']
        reviewed = json.loads(ledger.EVIDENCE.read_text())['contracts']
        closed = {r['id'] for r in reviewed if r.get('test') ==
                  'test/training_words_dos_test.dart' and r.get('verification') == 'verified'}
        actual = [s for s in sites if s['id'] in closed]
        self.assertEqual(len(actual), 3)
        self.assertEqual({s['line'] for s in actual}, {1359, 1360, 1367})
        self.assertTrue(all(s['routine'] == 'LORESUB.PAS:train_center:1'
                            and s['verification_status'] == 'verified' for s in actual))
        for row in reviewed:
            if row['id'] in closed:
                self.assertIn('StateError', row['note'])
                self.assertIn('uninitialized DOS stack', row['note'])

    def test_return_magic_and_message_keep_explicit_invalid_memory_policy(self):
        sites = ledger.build()['control_sites']
        closed = [s for s in sites if s['routine'] == 'LORESUB.PAS:returnmagic:1'
                  and s['line'] == 729]
        self.assertEqual(len(closed), 1)
        self.assertEqual(closed[0]['verification_status'], 'verified')
        messages = [s for s in sites if s['routine'] == 'LORESUB.PAS:returnmessage:1'
                     and s['line'] == 789]
        self.assertEqual(len(messages), 1)
        self.assertEqual(messages[0]['verification_status'], 'verified')
        reviewed = json.loads(ledger.EVIDENCE.read_text())['contracts']
        note = next(r['note'] for r in reviewed if r['id'] == messages[0]['id'])
        self.assertIn('RangeError', note)
        self.assertIn('StateError', note)
        self.assertIn('No BGI glyph or invalid-memory byte-for-byte equivalence', note)

    def test_remains_blink_scope_is_seven_ordered_presentation_loops(self):
        sites = ledger.build()['control_sites']
        reviewed = json.loads(ledger.EVIDENCE.read_text())['contracts']
        closed = {r['id'] for r in reviewed if r.get('test') ==
                  'test/remains_blink_dos_test.dart' and r.get('verification') == 'verified'}
        self.assertEqual(len(closed), 7)
        actual = [s for s in sites if s['id'] in closed]
        self.assertEqual({s['line'] for s in actual}, {827,873,909,960,1009,1038,1050})
        self.assertTrue(all(s['routine'] == 'LORETALK.PAS:talkmode:1'
                            and s['verification_status'] == 'verified' for s in actual))

    def test_load_state_scope_leaves_file_io_and_bgi_contracts_partial(self):
        sites = ledger.build()['control_sites']
        reviewed = json.loads(ledger.EVIDENCE.read_text())['contracts']
        closed = {r['id'] for r in reviewed if r.get('test') ==
                  'test/load_state_dos_test.dart' and r.get('verification') == 'verified'}
        self.assertEqual(len(closed), 2)
        actual = [s for s in sites if s['id'] in closed]
        self.assertEqual({(s['routine'], s['line']) for s in actual}, {
            ('LORESUB.PAS:load:1', 1729), ('LORESUB.PAS:load:1', 1762)})
        for routine, line in [('LORESUB.PAS:setscrolltype:1', 287),
                              ('LORESUB.PAS:setscrolltype:1', 292)]:
            untouched = [s for s in sites if s['routine'] == routine and s['line'] == line]
            self.assertEqual(len(untouched), 1)
            self.assertEqual(untouched[0]['verification_status'], 'verified')
            self.assertEqual(untouched[0]['behavioral_evidence'][0], 'test/scroll_fill_dos_test.dart')

    def test_final_threshold_batch_has_exact_scope_and_preserves_hardware_gaps(self):
        sites = ledger.build()['control_sites']
        reviewed = json.loads(ledger.EVIDENCE.read_text())['contracts']
        for test, count in {
            'test/battle_commands_dos_test.dart': 8,
            'test/source_battle_flow_ui_test.dart': 10,
            'test/join_bounds_dos_test.dart': 2,
            'test/source_new_game_persistence_test.dart': 3,
            'test/source_special_event_routing_test.dart': 3,
            'test/source_map7_map19_portal_test.dart': 9,
            'test/source_remaining_late_guards_test.dart': 4,
            'test/creation_name_dos_test.dart': 8,
            'test/source_coordinates_dos_test.dart': 2,
            'test/source_enemy_database_test.dart': 1,
            'test/creation_class_queue_dos_test.dart': 1,
            'test/save_party_dos_test.dart': 2,
        }.items():
            ids = {r['id'] for r in reviewed if r.get('test') == test and r.get('verification') == 'verified'}
            self.assertEqual(len(ids), count)
            self.assertTrue(all(s['verification_status'] == 'verified' for s in sites if s['id'] in ids))
        for routine, line in [('LORECRET.PAS:last:1',740)]:
            untouched = [s for s in sites if s['routine'] == routine and s['line'] == line]
            self.assertEqual(len(untouched),1)
            self.assertEqual(untouched[0]['verification_status'],'partial')

        clear = [s for s in sites if s['routine'] == 'LOREBATT.PAS:battlemode:1'
                 and s['line'] == 1027]
        self.assertEqual(len(clear), 1)
        self.assertEqual(clear[0]['verification_status'], 'verified')
        self.assertEqual(clear[0]['behavioral_evidence'][0], 'test/battle_clear_dos_test.dart')

    def test_creation_keyboard_scope_preserves_crt_wait_gaps(self):
        sites = ledger.build()['control_sites']
        expected = {'test/creation_second_dos_test.dart': 9,
                    'test/creation_class_dos_test.dart': 8,
                    'test/companion_selection_dos_test.dart': 14}
        for test, count in expected.items():
            # Behavioral evidence includes supporting UI tests; select contract IDs
            # through reviewed primary evidence instead of counting incidental links.
            reviewed = json.loads(ledger.EVIDENCE.read_text())['contracts']
            ids = {r['id'] for r in reviewed if r.get('test') == test and r.get('verification') == 'verified'}
            closed = [s for s in sites if s['id'] in ids]
            self.assertEqual(len(closed), count)
            self.assertTrue(all(s['verification_status'] == 'verified' for s in closed))
        waiting = [s for s in sites if (s['routine'], s['line']) in {
            ('LORECRET.PAS:second:1', 422),
            ('LORECRET.PAS:fourth:1', 583),
            ('LORECRET.PAS:fourth:1', 604)}]
        self.assertEqual(len(waiting), 3)
        self.assertTrue(all(s['verification_status'] == 'partial' for s in waiting))

    def test_remaining_effect_scope_excludes_unobserved_ui(self):
        sites = ledger.build()['control_sites']
        for test, expected in [('test/source_talk_remaining_effects_test.dart', 7),
                               ('test/enemy_colors_dos_test.dart', 4),
                               ('test/battle_menus_dos_test.dart', 7)]:
            closed = [s for s in sites if s['behavioral_evidence']
                      and test == s['behavioral_evidence'][0]]
            self.assertEqual(len(closed), expected)
            self.assertTrue(all(s['verification_status'] == 'verified' for s in closed))
        untouched = [s for s in sites if s['routine'] == 'LOREBATT.PAS:displayenemies:1'
                     and s['line'] == 79]
        self.assertEqual(len(untouched), 1)
        self.assertEqual(untouched[0]['verification_status'], 'verified')
        self.assertEqual(untouched[0]['behavioral_evidence'][0], 'test/battle_clear_dos_test.dart')
        hardware = [s for s in sites if s['routine'] == 'LORESUB.PAS:scroll:1'
                    and s['line'] == 219]
        self.assertTrue(hardware)
        self.assertTrue(all(s['verification_status'] == 'partial' for s in hardware))

    def test_field_battle_eight_sites_have_independent_primary_scope(self):
        data = ledger.build()
        sites = data['control_sites']
        primary = {
            'test/field_pages_dos_test.dart': 3,
            'test/main_input_gates_dos_test.dart': 2,
            'test/main_tab_palette_dos_test.dart': 1,
            'test/battle_clear_dos_test.dart': 2,
        }
        for path, count in primary.items():
            owned = [s for s in sites if s['behavioral_evidence']
                     and s['behavioral_evidence'][0] == path]
            self.assertEqual(len(owned), count)
            self.assertTrue(all(s['verification_status'] == 'verified' for s in owned))
        self.assertFalse(any(s.get('verification_status') == 'partial'
                             for s in sites if s['file'] in {'LOREMAIN.PAS', 'LOREBATT.PAS'}))
        self.assertEqual(data['baseline_gaps']['unverified_behavior_sites'], 79)

    def test_special_arrival_scope_is_exact(self):
        sites = ledger.build()['control_sites']
        closed = [s for s in sites if s['behavioral_evidence']
                  and s['behavioral_evidence'][0] == 'test/special_arrival_dos_test.dart']
        self.assertEqual(len(closed), 10)
        self.assertTrue(all(s['file'] == 'LORESPEC.PAS'
                            and s['verification_status'] == 'verified' for s in closed))
        self.assertFalse(any(s['verification_status'] == 'partial'
                             for s in sites if s['file'] == 'LORESPEC.PAS'))

    def test_cast_special_native_scope_is_exact(self):
        closed = [s for s in ledger.build()['control_sites']
                  if 'test/cast_special_dos_test.dart' in s['behavioral_evidence']]
        self.assertEqual(len(closed), 47)
        self.assertTrue(all(s['routine'] == 'LOREBATT.PAS:castspecial:1'
                            and s['verification_status'] == 'verified' for s in closed))

    def test_battle_esp_native_scope_is_49_game_state_contracts(self):
        sites = ledger.build()["control_sites"]
        closed = [s for s in sites if "test/battle_esp_dos_test.dart"
                  in s["behavioral_evidence"]]
        self.assertEqual(len(closed), 49)
        self.assertTrue(all(s["routine"] == "LOREBATT.PAS:battleesp:1"
                            and s["verification_status"] == "verified" for s in closed))
        self.assertFalse(any("test/battle_esp_dos_test.dart" in s["behavioral_evidence"]
                             for s in sites if s["routine"] != "LOREBATT.PAS:battleesp:1"))

    def test_specialcast_native_scope_keeps_explicit_unknown_summon_fault(self):
        sites = ledger.build()["control_sites"]
        closed = [s for s in sites if "test/enemy_special_cast_dos_test.dart"
                  in s["behavioral_evidence"] and s['routine'] in {
                      'LOREBATT.PAS:specialcastattack:1',
                      'LORESUB.PAS:turn_mind:1'}]
        self.assertEqual(len(closed), 20)
        self.assertTrue(all(s["verification_status"] == "verified" for s in closed))
        unknown = [s for s in sites if s["routine"] == "LOREBATT.PAS:specialcastattack:1"
                   and s["line"] in {904, 905}]
        self.assertEqual(len(unknown), 2)
        self.assertTrue(all(s["verification_status"] == "verified" for s in unknown))
        reviewed = json.loads(ledger.EVIDENCE.read_text())['contracts']
        for site in unknown:
            row = next(r for r in reviewed if r['id'] == site['id'])
            self.assertEqual(row['test'], 'test/summon_bounds_dos_test.dart')
            self.assertIn('RangeError', row['note'])
            self.assertIn('not adjacent DOS byte equivalence', row['note'])
        findgold = next(s for s in sites if s['routine'] == 'LORESUB.PAS:findgold:1'
                        and s['line'] == 1018)
        self.assertEqual(findgold['verification_status'], 'partial')

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
        self.assertEqual(data["baseline_gaps"]["unverified_behavior_sites"], 79)
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
        effects = [s for s in sites if
                   s["routine"] == "LOREBATT.PAS:specialcastattack:1"
                   and s["line"] in {904, 905}]
        self.assertTrue(effects)
        reviewed = json.loads(ledger.EVIDENCE.read_text())['contracts']
        self.assertTrue(all(next(r for r in reviewed if r['id'] == s['id'])['test']
                            == 'test/summon_bounds_dos_test.dart' for s in effects))

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

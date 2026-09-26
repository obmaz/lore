import unittest

from audit_script_branches import audit, contradictions, effect_summary, false_probes, report


class ScriptBranchAuditTest(unittest.TestCase):
    def test_detects_proven_shadow_and_missing_source_coordinate(self):
        scripts = [
            {"id": "early", "map": 1, "trigger": "step", "x": 4, "y": 5, "steps": [{"say": "first"}]},
            {"id": "later", "map": 1, "trigger": "step", "x": 4, "y": 5, "require": {"flag": "ready"}, "steps": [{"gold": 10}]},
        ]
        _, _, findings = audit(scripts, [], [(1, 12, 4, 5, []), (1, 13, 7, 8, [])], {1: (10, 10)})
        self.assertIn("later ← early", findings["shadowed"][0])
        self.assertEqual(len(findings["missing_source_coordinates"]), 1)
        self.assertIn("(7,8)", findings["missing_source_coordinates"][0])

    def test_flags_disabled_rule_without_active_location(self):
        scripts = [
            {"id": "ported", "map": 1, "trigger": "step", "x": 4, "y": 5, "steps": [{"say": "ok"}]},
            {"id": "unported-candidate", "map": 1, "trigger": "step", "x": 7, "y": 8, "disabled": True, "steps": [{"gold": 10}]},
        ]
        _, _, findings = audit(scripts, [], [], {1: (10, 10)})
        self.assertIn("unported-candidate", findings["disabled_without_cover"][0])

    def test_reconciles_portal_target_but_keeps_guard_and_refusal_separate(self):
        scripts = [
            {"id": "target", "map": 1, "trigger": "step", "x": 5, "y": 6, "disabled": True, "steps": [{"teleport": {"map": 2, "x": 3, "y": 4}}]},
            {"id": "refusal", "map": 1, "trigger": "step", "x": 5, "y": 6, "disabled": True, "steps": [{"nudge": {"dy": -1}}]},
            {"id": "guard", "map": 1, "trigger": "step", "x": 5, "y": 6, "disabled": True, "steps": [{"flag": "done"}, {"block": True}]},
        ]
        portals = [{"map": 1, "x": 5, "y": 6, "targetMap": 2, "targetX": 3, "targetY": 4}]
        _, _, findings = audit(scripts, portals, [], {1: (10, 10)})
        self.assertEqual(len(findings["portal_target_match"]), 1)
        self.assertEqual(len(findings["portal_refusal"]), 1)
        self.assertEqual(len(findings["portal_guard"]), 1)
        self.assertEqual(findings["disabled_without_cover"], [])

    def test_distinguishes_contradiction_from_condition_variant(self):
        self.assertTrue(contradictions({"flag": "a", "flagNot": "a"}))
        self.assertTrue(contradictions({"quest": {"name": "q", "eq": 4, "lt": 4}}))
        scripts = [
            {"id": "portal", "map": 1, "trigger": "portal", "require": {"flag": "a"}, "steps": [{"say": "a"}]},
            {"id": "portal", "map": 1, "trigger": "portal", "require": {"flagNot": "a"}, "steps": [{"say": "b"}]},
        ]
        _, _, findings = audit(scripts, [], [], {1: (10, 10)})
        self.assertEqual(findings["duplicate_ids"], [])
        self.assertEqual(len(findings["shared_ids"]), 1)

    def test_party_member_false_probe(self):
        self.assertIn(
            "Polaris → 현재 파티에서 제외",
            false_probes({"partyMember": "Polaris"}),
        )

    def test_links_battle_victory_escape_and_tile_effects(self):
        summary = effect_summary([
            {"setTile": {"x": 1, "y": 2, "tile": 44}},
            {"battle": {"monsters": [1, 2, 3], "victoryFlag": "won", "onRunAway": [{"nudge": {"dx": 1}}], "victoryIfEnemyDead": 3}},
        ])
        self.assertIn("setTile", summary)
        self.assertIn("승리 플래그", summary)
        self.assertIn("도주 분기", summary)
        self.assertIn("격퇴 슬롯 3", summary)
        self.assertIn("nudge", summary)

    def test_current_assets_generate_all_map_sections(self):
        generated = report()
        self.assertIn("전체 ", generated)
        self.assertIn("/ 활성 ", generated)
        self.assertIn("### 맵 27", generated)
        self.assertIn("oedipus-spear", generated)


if __name__ == "__main__":
    unittest.main()

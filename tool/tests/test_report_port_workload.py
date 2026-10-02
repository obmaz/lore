import unittest

from report_port_workload import (
    battle_evidence,
    classify,
    map_arms,
    routine_for_line,
    routine_starts,
)
from source_branch_inventory import inventory


class PortWorkloadReportTest(unittest.TestCase):
    def test_routine_line_numbers_follow_dos_newlines(self):
        starts = routine_starts("LORESUB.PAS")
        self.assertEqual(routine_for_line(starts, 729), "ReturnMagic")
        self.assertEqual(routine_for_line(starts, 1677), "Load")

    def test_map_arms_cover_source_sites_once(self):
        data = inventory()
        by_file, _, by_map, unattributed = classify(data)
        for filename in ("LORESPEC.PAS", "LORETALK.PAS", "LOREENT.PAS"):
            self.assertEqual(
                sum(count for (name, _), count in by_map.items() if name == filename)
                + unattributed[filename],
                by_file[filename],
            )
        self.assertEqual(len([number for number, _, _ in map_arms("LORESPEC.PAS")
                              if number == 20]), 1)

    def test_battle_evidence_distinguishes_rules_from_scenarios(self):
        entries, ids, referenced, actions = battle_evidence()
        self.assertGreater(len(entries), len(ids))  # Conditional rules reuse IDs.
        self.assertTrue(referenced <= ids)
        self.assertGreater(actions["retreat"], 0)
        self.assertGreater(actions["victory"], 0)


if __name__ == "__main__":
    unittest.main()

import unittest

from audit_loreent import PORTALS, SOURCE, matching_portals, scan_entermode
import json


class LoreEntranceAuditTest(unittest.TestCase):
    def test_original_entrances_match_json_routes(self):
        entrances = scan_entermode(SOURCE.read_text(encoding="utf-8", errors="replace"))
        portals = json.loads(PORTALS.read_text(encoding="utf-8"))["portals"]
        self.assertEqual(len(entrances), 27)
        self.assertEqual(sum(point is not None for _, _, point, *_ in entrances), 16)
        self.assertEqual([entry for entry in entrances if not matching_portals(entry, portals)], [])

    def test_point_and_destination_must_both_match(self):
        entry = (30, 1, (76, 57), 7, 37, 70)
        self.assertEqual(matching_portals(entry, [{"map": 1, "x": 76, "y": 58, "targetMap": 7, "targetX": 37, "targetY": 70}]), [])
        self.assertEqual(matching_portals(entry, [{"map": 1, "x": 76, "y": 57, "targetMap": 7, "targetX": 38, "targetY": 70}]), [])


if __name__ == "__main__":
    unittest.main()

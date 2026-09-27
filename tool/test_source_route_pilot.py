import json
import unittest

import source_route_pilot as pilot


class SourceRoutePilotTest(unittest.TestCase):
    def test_fixture_matches_current_pascal_and_map(self):
        path = pilot.ROOT / 'test/fixtures/map17_route_parity.json'
        recorded = json.loads(path.read_text(encoding='utf-8'))
        self.assertEqual(recorded, pilot.fixture(17))
        self.assertEqual([r['kind'] for r in recorded['rules']], [
            'set_y', 'row_tiles', 'column_and_nudge', 'row_and_teleport',
        ])

    def test_source_out_of_bounds_is_reported_separately(self):
        cases = pilot.fixture(17)['cases']
        exceptions = [case for case in cases if 'safetyNote' in case]
        self.assertEqual(len(exceptions), 1)
        self.assertEqual(exceptions[0]['start'], [72, 80])
        self.assertEqual(exceptions[0]['sourceEnd'], [72, -1])
        self.assertEqual(exceptions[0]['safeEnd'], [72, 6])

    def test_map20_extracts_both_tile_dependent_passages(self):
        path = pilot.ROOT / 'test/fixtures/map20_route_parity.json'
        recorded = json.loads(path.read_text(encoding='utf-8'))
        self.assertEqual(recorded, pilot.fixture(20))
        self.assertEqual(len(recorded['rules']), 2)
        self.assertEqual(len(recorded['cases']), 160)
        for case in recorded['cases']:
            if case['tileAtPlayer'] == 0:
                self.assertEqual(case['sourceMap'], 20)
                self.assertEqual(case['sourceEnd'][0], case['start'][0])
                self.assertEqual(
                    case['sourceEnd'][1], 80 if case['start'][1] == 88 else 63,
                )
            else:
                self.assertEqual((case['sourceMap'], case['sourceEnd']),
                                 (4, [82, 17]))

    def test_map19_lever_keeps_completed_puzzle_terrain(self):
        path = pilot.ROOT / 'test/fixtures/map19_route_parity.json'
        recorded = json.loads(path.read_text(encoding='utf-8'))
        self.assertEqual(recorded, pilot.fixture(19))
        self.assertEqual(len(recorded['cases']), 4)
        active, completed, blocked, blocked_completed = recorded['cases']
        self.assertEqual(len(active['writes']), 6)
        self.assertEqual(active['randomRoomCount'], 7)
        self.assertEqual(completed['writes'], [[41, 41, 39, 39, 49]])
        self.assertEqual(completed['randomRoomCount'], 0)
        self.assertEqual(blocked['writes'], [])
        self.assertEqual(blocked_completed['writes'], [])


if __name__ == '__main__':
    unittest.main()

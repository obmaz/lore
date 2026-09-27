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

    def test_map17_only_replays_specialevent_tiles(self):
        cases = pilot.fixture(17)['cases']
        self.assertEqual(len(cases), 16)
        self.assertFalse(any('safetyNote' in case for case in cases))
        self.assertFalse(any(case['start'] == [72, 80] for case in cases))
        self.assertEqual(
            {tuple(case['start']) for case in cases if case.get('tileAtPlayer') == 52},
            {(67, 38), (68, 38), (69, 38)},
        )

    def test_map20_extracts_both_tile_dependent_passages(self):
        path = pilot.ROOT / 'test/fixtures/map20_route_parity.json'
        recorded = json.loads(path.read_text(encoding='utf-8'))
        self.assertEqual(recorded, pilot.fixture(20))
        self.assertEqual(len(recorded['rules']), 2)
        self.assertEqual(len(recorded['cases']), 8)
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
        self.assertEqual(len(recorded['cases']), 6)
        first_active, first_blocked, active, completed, blocked, blocked_completed = recorded['cases']
        self.assertEqual(first_active['writes'], [
            [11, 11, 40, 40, 49], [41, 41, 39, 39, 0],
        ])
        self.assertEqual(first_blocked['writes'], [])
        self.assertEqual(len(active['writes']), 6)
        self.assertEqual(active['randomRoomCount'], 7)
        self.assertEqual(completed['writes'], [[41, 41, 39, 39, 49]])
        self.assertEqual(completed['randomRoomCount'], 0)
        self.assertEqual(blocked['writes'], [])
        self.assertEqual(blocked_completed['writes'], [])

    def test_map27_special_tiles_bounce_and_exit_stays_at_border(self):
        path = pilot.ROOT / 'test/fixtures/map27_route_parity.json'
        recorded = json.loads(path.read_text(encoding='utf-8'))
        self.assertEqual(recorded, pilot.fixture(27))
        self.assertEqual(len(recorded['cases']), 8)
        for case in recorded['cases']:
            start_y = case['start'][1]
            self.assertEqual(
                case['sourceEnd'][1], start_y + (1 if start_y < 25 else -1),
            )
        exit_x, exit_y, exit_map = recorded['rules'][0]['args']
        portals = json.loads(
            (pilot.ROOT / 'assets/data/portals.json').read_text(encoding='utf-8'),
        )['portals']
        self.assertTrue(any(
            portal['map'] == 27
            and portal.get('yMin') == 50
            and (portal['targetMap'], portal['targetX'], portal['targetY'])
            == (exit_map, exit_x, exit_y)
            for portal in portals
        ))

    def test_map25_side_door_tile_loops_match_pascal(self):
        path = pilot.ROOT / 'test/fixtures/map25_route_parity.json'
        recorded = json.loads(path.read_text(encoding='utf-8'))
        self.assertEqual(recorded, pilot.fixture(25))
        self.assertEqual([r['kind'] for r in recorded['rules']],
                         ['side_door', 'side_door'])
        self.assertEqual([case['start'] for case in recorded['cases']],
                         [[15, 34], [36, 34]])
        self.assertTrue(all(len(case['writes']) == 6 for case in recorded['cases']))

    def test_map23_castle_only_replaces_zero_tiles(self):
        path = pilot.ROOT / 'test/fixtures/map23_route_parity.json'
        recorded = json.loads(path.read_text(encoding='utf-8'))
        self.assertEqual(recorded, pilot.fixture(23))
        self.assertEqual(recorded['rules'][0]['kind'], 'castle_lever')
        case = recorded['cases'][0]
        self.assertEqual(case['start'], [25, 27])
        self.assertEqual(case['tileAtPlayer'], 52)
        self.assertGreater(len(case['writes']), 80)
        self.assertIn([25, 26, 12, 12, 54], case['writes'])


if __name__ == '__main__':
    unittest.main()

import json
import unittest

import source_route_pilot as pilot


class SourceRoutePilotTest(unittest.TestCase):
    def test_fixture_matches_current_pascal_and_map(self):
        recorded = json.loads(pilot.FIXTURE.read_text(encoding='utf-8'))
        self.assertEqual(recorded, pilot.fixture())
        self.assertEqual([r['kind'] for r in recorded['rules']], [
            'set_y', 'row_tiles', 'column_and_nudge', 'row_and_teleport',
        ])

    def test_source_out_of_bounds_is_reported_separately(self):
        cases = pilot.fixture()['cases']
        exceptions = [case for case in cases if 'safetyNote' in case]
        self.assertEqual(len(exceptions), 1)
        self.assertEqual(exceptions[0]['start'], [72, 80])
        self.assertEqual(exceptions[0]['sourceEnd'], [72, -1])
        self.assertEqual(exceptions[0]['safeEnd'], [72, 6])


if __name__ == '__main__':
    unittest.main()

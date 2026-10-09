import json
import unittest

from export_dos_battle_clear import OUT, build


class BattleClearFixtureTest(unittest.TestCase):
    def test_original_conditional_and_backdrop_callbacks(self):
        data = json.loads(OUT.read_text())
        self.assertEqual(data, build())
        self.assertEqual(len(data['commands']), 256)
        for row in data['commands']:
            self.assertEqual(row['events'], [] if row['k'] == 1 else [['Clear', []]])
        self.assertEqual(data['displays'], [
            {'clean': False, 'events': []},
            {'clean': True, 'events': [['SetFillStyle', [1, 0]],
                                      ['Bar', [20, 20, 199, 199]],
                                      ['SetFillStyle', [1, 8]]]},
        ])

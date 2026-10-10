import json
import unittest
from export_dos_field_pages import OUT, build


class FieldPageFixtureTest(unittest.TestCase):
    def test_original_closed_page_branches(self):
        data = json.loads(OUT.read_text())
        self.assertEqual(data, build())
        self.assertEqual(len(data['swamp']), 4096)
        self.assertEqual(len(data['lava']), 48)
        for row in data['swamp'] + data['lava']:
            self.assertEqual(len(row['pages']), 2)
            self.assertEqual([p['page'] for p in row['pages']], [1-row['initialPage'], row['initialPage']])
            self.assertEqual(row['pages'][0]['lines'], row['pages'][1]['lines'])
        for row in data['lava']:
            self.assertEqual(row['clearedBeforeFirstDraw'], [0]*6)
            self.assertTrue(row['scratch7Preserved'])
            self.assertEqual(row['bounds'], [v for luck in row['luck'] for v in [luck, 40]])

import json
import unittest

from export_dos_main_input_gates import OUT, build


class MainInputFixtureTest(unittest.TestCase):
    def test_original_input_boundaries(self):
        data = json.loads(OUT.read_text())
        self.assertEqual(data, build())
        self.assertEqual(data['polls'][0]['result']['events'], ['poll'])
        self.assertEqual(data['polls'][1]['result']['events'], ['poll', 'read'])
        self.assertEqual(len(data['scans']), 2048)
        for row in data['scans']:
            r = row['result']
            self.assertEqual(r['events'], ['read'])
            self.assertEqual(r['ok'], row['scan'] in [72, 75, 77, 80])
            if row['scan'] not in [72, 75, 77, 80]:
                self.assertEqual((r['dx'], r['dy']), (0, 0))
                self.assertEqual(r['face'], 7 if row['mapId'] == 26 else 3)
        for row in data['tabs']:
            self.assertEqual(row['result']['events'], [[16, 0x101b, 0, 255]]
                             if row['byte'] == 9 else [])

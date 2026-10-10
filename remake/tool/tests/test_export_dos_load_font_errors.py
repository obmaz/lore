import json
import unittest
import export_dos_load_font_errors as e


class LoadFontErrorsTest(unittest.TestCase):
    def test_native_error_conditions_and_short_byte_counts(self):
        data = json.loads(e.OUT.read_text())
        self.assertEqual(len(data['cases']), 48)
        failures = 0
        for row in data['cases']:
            selected = {1: 'ground.fnt', 6: 'town.fnt', 14: 'den.fnt', 21: 'keep.fnt'}[row['mapId']]
            failed = row['target'] == selected or (row['target'] == 'chara.fnt' and not row['warm'])
            attempts = [event[1] for event in row['events'] if event[0] == 'openAttempt']
            if failed:
                failures += 1
                self.assertEqual(row['error'], dict(need=False, name=row['target']))
                self.assertEqual(attempts[-1], row['target'])
                self.assertEqual(row['afterLoadFont'], int(row['warm']))
                if row['mode'] == 'truncated':
                    self.assertEqual(row['events'][-1], ['close', row['target'], 13775, 1])
            else:
                self.assertIsNone(row['error'])
                self.assertNotIn(row['target'], attempts)
                self.assertEqual(row['afterLoadFont'], 1)
        self.assertEqual(failures, 24)

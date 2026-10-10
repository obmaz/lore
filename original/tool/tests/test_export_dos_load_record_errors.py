import json
import unittest
import export_dos_load_record_errors as e


class LoadRecordErrorsTest(unittest.TestCase):
    def test_original_slot_labels_need_and_partial_read_counts(self):
        data = json.loads(e.OUT.read_text())
        self.assertEqual(len(data['cases']), 16)
        for row in data['cases']:
            name = row['target']
            self.assertEqual(row['error'], dict(need=True, name=name))
            self.assertEqual(row['afterLoadFont'], 0)
            attempts = [event[1] for event in row['events'] if event[0] == 'openAttempt']
            self.assertEqual(attempts[-1], name)
            if name.startswith('party'):
                self.assertEqual(attempts, [name])
            else:
                self.assertEqual(attempts, [f"party{row['slot']}.dat", name])
            if row['mode'] == 'truncated':
                self.assertEqual(row['events'][-1], ['close', name,
                    107 if name.startswith('party') else 329,
                    1 if name.startswith('party') else 6])

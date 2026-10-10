import json
import unittest
import export_dos_load_phases as e


class LoadPhasesTest(unittest.TestCase):
    def test_complete_load_records_and_resource_choice(self):
        data = json.loads(e.OUT.read_text())
        self.assertEqual(len(data['cases']), 108)
        for row in data['cases']:
            warm = row['warm']
            names = [event[1] for event in row['events'] if event[0] == 'open']
            expected_map = 'save1.map' if row['saved'] and not warm else row['mapName'].lower() + '.map'
            self.assertEqual(names[:-1], ([expected_map] if warm else
                ['party1.dat', 'player1.dat', 'chara.fnt', expected_map]))
            self.assertEqual(names[-1], ['town', 'ground', 'den', 'keep'][row['position']] + '.fnt')
            self.assertEqual(row['afterLoadFont'], 1)
            expected = list(row['beforeParty'] if warm else row['fileParty'])
            expected[14], expected[15] = 2, 5
            self.assertEqual(row['afterParty'], expected)
            self.assertEqual(row['afterPlayers'], data['memoryPlayers'] if warm else
                data['filePlayers'] + data['memoryPlayers'][6:])
            closes = {event[1]: event[2:] for event in row['events'] if event[0] == 'close'}
            if not warm:
                self.assertEqual(closes['party1.dat'], [108, 1])
                self.assertEqual(closes['player1.dat'], [330, 6])
            record = data['mapRecords'][row['mapRecord']]
            reads = record['width'] * record['height'] + 2
            self.assertEqual(closes[expected_map], [reads, reads])

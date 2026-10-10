import hashlib
import json
import unittest
import export_dos_detect_game_over as e

class DetectGameOverTest(unittest.TestCase):
    def test_full_masks_signed_predicates_and_six_slots(self):
        data=json.loads(e.OUT.read_text())
        exe=(e.ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
        self.assertEqual(data['exeSha256'],hashlib.sha256(exe).hexdigest())
        self.assertEqual(len(data['masks']),192)
        self.assertEqual(len(data['predicates']),1500)
        self.assertEqual({r['slot'] for r in data['predicates']},set(range(1,7)))
        for row in data['masks']+data['predicates']:
            self.assertEqual(len(row['records']),6)
            active=any(r['name'] and r['hp']>0 and r['unconscious']==0 and r['dead']==0 for r in row['records'])
            self.assertEqual(row['calls'],[] if active else [255])
            self.assertEqual(row['afterEtc6'],row['etc6'] if active else 255)

import itertools
import json
import unittest

import export_dos_enemy_special_attack as special


class EnemySpecialAttackTest(unittest.TestCase):
    def test_executable_fragments_and_ui_skip_spans(self):
        special.check()

    def test_complete_masks_and_native_equality_boundaries(self):
        rows = json.loads(special.OUT.read_text())['cases']
        keys = [(r['mode'], r['mask'], r['blank'], r['seed'], r['pattern']) for r in rows]
        expected = list(itertools.product([1, 2, 3], range(64), [False, True], special.SEEDS, range(12)))
        expected.extend((m, 63, False, 0, -1) for m in [0, *range(4, 256)])
        self.assertEqual(keys, expected)
        saw_equal = saw_fail = saw_dodge = saw_unchanged_status = False
        for r in rows:
            if r['pattern'] == -1:
                self.assertEqual(r['bounds'], [])
                self.assertEqual(r['events'], [])
                self.assertEqual(r['before'], r['after'])
                self.assertEqual(r['afterSeed'], r['seed'])
                continue
            target = r['events'][0][0]
            self.assertTrue(1 <= target <= 6)
            self.assertEqual(r['events'][0][1], 13)
            rolls = dict(r['rolls'])
            if r['pattern'] == 8:
                self.assertEqual(r['agility'], rolls['agility'])
                self.assertEqual(r['luck'], rolls['luck'])
                self.assertEqual(r['events'][-1][1], 4)
                saw_equal = True
            saw_fail |= 'luck' not in rolls
            saw_dodge |= 'luck' in rolls and r['luck'] > rolls['luck']
            field = {1: 'poison', 2: 'unconscious', 3: 'dead'}[r['mode']]
            if r['events'][-1][1] == 4 and r['before'][target - 1][field] != 0:
                self.assertEqual(r['before'], r['after'])
                saw_unchanged_status = True
            for slot in range(1, 7):
                if slot != target:
                    self.assertEqual(r['before'][slot - 1], r['after'][slot - 1])
        self.assertTrue(all([saw_equal, saw_fail, saw_dodge, saw_unchanged_status]))

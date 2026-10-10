import collections
import itertools
import json
import unittest

import export_dos_enemy_ai_dispatch as ai


class EnemyAiDispatchTest(unittest.TestCase):
    def test_original_executable_and_fragment_hashes(self):
        ai.check()

    def test_complete_unique_inputs_and_decision_outcomes(self):
        data = json.loads(ai.OUT.read_text())
        rows = data['cases']
        expected = [(m, k, b, l, s, 0) for m, k, b, l, s in itertools.product(
            [4, 5, 6], range(64), [False, True], range(len(ai.LAYOUTS)), ai.SEEDS)]
        expected.extend((6, k, True, l, s, a) for k, l, s, a in itertools.product(
            [0, 1, 3, 16, 63], [0, 4], ai.SEEDS, range(1, len(ai.ARMORS))))
        expected.extend((m, 63, False, 0, 0, 0) for m in [0, *range(7, 256)])
        self.assertEqual([(r['mode'], r['mask'], r['blank'], r['layout'],
                           r['seed'], r['armor']) for r in rows], expected)
        effects = collections.defaultdict(set)
        for r in rows:
            effects[r['mode']].add(r['effect'])
            if r['mode'] not in [4, 5, 6]:
                self.assertEqual((r['effect'], r['bounds'], r['afterSeed']),
                                 ('none', [], r['seed']))
            self.assertTrue(all(0 <= b <= 6 for b in r['bounds']))
            self.assertTrue(0 <= r['afterSeed'] <= 0xffffffff)
            if r['effect'] == 'one':
                self.assertTrue(1 <= r['target'] <= 6)
            if r['effect'] == 'self-cure':
                self.assertEqual(r['target'], 1)
            if r['effect'] == 'group-cure':
                self.assertEqual(r['target'], 1)  # first effect boundary only
                self.assertGreater(len(ai.LAYOUTS[r['layout']]), 2)
            if r['effect'] == 'armor-division-zero':
                self.assertEqual((r['mode'], r['mask'], r['blank']), (6, 0, True))
        self.assertEqual(effects[4], {'one', 'all', 'self-cure'})
        self.assertEqual(effects[5], {'one', 'all', 'self-cure', 'group-cure'})
        self.assertEqual(effects[6], {'one', 'all', 'self-cure', 'group-cure',
                                     'armor', 'armor-division-zero'})


if __name__ == '__main__':
    unittest.main()

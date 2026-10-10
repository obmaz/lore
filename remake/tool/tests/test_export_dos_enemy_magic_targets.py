import itertools
import json
import unittest

import export_dos_enemy_magic_targets as targets


class EnemyMagicTargetsTest(unittest.TestCase):
    def test_original_executable_and_fragment_hashes(self):
        targets.check()

    def test_fixture_has_unique_complete_synthetic_inputs(self):
        rows = json.loads(targets.OUT.read_text())['cases']
        keys = [(r['mode'], r['mask'], r['blank'], r['seed']) for r in rows]
        expected = list(itertools.product([1, 2, 3], range(64), [False, True],
                                         [0, 1, 0xdeadbeef, 0xffffffff]))
        self.assertEqual(keys, expected)
        for r in rows:
            self.assertTrue(r['bounds'])
            self.assertTrue(all(0 <= b <= 6 for b in r['bounds']))
            self.assertEqual(r['target'] is None, r['all'])
            if r['all']:
                self.assertEqual(r['mode'], 3)
            else:
                self.assertTrue(1 <= r['target'] <= 6)


if __name__ == '__main__':
    unittest.main()

import json
import unittest

import export_dos_enemy_cure_continuation as cure


class EnemyCureContinuationTest(unittest.TestCase):
    def test_original_executable_fragments_and_ui_skip_boundary(self):
        cure.check()

    def test_complete_cure_iterations_and_status_inputs(self):
        rows = json.loads(cure.OUT.read_text())['cases']
        self.assertEqual(len(rows), 112)
        self.assertEqual({r['mode'] for r in rows}, {4, 5, 6})
        self.assertEqual({r['status'] for r in rows},
                         {'normal', 'dead', 'unconscious', 'mixed'})
        for r in rows:
            n = len(r['before']) if r['effect'] == 'group-cure' else 1
            self.assertEqual([num for num, amount in r['cures']], list(range(1, n + 1)))
            self.assertEqual(len(r['before']), len(r['after']))
            self.assertTrue(all(0 <= b <= 6 for b in r['bounds']))
            for num, amount in r['cures']:
                before, after = r['before'][num - 1], r['after'][num - 1]
                if before['dead']:
                    self.assertEqual(after, dict(hp=before['hp'], dead=False,
                                                unconscious=before['unconscious']))
                elif before['unconscious']:
                    self.assertEqual(after, dict(hp=max(1, before['hp']),
                                                dead=False, unconscious=False))


if __name__ == '__main__':
    unittest.main()

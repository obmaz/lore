import itertools
import json
import unittest

import export_dos_enemy_spell_dispatch as spells


class EnemySpellDispatchTest(unittest.TestCase):
    def test_executable_fragments_and_skip_spans(self):
        spells.check()

    def test_complete_byte_domain_and_six_slot_order(self):
        rows = json.loads(spells.OUT.read_text())['cases']
        self.assertEqual([(r['all'], r['mentality'], r['level']) for r in rows],
                         list(itertools.product([False, True], range(256), spells.LEVELS)))
        for r in rows:
            targets = list(range(1, 7)) if r['all'] else [r['target']]
            self.assertEqual(r['calls'], [[r['factor'] * r['level'], n] for n in targets])
            self.assertTrue(1 <= r['method'] <= (5 if r['all'] else 6))

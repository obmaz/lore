import json
import unittest

import export_dos_enemy_armor_effects as armor


class EnemyArmorEffectsTest(unittest.TestCase):
    def test_original_executable_fragments_and_ui_skip_boundaries(self):
        armor.check()

    def test_luck_equality_and_slot_loop_storage_boundaries(self):
        rows = json.loads(armor.OUT.read_text())['cases']
        self.assertEqual(len(rows), 1064)
        self.assertEqual({r['pattern'] for r in rows}, set(range(8)))
        seen_equal = seen_resist = seen_zero = seen_empty = seen_inactive = False
        for r in rows:
            named = [s for s in range(1, 7)
                     if not r['blank'] or r['mask'] & (1 << (s - 1))]
            self.assertEqual([s for s, _ in r['rolls']], named)
            self.assertEqual(r['bounds'], [5] + [21] * len(named))
            expected = list(r['ac'])
            events = []
            for slot, roll in r['rolls']:
                resist = r['luck'][slot - 1] > roll
                seen_equal |= r['luck'][slot - 1] == roll
                seen_resist |= resist
                seen_zero |= r['ac'][slot - 1] == 0
                seen_inactive |= not bool(r['mask'] & (1 << (slot - 1)))
                events.extend([[slot, 13], [slot, 7 if resist else 5]])
                if not resist and expected[slot - 1] > 0:
                    expected[slot - 1] -= 1
            seen_empty |= len(named) < 6
            self.assertEqual(r['messages'], events)
            self.assertEqual(r['afterAc'], expected)
        self.assertTrue(all([seen_equal, seen_resist, seen_zero, seen_empty, seen_inactive]))


if __name__ == '__main__':
    unittest.main()

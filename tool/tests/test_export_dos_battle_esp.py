import json
import sys
import unittest
from unittest.mock import patch
import export_dos_battle_esp as evidence


class NativeBattleEspTest(unittest.TestCase):
    def test_original_executable_fragments_sets_and_database(self):
        with patch.object(sys, 'argv', ['export', '--check']):
            evidence.main()

    def test_input_and_effect_scope_is_complete(self):
        data = json.loads(evidence.OUT.read_text())
        rows = data['cases']
        self.assertEqual(len(rows), 90110)
        self.assertEqual(len(rows), sum(1 for _ in evidence.configurations()))
        self.assertEqual({r['level'] for r in rows}, set(range(256)))
        self.assertEqual({r['action'] for r in rows}, set(range(256)))
        self.assertEqual({r['enemyId'] for r in rows}, set(range(256)))
        self.assertEqual({r['cls'] for r in rows}, set(range(11)))
        self.assertEqual({r['status'] for r in rows}, set(range(5)))
        effects = {k for row in rows for k in row['k']}
        self.assertLessEqual(set(range(1, 19)), effects)
        self.assertTrue(any(k > 18 for k in effects))
        self.assertTrue(any(r['bounds'] == [0] for r in rows))
        colors = {color for row in rows for color in row['colors']}
        self.assertLessEqual({7, 10, 11, 14, 'condition'}, colors)
        # Original group death branch awards using the selected target,
        # not the loop victim; the conscious selected target makes it actor-only.
        self.assertTrue(any(r['count'] == 7 and r['status'] == 1
                            and r['k'] and 7 <= r['k'][0] <= 10
                            and [c[2] for c in r['calls'] if c[0] == 'xp']
                            == [1, 7, 3, 7, 5, 7, 7] for r in rows))
        self.assertTrue(any(r['person'] == 6 and c[0] == 'join'
                            for r in rows for c in r['calls']))
        edges = data['conditionalEdges']
        # Both sides of fear resistance/endurance clamps, heart HP=10,
        # illusion agility clamp, and looped accuracy decrement guards.
        for offset in [0x22761, 0x227ab, 0x22957, 0x229eb, 0x22a47]:
            self.assertEqual(len(edges[hex(offset)]), 2, hex(offset))

    def test_raw_records_retain_signed_and_wrapped_state(self):
        data = json.loads(evidence.OUT.read_text())
        import struct
        xp = [struct.unpack_from('<i', bytes(r), 45)[0] for r in data['partyRecords']]
        hp = [struct.unpack_from('<h', bytes(r), 30)[0] for r in data['enemyRecords']]
        self.assertIn(-2147483648, xp)
        self.assertIn(2147483600, xp)
        self.assertTrue(any(-2147483648 < n < -2147480000 for n in xp))
        self.assertIn(-32768, hp)
        self.assertIn(32767, hp)

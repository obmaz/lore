import json
import unittest
import export_dos_enemy_special_cast as evidence


class NativeSpecialCastTest(unittest.TestCase):
    def test_original_instruction_and_database_provenance(self):
        import sys
        from unittest.mock import patch
        with patch.object(sys, 'argv', ['export', '--check']):
            evidence.main()

    def test_native_scope_and_call_continuations(self):
        data = json.loads(evidence.OUT.read_text())
        rows = data['cases']
        self.assertEqual(len(rows), 40551)
        self.assertEqual({r['count'] for r in rows}, set(range(1, 8)))
        self.assertEqual({r['mode'] for r in rows}, set(range(256)))
        self.assertTrue(any(r['afterCount'] > r['count'] for r in rows))
        self.assertTrue(any(c[0] == 'mind' and c[1] == 7
                            for r in rows for c in r['calls']))
        self.assertTrue(any(c[0] == 'summon' for r in rows for c in r['calls']))
        self.assertTrue(any(e[0] == 4 for r in rows for e in r['events']))
        self.assertTrue(any(e[0] == 7 for r in rows for e in r['events']))
        for row in rows:
            if row['foeId'] == 1:
                self.assertEqual(row['bounds'], [])
                self.assertEqual(row['beforeEnemy'], row['afterEnemy'])
                self.assertEqual(row['beforeParty'], row['afterParty'])
            for call in row['calls']:
                if call[0] == 'mind':
                    self.assertEqual(call[2], 6)
                    self.assertIn(['condition', 0], row['events'])

    def test_interning_is_lossless_and_idempotent(self):
        data = {'cases': [{'beforeEnemy': [[0] * 35], 'afterEnemy': [[0] * 35],
                           'beforeParty': [[0] * 55], 'afterParty': [[1] * 55]}]}
        compacted = evidence.compact(data)
        self.assertEqual(compacted['cases'][0]['beforeEnemy'], [0])
        self.assertEqual(compacted['cases'][0]['afterEnemy'], [0])
        self.assertEqual(compacted['partyRecords'][1], [1] * 55)
        self.assertIs(evidence.compact(compacted), compacted)

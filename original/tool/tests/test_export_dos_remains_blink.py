import hashlib
import json
import unittest

import export_dos_remains_blink as e


class RemainsBlinkTest(unittest.TestCase):
    def test_native_loop_fingerprints_and_final_write_order(self):
        data = json.loads(e.OUT.read_text())
        exe = (e.ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
        self.assertEqual(data['exeSha256'], hashlib.sha256(exe).hexdigest())
        self.assertEqual(data['fragments'], [dict(line=l, start=a, end=z,
            sha256=hashlib.sha256(exe[a:z]).hexdigest()) for l, _, _, a, z in e.SPANS])
        self.assertEqual(len(data['cases']), 98)
        self.assertEqual({r['line'] for r in data['cases']}, {r[0] for r in e.SPANS})
        for row in data['cases']:
            trace = row['trace']
            self.assertEqual(len(trace), 121)
            self.assertEqual(trace[-1], ['write', 35])
            self.assertEqual(sum(t[1] for t in trace if t[0] == 'delay'), 1860)
            self.assertEqual([t[3] for t in trace if t[0] == 'draw'], [48, 35] * 30)
            self.assertTrue(all(t[4] == 0 for t in trace if t[0] == 'draw'))

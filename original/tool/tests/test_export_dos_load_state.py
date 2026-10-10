import hashlib
import json
import unittest

import export_dos_load_state as exporter


class LoadStateTest(unittest.TestCase):
    def test_native_fingerprints_selectors_and_retained_normal_pattern(self):
        data = json.loads(exporter.OUT.read_text())
        exe = (exporter.ROOT / 'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
        self.assertEqual(data['scope'], exporter.__doc__)
        self.assertEqual(data['exeSha256'], hashlib.sha256(exe).hexdigest())
        self.assertEqual(data['fragments'], [dict(name=n, start=a, end=z,
            sha256=hashlib.sha256(exe[a:z]).hexdigest()) for n, a, z in exporter.SPANS])
        self.assertEqual(len(data['resources']), 256)
        self.assertEqual({r['map'] for r in data['resources']}, set(range(256)))
        self.assertEqual({r['font'] for r in data['resources']}, {'town', 'ground', 'den', 'keep'})
        self.assertTrue(all(r['quitPlay'] == 1 for r in data['resources']))
        self.assertEqual(len(data['weather']), 1536)
        self.assertEqual({r['raw'] for r in data['weather']}, set(range(256)))
        for row in data['weather']:
            if row['raw'] not in range(1, 6):
                self.assertEqual(row['mode'], 0)
                self.assertEqual(row['etc12'], 0)
                self.assertEqual(row['after'], row['before'][:2] + [0])
            else:
                self.assertEqual(row['mode'], row['raw'])
                self.assertEqual(row['etc12'], row['raw'])
                self.assertEqual(row['after'][2], 2)

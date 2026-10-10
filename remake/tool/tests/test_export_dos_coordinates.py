import hashlib
import json
import unittest

import export_dos_coordinates as exporter

class CoordinatesTest(unittest.TestCase):
    def test_native_fingerprint_boundary_axes_and_true_false_outcomes(self):
        data = json.loads(exporter.OUT.read_text())
        exe = (exporter.ROOT/'repo_source/LORE_1993_runtime/LORE.EXE').read_bytes()
        self.assertEqual(data['exeSha256'],hashlib.sha256(exe).hexdigest())
        self.assertEqual(data['fragments'],[dict(name=n,start=a,end=z,sha256=hashlib.sha256(exe[a:z]).hexdigest()) for n,a,z in exporter.SPANS])
        for name in ['at','on']:
            self.assertEqual(len(data[name]),1764)
            self.assertEqual({r[0] for r in data[name]},set(exporter.VALUES))
            self.assertEqual(sum(r[-1] for r in data[name]),196)
        self.assertTrue(any(r[0]+r[2]>32767 and r[-1] for r in data['at']))
        self.assertTrue(any(r[1]+r[3]<-32768 and r[-1] for r in data['at']))

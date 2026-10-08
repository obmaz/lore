import json
import unittest
import export_dos_summon_bounds as e

class SummonBoundsTest(unittest.TestCase):
    def test_native_defined_and_synthetic_invalid_reads(self):
        data=json.loads(e.OUT.read_text())
        self.assertEqual(len(data['cases']),32)
        for row in data['cases']:
            self.assertEqual(row['bounds'],[3,3,4])
            self.assertEqual(row['afterCount'],min(row['count']+1,7))
            self.assertEqual(row['beforeRead'],row['before'])
            if row['call'][1]==0:
                target=row['after'][row['call'][0]-1]
                self.assertEqual(bytes(target[2:2+target[1]]).decode('ascii'),row['marker'])
                self.assertEqual(target[0],0)

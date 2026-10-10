import json
import unittest
from export_dos_creation_palette import build, OUT


class CreationPaletteTests(unittest.TestCase):
    def test_original_loops_and_waits_reproduce_all_fixture_cases(self):
        data=build()
        self.assertEqual(data,json.loads(OUT.read_text()))
        self.assertEqual(len(data['cases']),60)
        for row in data['cases']:
            if 'Pulse' in row['kind'] or 'Wait' in row['kind']:
                ready=[v[1] for v in row['trace'] if v[0]=='ready']
                self.assertEqual(ready,[False]*row['falsePolls']+[True])


if __name__=='__main__':unittest.main()

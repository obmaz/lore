import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import export_load_facing as facing


class LoadFacingTest(unittest.TestCase):
    def test_shared_filename_keeps_distinct_source_map_classes(self):
        data = facing.fixture()
        rows = {(r['map'], r['y']): r for r in data['cases']}
        self.assertEqual(len(data['cases']), 135)
        self.assertEqual({r['map'] for r in data['cases']}, set(range(1, 28)))
        for i in [24, 27]:
            r = next(r for r in data['cases'] if r['map'] == i)
            self.assertEqual((r['category'], r['face']), ('town', 0))
        self.assertEqual(rows[25, 1]['name'], rows[26, 1]['name'])
        self.assertEqual(rows[25, 1]['category'], 'den')
        self.assertEqual(rows[26, 1]['category'], 'town')
        self.assertEqual(rows[26, 24]['face'], 4)
        self.assertEqual(rows[26, 25]['face'], 5)

    def test_source_expression_drift_is_rejected(self):
        source = facing.SOURCE.read_bytes().replace(b'ymax div 2 > y', b'ymax div 2 >= y')
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'LORESUB.PAS'
            path.write_bytes(source)
            with patch.object(facing, 'SOURCE', path):
                with self.assertRaises(AssertionError):
                    facing.fixture()


if __name__ == '__main__':
    unittest.main()

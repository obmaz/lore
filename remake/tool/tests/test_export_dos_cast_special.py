import json
import unittest
from export_dos_cast_special import OUT, configurations, main
from unittest.mock import patch


class CastSpecialNativeTest(unittest.TestCase):
    def test_original_fingerprints(self):
        with patch('sys.argv', ['export_dos_cast_special', '--check']):
            main()

    def test_all_numeric_jumps_take_both_paths(self):
        data = json.loads(OUT.read_text())
        # Case dispatch alternatives are separately covered by every action byte.
        dispatch = {'0x218af', '0x2197f', '0x21a4f', '0x21b62', '0x21c63', '0x21d6d'}
        edges = data['conditionalEdges']
        self.assertGreater(len(edges), 25)
        self.assertTrue(all(len(nexts) == 2 for addr, nexts in edges.items()
                            if addr not in dispatch), edges)

    def test_configuration_scope(self):
        rows = list(configurations())
        self.assertEqual({r['action'] for r in rows}, set(range(256)))
        for field in ['resistance', 'accuracy', 'ac', 'level', 'cast', 'specialCast']:
            self.assertEqual({r[field] for r in rows if field in r}, set(range(256)))


if __name__ == '__main__': unittest.main()

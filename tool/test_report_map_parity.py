import unittest

import report_map_parity


class MapParityReportTest(unittest.TestCase):
    def test_all_original_maps_are_listed_without_completion_claims(self):
        rows = report_map_parity.collect()
        self.assertEqual([row['map'] for row in rows], list(range(1, 28)))
        text = report_map_parity.render(rows)
        self.assertEqual(text, report_map_parity.OUTPUT.read_text())
        self.assertNotIn('완료 |', text)


if __name__ == '__main__':
    unittest.main()

import json
import unittest

import export_map1_food


class Map1FoodTest(unittest.TestCase):
    def test_source_food_cache_is_current(self):
        expected = export_map1_food.fixture()
        saved = json.loads(export_map1_food.OUTPUT.read_text())
        self.assertEqual(saved, expected)
        self.assertEqual(len(expected['cases']), 32)
        self.assertEqual({(case['x'], case['y']) for case in expected['cases']}, {(42, 84)})


if __name__ == '__main__':
    unittest.main()

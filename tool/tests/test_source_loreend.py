import json
import unittest

import source_loreend as end


class LoreEndSourceTest(unittest.TestCase):
    def test_current_source_matches_recorded_fixture(self):
        recorded = json.loads(end.OUTPUT.read_text(encoding='utf-8'))
        self.assertEqual(recorded, end.fixture())
        self.assertEqual(len(recorded['message']['lines']), 11)
        self.assertEqual(recorded['walkerFrames'][:4], [[2, 24], [4, 21], [6, 24], [8, 20]])

    def test_fade_table_uses_pascal_integer_division(self):
        contract = end.fixture()
        table = contract['fade']['table']
        # color 6 at adder 150: g = 21 + 150*2 div 15 = 41, b = 150 div 5 = 30
        self.assertEqual(table['150'][6], [52, 41, 30])
        self.assertEqual(table['0'][1], [0, 0, 42])
        self.assertEqual(table['310'][14], [62, 62, 62])

    def test_changed_layout_fails(self):
        _, source = end.load_source()
        changed = source.replace('delay(200);', 'delay(100);', 1)
        self.assertNotEqual(changed, source)
        self.assertEqual(end.extract(changed)['walker']['delayMs'], 100)
        broken = source.replace('until ok;\n   if AdLibOn', 'until FALSE;\n   if AdLibOn', 1)
        with self.assertRaises(ValueError):
            end.extract(broken)

    def test_walker_cycle_repeats(self):
        contract = end.fixture()
        frames = end.walker_frames(contract, 24)
        sprites = [j for _, j in frames]
        self.assertEqual(sprites[:8], [24, 21, 24, 20, 24, 21, 24, 20])
        self.assertEqual(sprites[:4], sprites[4:8])

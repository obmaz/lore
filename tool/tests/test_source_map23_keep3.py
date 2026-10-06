import json
import unittest

import source_map23_keep3 as keep3


class Map23Keep3SourceTest(unittest.TestCase):
    def test_current_source_matches_recorded_replay(self):
        recorded = json.loads(keep3.OUTPUT.read_text(encoding='utf-8'))
        self.assertEqual(recorded, keep3.fixture())
        self.assertEqual(recorded['impostorMonster'], 70)
        self.assertEqual(recorded['mirrorCount'], 6)
        self.assertEqual(recorded['mirrorEmptySlotMonster'], 60)
        self.assertEqual(recorded['greetingSuffix'], '.')
        self.assertEqual(recorded['clearedFlags'], 0)
        self.assertEqual(recorded['randomCalls'], 0)

    def test_escape_and_defeat_never_reach_victory_writes(self):
        contract = keep3.fixture()
        for results in ([255], [1, 255], [0, 255], [0, 1], [0, 254], [1, 0, 1]):
            events = keep3.replay(contract, results)
            self.assertFalse([e for e in events if e.startswith('write:')], results)
            self.assertNotIn('scene:victory', events)
        self.assertEqual(keep3.replay(contract, [0, 3])[-1], 'nudge:0,1')
        self.assertEqual(keep3.replay(contract, [0, 255])[-1], 'battle:duel:255')

    def test_mirror_fight_repeats_until_a_decisive_result(self):
        contract = keep3.fixture()
        events = keep3.replay(contract, [1, 2, 3, 0, 0])
        self.assertEqual(events.count('scene:retry'), 3)
        self.assertEqual(events.count('scene:duel'), 1)
        self.assertEqual(events[-1], 'scene:end')

    def test_changed_guards_and_unmodeled_random_fail(self):
        _, source = keep3.load_source()
        changed = source.replace('if map[x,y] = 0 then exit;\n              Clear;\n              if y = 46',
                                 'if map[x,y] = 52 then exit;\n              Clear;\n              if y = 46', 1)
        self.assertNotEqual(source, changed)
        with self.assertRaisesRegex(ValueError, 'tile guard'):
            keep3.extract(changed)
        changed = source.replace('if party.etc[6] > 0 then begin\n                       Clear;',
                                 'if party.etc[6] >= 0 then begin\n                       Clear;', 1)
        self.assertNotEqual(source, changed)
        with self.assertRaisesRegex(ValueError, 'Unsupported map 23 source'):
            keep3.extract(changed)
        changed = source.replace('if y = 26 then begin', 'if y = 26 then begin random(2);', 1)
        with self.assertRaisesRegex(ValueError, 'random-call model'):
            keep3.extract(changed)

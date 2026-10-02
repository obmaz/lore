import json
import unittest

import source_map25_guardian as guardian


class Map25GuardianSourceTest(unittest.TestCase):
    def test_current_source_matches_recorded_replay(self):
        recorded = json.loads(guardian.OUTPUT.read_text(encoding='utf-8'))
        self.assertEqual(recorded, guardian.fixture())
        self.assertEqual(recorded['battleMonsters'], [66, 66, 66, 66, 71])
        self.assertEqual(recorded['guideActors'], [68, 67])
        self.assertEqual(recorded['promotionSlots'], [1, 2, 3, 4, 5, 6])
        self.assertEqual(recorded['randomCalls'], 0)

    def test_nonzero_results_exit_without_rewards(self):
        contract = guardian.fixture()
        for result in range(1, 256):
            state = guardian.replay(contract, 255, result)
            self.assertEqual(state['afterTorch'], 255)
            self.assertEqual(state['writes'], [])
            self.assertIsNone(state['promotionClass'])
            self.assertEqual(state['nudge'], [0, 0] if result == 255 else [0, 1])

    def test_changed_guard_and_unmodeled_random_fail(self):
        source = guardian.SOURCE.read_bytes().decode('johab')
        changed = source.replace('if party.etc[6] > 0 then begin', 'if party.etc[6] >= 0 then begin')
        with self.assertRaisesRegex(ValueError, 'Unsupported map 25 source'):
            guardian.extract(changed)
        changed = source.replace('if y = 43 then begin', 'if y = 43 then begin random(2);')
        with self.assertRaisesRegex(ValueError, 'random-call model'):
            guardian.extract(changed)

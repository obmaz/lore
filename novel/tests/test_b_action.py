"""Action prose must still obey the common route; not a literary-quality score."""
import unittest

from materials import ROOT, read
import test_prose_series


class BActionRevisionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        test_prose_series.ProseSeriesTests.setUpClass()
        cls.routes = test_prose_series.ProseSeriesTests()
        cls.review = read(ROOT/'writing/variants/B/copyedit-review.json')['passes'][-1]
        cls.blocks = {b['id']: b for n in cls.routes.web['nodes'] for b in n['blocks']}

    def test_revision_records_actual_scope_and_four_phases_per_chapter(self):
        review = self.review
        self.assertEqual(review['id'], 'action-developmental-edit-05')
        self.assertEqual(review['style_revision'], 3)
        self.assertFalse(review['policy']['A_authored_prose_changed'])
        self.assertFalse(review['policy']['common_source_scripts_changed'])
        self.assertFalse(review['policy']['choices_or_effects_changed'])
        self.assertFalse(review['policy']['literary_or_canon_approval'])
        for chapter, arc in review['chapter_arcs'].items():
            self.assertEqual([p['phase'] for p in arc], ['기', '승', '전', '결'])
            keys = [x['block_id'] for x in review['changes'] if x['file'].endswith(chapter+'.json')]
            self.assertEqual(len(keys), review['changed_blocks'][chapter])
            self.assertEqual(len(keys), len(set(keys)))
            for key in keys:
                self.assertEqual(self.blocks[key]['provenance']['origin'], 'authored')
                self.assertIn('교정 5:', self.blocks[key]['provenance']['note'])
        self.assertEqual(review['changed_blocks']['chapter02'], 77)
        self.assertEqual(review['changed_blocks']['chapter03'], 70)

    def test_all_rescue_outcomes_and_both_combat_approaches_keep_their_payoffs(self):
        for rescue in ('aid_rigel', 'join_rigel', 'leave_rigel'):
            for armed in (False, True):
                with self.subTest(rescue=rescue, armed=armed):
                    _, packet = self.routes.walk(polaris=armed, spear='protagonist' if armed else None,
                                                tactic='separate_pressure' if armed else 'hold_together', rescue=rescue)
                    self.assertTrue(packet['main_story']['complete'])
                    self.assertEqual(len(packet['main_story']['seen_scenes']), 43)
                    seen = {b for h in packet['history'] for b in h['visible_block_ids']}
                    self.assertEqual('lastditch_pyramid/battle_spear_protagonist' in seen, armed)
                    self.assertEqual('lastditch_pyramid/battle_weapon_polaris' in seen, armed)
                    self.assertEqual('lastditch_pyramid/hold_body' in seen, not armed)
                    self.assertEqual('lastditch_pyramid/separate_body' in seen, armed)
                    expected = {'aid_rigel':'aided', 'join_rigel':'joined', 'leave_rigel':'left'}[rescue]
                    for outcome in ('aided', 'joined', 'left'):
                        self.assertEqual('gaia_evil_seal/'+outcome+'_body' in seen, outcome==expected)
                        self.assertEqual('gaia_evil_seal/'+outcome+'_exit' in seen, outcome==expected)
                    for arc in self.review['chapter_arcs'].values():
                        for phase in arc:
                            self.assertLessEqual(set(phase['blocks']), seen)

    def test_hero_does_not_receive_an_unconditional_weapon_or_early_victory(self):
        for key in ('lastditch_pyramid/battle_body', 'i/return_boar_escape'):
            refs = [s['ref'] for s in self.blocks[key]['text'] if 'ref' in s]
            self.assertFalse(any(r['catalog']=='equipment' for r in refs))
            self.assertFalse(any(r['catalog']=='abilities' for r in refs))
        battle = ''.join(s.get('text','') for s in self.blocks['lastditch_pyramid/battle_body']['text'])
        self.assertIn('아직 끝난 싸움은 아니었다', battle)
        shield = self.blocks['i/return_boar_shield_protagonist']
        self.assertNotEqual(shield['when'], True)
        refs = [s['ref']['id'] for s in shield['text'] if 'ref' in s]
        self.assertIn('shield_5', refs)
        self.assertNotIn('story_axe', refs)
        for key in ('gaia_evil_seal/floating_body', 'gaia_evil_seal/seal_return'):
            self.assertIn('magic_34', [s['ref']['id'] for s in self.blocks[key]['text'] if 'ref' in s])
        self.assertIn('magic_19', [s['ref']['id'] for s in self.blocks['gaia_evil_seal/aided_body']['text'] if 'ref' in s])


if __name__=='__main__':
    unittest.main()

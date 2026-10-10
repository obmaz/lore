import copy
import unittest
from unittest.mock import patch

from materials import ROOT, read
from writing import READING, reading_preview, validate_episode_plan


class EpisodeTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.plan = read(ROOT/'writing/episodes/lore_menace.json')
        cls.direct = reading_preview('menace-01')
        cls.tavern = reading_preview('menace-01-tavern')

    def test_six_units_only_first_is_rewritten(self):
        self.assertEqual(validate_episode_plan(self.plan)['units'],6)
        self.assertEqual(validate_episode_plan(self.plan)['revised_drafts'],1)
        self.assertEqual(self.plan['units'][0]['status'],'revised_draft')
        self.assertTrue(all(u['status']=='structural_draft' for u in self.plan['units'][1:]))
        self.assertTrue(all('blocks' not in u and 'text' not in u for u in self.plan['units']))

    def test_reusable_template_is_empty_outline(self):
        template = read(ROOT/'writing/templates/episode.template.json')
        result = validate_episode_plan(template,read(ROOT/'writing/templates/quest.template.json'))
        self.assertEqual((result['units'],result['revised_drafts']),(1,0))

    def test_duplicate_or_missing_scene_fails(self):
        for mutation in ('duplicate','missing'):
            plan = copy.deepcopy(self.plan)
            if mutation=='duplicate': plan['units'][1]['node_ids'].append('assignment')
            else: plan['units'][0]['node_ids']=['made_up']
            with self.assertRaisesRegex(ValueError,'episode'):
                validate_episode_plan(plan)

    def test_unmarked_authored_unit_fails(self):
        plan = copy.deepcopy(self.plan)
        plan['units'][0]['metadata']['addition']=False
        with self.assertRaisesRegex(ValueError,'addition'):
            validate_episode_plan(plan)

    def test_focus_stops_before_companion_exploration_and_reward(self):
        for p in [self.direct,self.tavern]:
            self.assertEqual([s['node_id'] for s in p['sections']],['lore_menace/assignment'])
            self.assertEqual(p['state']['quest.lore_stage'],3)
            self.assertEqual(p['state']['companions.optional_recruits'],[])
            self.assertFalse(p['state']['event.skeleton_offer_seen'])
            self.assertFalse(p['state']['quest.menace_reward_claimed'])
            self.assertNotIn('skeleton_departure_account',p['knowledge']['protagonist'])
            self.assertNotIn('lastditch_direction_account',p['knowledge']['protagonist'])

    def test_long_scene_and_tavern_memory_remain_different(self):
        for p in [self.direct,self.tavern]:
            blocks = p['sections'][0]['blocks']
            length = sum(len(b['text']) for b in blocks)
            self.assertTrue(3500<=length<=6500,length)
            self.assertGreaterEqual(len(blocks),25)
            self.assertTrue(p['provisional'])
        ids = lambda p:{b['id'] for b in p['sections'][0]['blocks']}
        self.assertNotIn('lore_menace/request_veteran_memory',ids(self.direct))
        self.assertIn('lore_menace/request_veteran_memory',ids(self.tavern))

    def test_focus_cannot_hide_a_future_route_that_was_already_replayed(self):
        catalog = read(READING)
        catalog['routes']['menace-01']['parts'] = catalog['routes']['first-journey']['parts']
        with patch('writing.read',side_effect=lambda p:catalog if p==READING else read(p)):
            with self.assertRaisesRegex(ValueError,'continues beyond'):
                reading_preview('menace-01')

    def test_focus_rejects_a_scene_not_on_route(self):
        catalog = read(READING)
        catalog['routes']['menace-01']['focus_nodes']=['lore_menace/center']
        with patch('writing.read',side_effect=lambda p:catalog if p==READING else read(p)):
            with self.assertRaisesRegex(ValueError,'not on'):
                reading_preview('menace-01')


if __name__=='__main__': unittest.main()

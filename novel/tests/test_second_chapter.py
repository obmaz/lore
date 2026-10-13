"""Written chapter two: source fidelity, forward forks and carried party/equipment."""
import unittest

from interactive_series import SeriesSession, PLAN
from materials import ROOT, read
from text_refs import archival, literals, source_ids


class SecondChapterTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.session=SeriesSession(chapter_limit=2)
        cls.nodes={n['id']:n for n in cls.session.story['nodes']}
        cls.quest=read(ROOT/'writing/quests/lastditch_pyramid.json')

    def walk(self, skeleton=False, polaris=True, spear='protagonist', tactics='hold_together'):
        route,p=self.session.advance([])
        while p['available_choices']:
            choices=p['available_choices']
            preferred=['prologue/visit_lord','i/depart_now',
                'lore_menace/accept_skeleton' if skeleton else 'lore_menace/decline_skeleton',
                'lore_menace/enter_menace','lore_menace/return_to_lore',
                'lastditch_pyramid/accept_polaris' if polaris else 'lastditch_pyramid/decline_polaris',
                'lastditch_pyramid/replace_for_polaris', 'lastditch_pyramid/replace_skeleton',
                'lastditch_pyramid/'+('leave_spear' if spear is None else 'equip_spear_'+spear),
                'lastditch_pyramid/'+tactics]
            choice=next((c for c in preferred if c in choices),choices[0])
            route,p=self.session.choose(route,choice)
        return route,p

    def test_all_original_scoped_dialogue_is_accounted_for_without_rewriting(self):
        raw=literals()
        expected={k for k,l in raw.items() if l['text'].strip() and l['role'] in
                  ('display_text_fragment','choice_label_or_prompt','text_variable_fragment') and any(
                  r['file']==l['source']['file'] and r['line_start']<=l['source']['line']<=r['line_end']
                  for r in self.quest['source_refs'].values())}
        used=set()
        for node in self.quest['nodes']:
            for b in node['blocks']:
                used.update(source_ids(b['text']))
                if b['provenance']['origin']=='source_exact':
                    self.assertEqual(archival(b['text'],raw),''.join(raw[i]['text'] for i in b['literal_ids']))
            for c in node['choices']:
                used.update(source_ids(c['label']))
                if c.get('label_literal_id'): used.add(c['label_literal_id'])
        self.assertTrue(expected<=used,expected-used)
        self.assertEqual(self.quest['coverage']['status'],'complete')

    def test_every_route_keeps_both_chapters_main_story_in_order(self):
        for recruit,owner,tactic in [(True,'protagonist','hold_together'),(False,None,'separate_pressure'),
                                     (True,'polaris','separate_pressure')]:
            route,p=self.walk(polaris=recruit,spear=owner,tactics=tactic)
            self.assertEqual(p['node_id'],'lastditch_pyramid/next_quest_boundary')
            self.assertTrue(p['main_story']['complete'])
            self.assertEqual(len(p['main_story']['seen_scenes']),31)
            self.assertEqual(p['state']['quest.lore_stage'],6)
            self.assertEqual(p['state']['quest.lastditch_stage'],3)
            self.assertEqual(p['state']['event.chapter02.experience_bonus'],10000)
            forks=[]
            for h in p['history']:
                choices=tuple(sorted(c['id'] for c in self.nodes[h['node_id']]['choices']
                                     if __import__('story_continuity').matches(c['when'],h['before'])))
                if len(choices)>1: forks.append((h['node_id'],choices))
            self.assertEqual(len(forks),len(set(forks)))

    def test_declined_companion_cannot_act_or_own_the_spear(self):
        route,p=self.walk(polaris=False,spear=None)
        self.assertNotIn('polaris',p['state']['companions.optional_recruits'])
        self.assertEqual(p['state']['event.chapter02.spear_owner'],'')
        for h in p['history']:
            if h['node_id'].startswith('lastditch_pyramid/'):
                self.assertFalse(any('/polaris_present_' in b or '/battle_weapon_polaris' in b or '/battle_spear_polaris' in b for b in h['visible_block_ids']))
        with self.assertRaises(ValueError): self.session.choose(route,'lastditch_pyramid/accept_polaris')

    def test_equipping_the_spear_changes_weapon_actions_not_magic(self):
        _,p=self.walk(spear='party_hunter')
        self.assertEqual(p['state']['event.weapon.party_hunter'],'weapon_3')
        battle=next(h for h in p['history'] if h['node_id']=='lastditch_pyramid/battle')
        self.assertIn('lastditch_pyramid/battle_spear_party_hunter',battle['visible_block_ids'])
        self.assertNotIn('lastditch_pyramid/battle_weapon_party_hunter',battle['visible_block_ids'])
        self.assertEqual(p['state']['event.chapter02.recipient_class'],'unknown')

    def test_full_party_replacement_is_departure_not_death_or_duplicate_reward(self):
        _,p=self.walk(skeleton=True)
        self.assertIn('polaris',p['state']['companions.optional_recruits'])
        self.assertNotIn('skeleton',p['state']['companions.optional_recruits'])
        self.assertEqual(p['state']['event.chapter02.departed'],'skeleton')
        self.assertLessEqual(1+len(p['state']['companions.starting'])+len(p['state']['companions.optional_recruits']),6)
        events=[e['id'] for e in p['proposed_events']]
        self.assertEqual(len(events),len(set(events)))
        self.assertIn('event.gold',p['handoff_packet']['state'])

    def test_all_chapters_use_common_policy_and_written_units_are_references(self):
        policy=read(ROOT/'writing/project.json')['branch_policy']
        self.assertEqual(policy['scope'],'all_chapters')
        self.assertEqual(policy['single_option'],'automatic_without_button')
        plan=read(PLAN)
        self.assertEqual(plan['branch_policy_ref'],'writing/project.json#/branch_policy')
        self.assertEqual(len(plan['chapters'][0]['units']),6)
        assigned=[n for u in plan['chapters'][0]['units'] for n in u['node_ids']]
        self.assertEqual(set(assigned),{'lastditch_pyramid/'+n['id'] for n in self.quest['nodes']})
        self.assertTrue(plan['metadata']['addition'])


if __name__=='__main__': unittest.main()

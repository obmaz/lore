"""The seal is found, not opened; rescue alternatives never leak across paths."""
import unittest
from interactive_series import SeriesSession
from materials import ROOT, read
from text_refs import archival, literals, source_ids, reject_fixed_names


class ThirdChapterTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.session=SeriesSession()
        cls.quest=read(ROOT/'writing/quests/gaia_evil_seal.json')

    def walk(self,response='aid_rigel',full=False):
        route,p=self.session.advance([])
        while p['available_choices']:
            preferred=['prologue/visit_lord','i/depart_now','lore_menace/decline_skeleton',
                'lore_menace/enter_menace','lore_menace/return_to_lore',
                'lastditch_pyramid/accept_polaris' if full else 'lastditch_pyramid/decline_polaris',
                'lastditch_pyramid/leave_spear','lastditch_pyramid/hold_together',
                'gaia_evil_seal/'+response,'gaia_evil_seal/replace_for_rigel','gaia_evil_seal/replace_polaris']
            route,p=self.session.choose(route,next((c for c in preferred if c in p['available_choices']),p['available_choices'][0]))
        return route,p

    def test_all_scoped_original_occurrences_are_preserved(self):
        raw=literals()
        expected={i for i,l in raw.items() if l['text'].strip() and l['role'] in
            ('display_text_fragment','choice_label_or_prompt','text_variable_fragment') and any(
            r['file']==l['source']['file'] and r['line_start']<=l['source']['line']<=r['line_end'] for r in self.quest['source_refs'].values())}
        used=set()
        for n in self.quest['nodes']:
            for b in n['blocks']:
                used.update(source_ids(b['text']))
                if b['provenance']['origin']=='source_exact':
                    self.assertEqual(archival(b['text'],raw),''.join(raw[i]['text'] for i in b['literal_ids']))
            for c in n['choices']:
                used.update(source_ids(c['label']))
                if c.get('label_literal_id'):used.add(c['label_literal_id'])
        self.assertTrue(expected<=used,expected-used)
        self.assertEqual(self.quest['coverage']['status'],'complete')

    def test_every_response_keeps_the_main_story_and_only_one_result(self):
        for response,result in [('join_rigel','joined'),('aid_rigel','aided'),('leave_rigel','left')]:
            _,p=self.walk(response)
            self.assertEqual(p['node_id'],'gaia_evil_seal/next_quest_boundary')
            self.assertTrue(p['main_story']['complete'])
            self.assertEqual(len(p['main_story']['seen_scenes']),43)
            self.assertEqual(p['state']['event.chapter03.rigel_response'],result)
            self.assertEqual('rigel' in p['state']['companions.optional_recruits'],result=='joined')
            self.assertEqual(p['state']['event.chapter03.blessing_offered'],result=='aided')
            self.assertEqual(p['state']['event.chapter03.experience_bonus'],10000)
            self.assertEqual(p['state']['quest.gaia_stage'],4)
            self.assertTrue(p['state']['quest.golden_seal_found'])
            self.assertFalse(p['state']['event.chapter03.floating'])
            visible={b for h in p['history'] for b in h['visible_block_ids']}
            for other in {'joined','aided','left'}-{result}:
                self.assertFalse(any('/'+other+'_body' in b for b in visible))
            self.assertEqual(p['handoff_packet']['quest_id'],'gaia_quake')

    def test_preparation_precedes_casting_and_only_aid_spends_the_supplies(self):
        for response in ['join_rigel','aid_rigel','leave_rigel']:
            _,p=self.walk(response)
            floating=next(h for h in p['history'] if h['node_id']=='gaia_evil_seal/floating')
            self.assertIn('magic_34',floating['before']['knowledge.spells.protagonist'])
            self.assertEqual(floating['before']['event.chapter03.prepared_sp'],10)
            self.assertEqual(p['state']['event.chapter03.prepared_sp'],0 if response=='aid_rigel' else 5)
            self.assertEqual(p['state']['event.chapter03.food'],0 if response=='aid_rigel' else 5)
            self.assertEqual(p['state']['event.chapter03.rigel_hp'],1 if response=='join_rigel' else 0)
            if response=='join_rigel':self.assertEqual(p['state']['event.weapon.rigel'],'weapon_4')

    def test_full_party_replaces_a_real_member_without_death(self):
        _,p=self.walk('join_rigel',full=True)
        self.assertEqual(p['state']['event.chapter03.departed'],'polaris')
        self.assertNotIn('polaris',p['state']['companions.optional_recruits'])
        self.assertIn('rigel',p['state']['companions.optional_recruits'])
        self.assertEqual(1+len(p['state']['companions.starting'])+len(p['state']['companions.optional_recruits']),6)
        self.assertEqual(p['state']['event.weapon.rigel'],'weapon_4')

    def test_numbered_labels_use_archived_clues_not_invented_codes(self):
        _,p=self.walk()
        self.assertEqual(p['state']['event.chapter03.door_number'],16)
        self.assertEqual(p['state']['event.chapter03.passcode'],5)
        insertions=self.session.overlay['display_insertions']
        self.assertTrue(any(i.get('state')=='event.chapter03.door_number' for a in insertions.values() for i in a))
        self.assertTrue(any(i.get('state')=='event.chapter03.passcode' for a in insertions.values() for i in a))

    def test_hero_reference_does_not_reject_unrelated_compound_words(self):
        catalog={'characters':{'protagonist':{'writing_name':{'value':'서진'}}}}
        reject_fixed_names([{'text':'부서진 성의 돌을 살폈다.'}],catalog)
        with self.assertRaises(ValueError):reject_fixed_names([{'text':'서진이 발밑을 보았다.'}],catalog)

    def test_new_prose_uses_name_references_not_role_labels(self):
        for n in self.session.story['nodes']:
            for b in n['blocks']:
                if b['kind'] not in ('source_quote','author_note'):
                    self.assertNotIn('주인공',''.join(t.get('text','') for t in b['text']))


if __name__=='__main__':unittest.main()

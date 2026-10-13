"""Written B chapters share A's flow, archived dialogue and carried memory."""
import copy
import hashlib
import unittest
from unittest.mock import patch
from interactive_series import compile_series
from prose_variants import load_series,apply_variant,structure,VariantSession,SERIES,compile_variant
from story_continuity import CANON,context_for_routes,validate
from materials import ROOT,read
from characters import load_characters
from reference import load_references
from text_refs import indexes,literals,render


class ProseSeriesTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.plan=load_series();cls.count=len(cls.plan['chapters'])
        cls.base,cls.memory,cls.overlay=compile_series(cls.count)
        cls.web=cls.base
        for row in cls.plan['chapters']:
            cls.web=apply_variant(cls.web,read(ROOT/row['file']),validate_result=False)
        validate(cls.web,cls.memory,read(CANON))
        cls.session=VariantSession.__new__(VariantSession)
        cls.session.story,cls.session.memory,cls.session.overlay=cls.web,cls.memory,cls.overlay
        cls.session.packet_for=context_for_routes(cls.web,cls.memory,read(CANON))

    def walk(self,polaris=True,skeleton=False,spear='party_hunter',tactic='separate_pressure',rescue='aid_rigel'):
        route,p=self.session.advance([])
        while p['available_choices']:
            preferred=['prologue/visit_lord','i/depart_now',
                'lore_menace/accept_skeleton' if skeleton else 'lore_menace/decline_skeleton',
                'lore_menace/enter_menace','lore_menace/return_to_lore',
                'lastditch_pyramid/accept_polaris' if polaris else 'lastditch_pyramid/decline_polaris',
                'lastditch_pyramid/replace_for_polaris','lastditch_pyramid/replace_skeleton',
                'lastditch_pyramid/'+('leave_spear' if spear is None else 'equip_spear_'+spear),
                'lastditch_pyramid/'+tactic,'gaia_evil_seal/'+rescue,
                'gaia_evil_seal/replace_for_rigel','gaia_evil_seal/replace_polaris']
            route,p=self.session.choose(route,next((c for c in preferred if c in p['available_choices']),p['available_choices'][0]))
        return route,p

    def test_all_chapters_share_the_entire_common_graph(self):
        self.assertEqual(structure(self.base),structure(self.web))
        for a,b in zip(self.base['nodes'],self.web['nodes']):
            self.assertEqual(a['choices'],b['choices'])
            for ba,bb in zip(a['blocks'],b['blocks']):
                if ba['provenance']['origin']!='authored':self.assertEqual(ba,bb)

    def test_each_chapter_has_a_full_explicit_prose_layer_not_a_fallback(self):
        expected={'chapter01':274,'chapter02':77,'chapter03':70}
        for row in self.plan['chapters']:
            doc=read(ROOT/row['file'])
            self.assertEqual(len(doc['block_overrides']),expected[row['chapter_id']])
            self.assertTrue(doc['metadata']['addition'])
            self.assertEqual(doc['style_revision'],1)
            for override in doc['block_overrides'].values():
                self.assertEqual(override['provenance']['origin'],'authored')
                self.assertNotIn('주인공',''.join(t.get('text','') for t in override['text']))

    def test_spear_assignment_and_companion_choices_persist_through_written_B(self):
        for recruit,owner,tactic in [(True,'party_hunter','separate_pressure'),(False,None,'hold_together')]:
            _,p=self.walk(polaris=recruit,spear=owner,tactic=tactic)
            self.assertTrue(p['main_story']['complete'])
            self.assertEqual(len(p['main_story']['seen_scenes']),31 if self.count==2 else 43)
            self.assertEqual(p['state']['event.chapter02.spear_owner'],owner or '')
            self.assertEqual(p['state']['event.chapter02.experience_bonus'],10000)
            self.assertEqual('polaris' in p['state']['companions.optional_recruits'],recruit)
            if owner:self.assertEqual(p['state']['event.weapon.'+owner],'weapon_3')
            if not recruit:
                self.assertFalse(any('/polaris_present_' in b for h in p['history'] for b in h['visible_block_ids']))

    def test_departure_is_not_death_and_absent_skeleton_never_speaks(self):
        _,p=self.walk(skeleton=True,polaris=True)
        self.assertEqual(p['state']['event.chapter02.departed'],'skeleton')
        self.assertNotIn('skeleton',p['state']['companions.optional_recruits'])
        self.assertFalse(any('/skeleton_present_' in b for h in p['history'] if not h['node_id'].startswith(('prologue/','lore_menace/','i/')) for b in h['visible_block_ids']))

    def test_B_sources_are_pinned_and_original_A_prose_is_not_replaced_on_disk(self):
        for row in self.plan['chapters']:
            doc=read(ROOT/row['file'])
            for name,digest in doc['base_source_sha256'].items():
                self.assertEqual(hashlib.sha256((ROOT/name).read_bytes()).hexdigest(),digest)
        base_text={b['id']:b['text'] for n in self.base['nodes'] for b in n['blocks']}
        web_text={b['id']:b['text'] for n in self.web['nodes'] for b in n['blocks']}
        self.assertNotEqual(base_text['lastditch_pyramid/arrival_body'],web_text['lastditch_pyramid/arrival_body'])

    def test_another_chapter_cannot_be_injected_into_a_prose_layer(self):
        doc=read(ROOT/self.plan['chapters'][1]['file'])
        doc['block_overrides']['prologue/arrival_first']=next(iter(doc['block_overrides'].values()))
        with self.assertRaisesRegex(ValueError,'explicitly replace'):apply_variant(self.base,doc)

    def test_index_rejects_gaps_duplicates_wrong_paths_and_stale_style(self):
        for mode in ['gap','duplicate','path','style']:
            plan=copy.deepcopy(self.plan)
            if mode=='gap':plan['chapters'][1]['chapter_id']='chapter03'
            elif mode=='duplicate':plan['chapters'][1]=copy.deepcopy(plan['chapters'][0])
            elif mode=='path':plan['chapters'][1]['file']='../elsewhere.json'
            else:plan['style_revision']+=1
            with patch('prose_variants.read',side_effect=lambda path:plan if path==SERIES else read(path)):
                with self.assertRaises(ValueError):load_series()

    @unittest.skipUnless((ROOT/'writing/variants/B/chapter03.json').is_file(),'B 3장 집필 후 검사')
    def test_three_rigel_responses_do_not_mix_resources_membership_or_blessing(self):
        if self.count<3:self.skipTest('3장은 아직 연결하지 않음')
        for choice,response in [('join_rigel','joined'),('aid_rigel','aided'),('leave_rigel','left')]:
            _,p=self.walk(rescue=choice)
            self.assertEqual(p['state']['event.chapter03.rigel_response'],response)
            self.assertEqual('rigel' in p['state']['companions.optional_recruits'],response=='joined')
            self.assertEqual(p['state']['event.chapter03.blessing_offered'],response=='aided')
            self.assertEqual(p['state']['event.chapter03.prepared_sp'],0 if response=='aided' else 5)
            self.assertEqual(p['state']['event.chapter03.food'],0 if response=='aided' else 5)
            self.assertEqual(p['state']['event.chapter03.experience_bonus'],10000)
            self.assertFalse(p['state']['event.chapter03.floating'])
            self.assertEqual(p['handoff_packet']['quest_id'],'gaia_quake')
            visible={b for h in p['history'] for b in h['visible_block_ids']}
            for other in {'joined','aided','left'}-{response}:
                self.assertNotIn('gaia_evil_seal/'+other+'_body',visible)

    @unittest.skipUnless((ROOT/'writing/variants/B/chapter03.json').is_file(),'B 3장 집필 후 검사')
    def test_preparation_is_visible_before_floating_and_seal_is_not_opened(self):
        if self.count<3:self.skipTest('3장은 아직 연결하지 않음')
        _,p=self.walk()
        cast=next(h for h in p['history'] if h['node_id']=='gaia_evil_seal/floating')
        self.assertIn('magic_34',cast['before']['knowledge.spells.protagonist'])
        self.assertEqual(cast['before']['event.chapter03.prepared_sp'],10)
        self.assertTrue(p['state']['quest.golden_seal_found'])
        self.assertEqual(p['state']['event.chapter03.passcode'],5)
        self.assertEqual(p['state']['event.chapter03.door_number'],16)

    @unittest.skipUnless((ROOT/'writing/variants/B/chapter03.json').is_file(),'B 3장 집필 후 검사')
    def test_replaced_starting_companion_has_no_later_narration(self):
        if self.count<3:self.skipTest('3장은 아직 연결하지 않음')
        route,p=self.session.advance([])
        while p['available_choices']:
            preferred=['prologue/visit_lord','i/depart_now','lore_menace/decline_skeleton',
                'lore_menace/enter_menace','lore_menace/return_to_lore','lastditch_pyramid/accept_polaris',
                'lastditch_pyramid/equip_spear_party_hunter','lastditch_pyramid/hold_together',
                'gaia_evil_seal/replace_for_rigel','gaia_evil_seal/replace_party_woodcutter']
            route,p=self.session.choose(route,next((c for c in preferred if c in p['available_choices']),p['available_choices'][0]))
        self.assertEqual(p['state']['event.chapter03.departed'],'party_woodcutter')
        self.assertNotIn('party_woodcutter',p['state']['companions.starting'])
        later=[b for h in p['history'] if h['node_id'] in ['gaia_evil_seal/passcode','gaia_evil_seal/next_request'] for b in h['visible_block_ids']]
        self.assertFalse(any(b.endswith('_party_party_woodcutter') for b in later))


if __name__=='__main__':unittest.main()

"""Two prose editions, one story graph, and no silent source/knowledge drift."""
import copy
import json
import re
import unittest
from interactive_series import compile_series,SeriesSession
from prose_variants import apply_variant,structure,VARIANT,STYLES,load_series
from materials import ROOT,read
from story_continuity import CANON,context_for_routes
from text_refs import indexes,literals,render
from characters import load_characters
from reference import load_references


class ProseVariantTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.base,cls.memory,cls.overlay=compile_series(chapter_limit=1)
        cls.document=read(VARIANT)
        cls.web=apply_variant(cls.base)
        cls.profiles=load_characters();cls.refs=load_references();cls.raw=literals()
        cls.session=SeriesSession.__new__(SeriesSession)
        cls.session.story,cls.session.memory,cls.session.overlay=cls.web,cls.memory,cls.overlay
        cls.session.packet_for=context_for_routes(cls.web,cls.memory,read(CANON))

    def test_same_nodes_choices_guards_effects_sources_and_main_story(self):
        self.assertEqual(structure(self.base),structure(self.web))
        self.assertEqual(len(self.document['block_overrides']),294)
        changed=sum(a['text']!=b['text'] for na,nb in zip(self.base['nodes'],self.web['nodes']) for a,b in zip(na['blocks'],nb['blocks']))
        self.assertGreater(changed,260)
        for na,nb in zip(self.base['nodes'],self.web['nodes']):
            for a,b in zip(na['blocks'],nb['blocks']):
                if a['provenance']['origin']!='authored':self.assertEqual(a,b)

    def test_no_unwritten_blocks_or_source_replacements(self):
        for mode in ['missing','source','unknown']:
            doc=copy.deepcopy(self.document)
            if mode=='missing':doc['block_overrides'].pop(next(iter(doc['block_overrides'])))
            else:doc['block_overrides']['prologue/introduction' if mode=='source' else 'not_a_block']=next(iter(doc['block_overrides'].values()))
            with self.assertRaisesRegex(ValueError,'explicitly replace'):apply_variant(self.base,doc)

    def test_stale_style_or_shared_inputs_stop_generation(self):
        for mode in ['style','base']:
            doc=copy.deepcopy(self.document)
            if mode=='style':doc['style_revision']+=1
            else:doc['base_source_sha256']['writing/quests/lore_menace.json']='0'*64
            with self.assertRaisesRegex(ValueError,'stale'):apply_variant(self.base,doc)

    def test_source_scope_cannot_be_silently_changed(self):
        doc=copy.deepcopy(self.document)
        doc['block_overrides']['prologue/arrival_first']['provenance']['source_refs']=['unknown']
        with self.assertRaisesRegex(ValueError,'source scope'):apply_variant(self.base,doc)

    def test_all_added_prose_is_marked_and_uses_mutable_references(self):
        self.assertTrue(self.document['metadata']['addition'])
        for override in self.document['block_overrides'].values():
            self.assertEqual(override['provenance']['origin'],'authored')
            self.assertIn('추가:',override['provenance']['note'])
            self.assertNotIn('주인공',''.join(s.get('text','') for s in override['text']))
        profiles=copy.deepcopy(self.profiles)
        profiles['characters']['protagonist']['writing_name']['value']='하나'
        profiles['characters']['protagonist'].setdefault('writing_overrides',{})['name']=copy.deepcopy(profiles['characters']['protagonist']['writing_name'])
        profiles['characters']['protagonist']['display_name']='하나'
        profiles['characters']['protagonist']['disclosure']['public_display_name']='하나'
        data=indexes(profiles,self.refs)
        first=self.document['block_overrides']['prologue/arrival_first']['text']
        displayed=render(first,data,self.raw,profiles,())
        self.assertRegex(displayed,r'하나는\s+[^.\n]*발을 거두고')
        self.assertNotIn('서진',displayed)
        self.assertNotIn('서진',''.join(s.get('text','') for s in first))

    def test_public_editions_have_their_own_scope_fingerprint_and_no_master(self):
        payloads={}
        for key,name in [('A','chapter01-interactive.html'),('B','chapter01-web.html')]:
            page=(ROOT/'writing/previews'/name).read_text()
            payloads[key]=json.loads(re.search(r'id="chapter-data">(.*?)</script>',page,re.S)[1])
            self.assertEqual(payloads[key]['edition'],key)
            for leaked in ['"relationships"','"biography"','"required_beats"','"canon"']:
                self.assertNotIn(leaked,page)
        self.assertEqual(len(payloads['A']['chapters']),3)
        self.assertEqual(len(payloads['B']['chapters']),len(load_series()['chapters']))
        self.assertNotEqual(payloads['A']['fingerprint'],payloads['B']['fingerprint'])
        wrapper=(ROOT/'writing/previews/novel-reader.html').read_text()
        self.assertIn('id="edition-select"',wrapper)
        self.assertIn('sandbox="allow-scripts allow-downloads"',wrapper)
        self.assertNotIn('allow-same-origin',wrapper)
        self.assertNotIn('fetch(',wrapper)

    def test_B_retains_every_mandatory_scene_and_stops_before_A_chapter_two(self):
        for recruit in [False,True]:
            route,p=self.session.advance([])
            while p['available_choices']:
                preferred=['prologue/visit_lord','i/depart_now',
                    'lore_menace/accept_skeleton' if recruit else 'lore_menace/decline_skeleton',
                    'lore_menace/enter_menace','lore_menace/return_to_lore']
                route,p=self.session.choose(route,next((c for c in preferred if c in p['available_choices']),p['available_choices'][0]))
            self.assertEqual(p['node_id'],'lore_menace/next_quest_boundary')
            self.assertTrue(p['main_story']['complete'])
            self.assertEqual(len(p['main_story']['seen_scenes']),17)
            self.assertEqual('skeleton' in p['state']['companions.optional_recruits'],recruit)
            self.assertFalse(any(h['node_id'].startswith('lastditch_pyramid/') for h in p['history']))

    def test_A_is_not_redefined_and_both_styles_point_to_the_shared_structure(self):
        profiles=read(STYLES)['profiles']
        self.assertEqual(profiles['A']['definition_ref'],'project.json#/style')
        self.assertEqual(profiles['B']['revision'],self.document['style_revision'])
        self.assertEqual(profiles['A']['written_chapters'],['chapter01','chapter02','chapter03'])
        self.assertEqual(profiles['B']['written_chapters'],[c['chapter_id'] for c in load_series()['chapters']])
        self.assertEqual(self.document['shared_structure'],'writing/interactive/series.json')


if __name__=='__main__':unittest.main()

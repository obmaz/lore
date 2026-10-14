import copy
import json
import re
import unittest

from materials import ROOT, read
from characters import load_characters
from reference import load_references
from text_refs import indexes, literals
from prose_presentation import PLAN, compile_presentation


class ProsePresentationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.plan=read(PLAN)
        cls.data=indexes(load_characters(),load_references())
        cls.literals=literals()
        cls.payloads={}
        for edition,name in [('A','chapter01-interactive.html'),('B','chapter01-web.html')]:
            source=(ROOT/'writing/previews'/name).read_text()
            cls.payloads[edition]=json.loads(re.search(r'id="chapter-data">(.*?)</script>',source,re.S)[1])

    def story(self,edition='A'):
        p=self.payloads[edition]
        types=lambda v:'boolean' if isinstance(v,bool) else 'integer' if isinstance(v,int) else 'string' if isinstance(v,str) else 'string_set'
        return {'nodes':copy.deepcopy(p['nodes']),'state_definitions':{k:{'type':types(v)}for k,v in p['initial'].items()}}

    def compile(self,document=None,story=None):
        return compile_presentation(story or self.story(),self.data,self.literals,document)

    def test_both_editions_bind_every_source_and_speaker_without_editing_story(self):
        for edition in ['A','B']:
            story=self.story(edition);before=copy.deepcopy(story)
            p=self.compile(story=story)
            self.assertEqual(story,before)
            self.assertEqual(len(p['groups']),129)
            ids=[i for g in p['groups']for i in g['block_ids']]
            self.assertEqual(len(ids),202)
            self.assertEqual(len(set(ids)),202)
            self.assertEqual(len(p['dialogues']),38)
            self.assertEqual(self.payloads[edition]['presentation'],p)
            self.assertFalse(p['policy']['speaker_labels'])
            self.assertFalse(p['policy']['source_boxes'])
            self.assertEqual(p['policy']['subsection_titles'],'author_only')

    def test_source_dialogue_fragments_are_joined_without_new_words(self):
        p=self.compile()
        g=next(g for g in p['groups']if g['node']=='lastditch_pyramid/request')
        self.assertEqual(len(g['block_ids']),11)
        self.assertEqual(g['kind'],'speech')
        self.assertTrue(all('body' not in e for e in g['editions'].values()))
        for group in p['groups']:
            self.assertEqual(group['provenance']['origin'],'source_adaptation' if group['kind']=='narration' else 'authored')
            self.assertEqual(group['provenance']['source_block_ids'],group['block_ids'])

    def test_unmapped_or_duplicate_source_fails(self):
        for mode in ['missing','duplicate']:
            doc=copy.deepcopy(self.plan)
            if mode=='missing':doc['groups'].pop(0)
            else:doc['groups'].append(copy.deepcopy(doc['groups'][0]))
            with self.assertRaisesRegex(ValueError,'unmapped|duplicate'):self.compile(doc)

    def test_reordering_or_nonadjacent_merge_fails(self):
        doc=copy.deepcopy(self.plan)
        group=next(g for g in doc['groups']if len(g['block_ids'])>1)
        group['block_ids'].reverse()
        with self.assertRaisesRegex(ValueError,'contiguous and ordered'):self.compile(doc)
        doc=copy.deepcopy(self.plan)
        doc['groups'][0]['block_ids'].append('prologue/courtyard_pause')
        with self.assertRaises(ValueError):self.compile(doc)

    def test_distinct_guards_and_speakers_cannot_merge(self):
        for mode in ['when','speaker']:
            story=self.story()
            block=next(b for n in story['nodes']for b in n['blocks']if b['id']=='lastditch_pyramid/request_444')
            block[mode]=False if mode=='when' else 'lord_ahn'
            with self.assertRaisesRegex(ValueError,'distinct conditions or speakers'):self.compile(story=story)

    def test_unknown_dialogue_speaker_and_missing_attribution_fail(self):
        for mode in ['missing','changed']:
            doc=copy.deepcopy(self.plan)
            if mode=='missing':doc['dialogues'].pop('prologue/tavern_reply')
            else:doc['dialogues']['prologue/tavern_reply']['speaker']='skeleton'
            with self.assertRaisesRegex(ValueError,'dialogue speaker'):self.compile(doc)

    def test_narrative_does_not_turn_ui_into_a_speaking_actor(self):
        p=self.compile()
        for id in ['lore_menace/reward_counter_quote','lastditch_pyramid/report_463','gaia_evil_seal/report_experience','gaia_evil_seal/aid_result_643']:
            g=next(g for g in p['groups']if id in g['block_ids'])
            self.assertEqual(g['kind'],'narration')
            self.assertTrue(all('body' in e for e in g['editions'].values()))
        inscription=next(g for g in p['groups']if 'gaia_evil_seal/door_clue_437' in g['block_ids'])
        self.assertEqual(inscription['kind'],'inscription')

    def test_reading_insertions_use_real_route_state_and_references(self):
        p=self.compile()
        shield=next(g for g in p['groups']if 'i/shield_equipped_words' in g['block_ids'])
        self.assertEqual(shield['editions']['A']['body'][0],{'state':'event.shield_owner','catalog':'characters','particle':'은/는'})
        doc=copy.deepcopy(self.plan)
        next(g for g in doc['groups']if 'i/shield_equipped_words' in g['block_ids'])['editions']['A']['body'][0]['state']='event.unknown'
        with self.assertRaisesRegex(ValueError,'unknown state'):self.compile(doc)
        for entry in [*p['groups'],*p['dialogues'].values()]:
            for e in entry['editions'].values():
                text=''.join(s.get('text','')for v in e.values()for s in v)
                self.assertNotIn('서진',text)
                self.assertNotIn('동욱',text)


if __name__=='__main__':unittest.main()

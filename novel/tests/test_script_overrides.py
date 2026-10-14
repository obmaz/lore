import copy
import hashlib
import unittest
from unittest.mock import patch
from materials import ROOT,read
from characters import load_characters
from reference import load_references
from text_refs import indexes,literals,archival
from prose_presentation import compile_presentation,section_paragraphs,display_text
from script_overrides import PLAN,compile_overrides
from ebook import payload_from_page


class ScriptOverridesTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.payload=payload_from_page((ROOT/'writing/previews/chapter01-web.html').read_text())
        cls.plan=read(PLAN);cls.data=indexes(load_characters(),load_references());cls.raw=literals()
        cls.story={'nodes':cls.payload['nodes'],'state_definitions':{k:{'type':'boolean'if isinstance(v,bool)else 'integer'if isinstance(v,int)else 'string'if isinstance(v,str)else 'string_set'}for k,v in cls.payload['initial'].items()}}
        cls.presentation=compile_presentation(cls.story,cls.data,cls.raw)

    def compile(self,document):
        return compile_overrides(self.story,self.presentation['groups'],self.data,self.raw,document)

    def test_source_words_ids_and_source_sha_are_unchanged(self):
        original=copy.deepcopy(self.story)
        self.compile(self.plan)
        self.assertEqual(original,self.story)
        block=next(b for n in self.story['nodes']for b in n['blocks']if b['id']=='prologue/lord_intro_dialogue')
        text=archival(block['text'],self.raw)
        self.assertIn('이 게임에서 새로운 인물',text)
        self.assertEqual(hashlib.sha256(text.encode()).hexdigest(),self.plan['overrides'][block['id']]['source_sha256'])

    def test_override_is_used_first_for_both_editions(self):
        for edition in ['A','B']:
            payload=copy.deepcopy(self.payload);payload['edition']=edition
            payload['presentation']=self.presentation
            node=next(n for n in payload['nodes']if n['id']=='prologue/audience')
            paragraphs=section_paragraphs(node,[b['id']for b in node['blocks']],payload['initial'],payload)
            text=next(p['text']for p in paragraphs if p['block_id']=='prologue/lord_intro_dialogue')
            self.assertIn('나는 동욱이오.',text)
            self.assertIn('새로운 여정',text)
            self.assertNotIn('게임',text)

    def test_missing_or_null_override_falls_back_without_editing_source(self):
        key='prologue/lord_intro_dialogue'
        for mode in ['missing','null']:
            doc=copy.deepcopy(self.plan)
            if mode=='missing':doc['overrides'].pop(key)
            else:doc['overrides'][key]['writing_overrides']['text']=None
            payload=copy.deepcopy(self.payload);payload['presentation']['script_overrides']=self.compile(doc)
            node=next(n for n in payload['nodes']if n['id']=='prologue/audience')
            result=section_paragraphs(node,[b['id']for b in node['blocks']],payload['initial'],payload)
            self.assertIn('이 게임에서 새로운 인물',next(p['text']for p in result if p['block_id']==key))

    def test_original_source_review_and_group_identity_are_guarded(self):
        for mode in ['hash','ids','group']:
            doc=copy.deepcopy(self.plan);entry=doc['overrides']['prologue/lord_intro_dialogue']
            if mode=='hash':entry['source_sha256']='0'*64
            elif mode=='ids':entry['source_literal_ids'].reverse()
            else:entry['source_block_ids']=['prologue/guide_dialogue']
            with self.assertRaisesRegex(ValueError,'source review|source scope'):self.compile(doc)

    def test_mutable_name_references_and_particle_are_not_copied_strings(self):
        payload=copy.deepcopy(self.payload);payload['labels']['characters']['lord_ahn']='미라'
        text=self.plan['overrides']['prologue/lord_intro_dialogue']['writing_overrides']['text']
        self.assertIn('나는 미라요.',display_text(text,payload['initial'],payload))
        self.assertNotIn('동욱',str(text))

    def test_fixed_names_or_game_terminology_in_replacement_fail(self):
        for text in ['나는 동욱이오.','이 게임에서 시작합니다.']:
            doc=copy.deepcopy(self.plan)
            doc['overrides']['prologue/lord_intro_dialogue']['writing_overrides']['text']=[{'text':text}]
            with self.assertRaises(ValueError):self.compile(doc)


if __name__=='__main__':unittest.main()

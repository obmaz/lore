"""Source-first connected edition: completeness, exactness, conditions and safety."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import jsonschema

from materials import ROOT, read, load_materials
from source_story import PLAN, compile_story, validate_story, source_indexes, story_document, export
from text_refs import source_text


class SourceStoryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.plan = read(PLAN)
        cls.story = compile_story()
        cls.raw, cls.events, cls.scenes = source_indexes(load_materials()[0])

    def records(self):
        return [r for s in self.story['sections'] for r in s['records']] + self.story['appendices']

    def test_01_every_original_occurrence_event_and_script_is_preserved(self):
        report = validate_story(self.story)
        self.assertEqual((report['source_files'], report['literal_occurrences'], report['display_events'], report['source_scripts']), (14,2483,1674,307))
        self.assertEqual(report['main_chapters'],15)
        keys = [key for r in self.records() for key in r['literal_ids']]
        self.assertEqual(len(keys), len(set(keys)))
        self.assertEqual(set(keys), set(self.raw))
        self.assertEqual({r['id'] for r in self.records() if r['kind']=='display_event'}, set(self.events))
        self.assertEqual({s['id'] for s in self.story['script_index']}, set(self.scenes))

    def test_02_original_text_conditions_expressions_and_code_are_not_rewritten(self):
        for row in self.records():
            expected = self.events[row['id']] if row['kind']=='display_event' else self.raw[row['id']]
            self.assertEqual(row['original'], expected)
            self.assertEqual(row['branch_context'], expected['branch_context'])
            for part in row['display_parts']:
                if 'source' in part:
                    self.assertEqual(source_text(part['source'],self.raw), ''.join(self.raw[k]['text'] for k in part['source']['literal_ids']))
        for script in self.story['script_index']:
            original = self.scenes[script['id']]
            self.assertEqual(script['original_source'],original['original_source'])
            self.assertEqual(script['state_changes'],original['state_changes'])
            self.assertEqual(script['calls'],original['calls'])

    def test_03_removing_or_tampering_with_originals_is_rejected(self):
        for mode in ('removed', 'text', 'condition', 'script', 'coverage'):
            story = copy.deepcopy(self.story)
            if mode=='removed':story['sections'][0]['records'].pop()
            elif mode=='text':story['sections'][0]['records'][0]['original']['text_template']='대체한 원문'
            elif mode=='condition':
                conditional = next(r for s in story['sections'] for r in s['records'] if r['branch_context'])
                conditional['branch_context']=[]
            elif mode=='script':story['script_index'].pop()
            else:story['coverage']['literal_occurrences']=0
            with self.assertRaisesRegex(ValueError,'differs'):
                validate_story(story)

    def test_04_a_missing_story_section_cannot_silently_become_an_appendix(self):
        plan = copy.deepcopy(self.plan)
        plan['sections']=[s for s in plan['sections'] if s['id']!='06-antares']
        with self.assertRaisesRegex(ValueError,'unplaced original story script'):
            compile_story(plan)
        plan = copy.deepcopy(self.plan)
        plan['sections']=[s for s in plan['sections'] if s['id']!='01-invitation']
        with self.assertRaisesRegex(ValueError,'unplaced original story script'):
            compile_story(plan)
        plan = copy.deepcopy(self.plan)
        plan['sections']=[s for s in plan['sections'] if s['id']!='shared-facilities']
        with self.assertRaisesRegex(ValueError,'unplaced original story script'):
            compile_story(plan)

    def test_05_overlapping_placements_and_skipped_chapters_are_rejected(self):
        plan = copy.deepcopy(self.plan)
        plan['sections'][1]['selectors'].append(copy.deepcopy(plan['sections'][0]['selectors'][0]))
        with self.assertRaisesRegex(ValueError,'overlapping'):
            compile_story(plan)
        plan = copy.deepcopy(self.plan)
        plan['sections']=[s for s in plan['sections'] if s['chapter_id']!='chapter02']
        with self.assertRaisesRegex(ValueError,'chapter order'):
            compile_story(plan)

    def test_06_authored_bridges_and_author_only_scope_are_enforced(self):
        for mode in ('unmarked', 'public', 'fixed_name'):
            plan = copy.deepcopy(self.plan)
            if mode=='unmarked':plan['sections'][0]['metadata']['addition']=False
            elif mode=='public':plan['visibility']='reader'
            else:plan['sections'][0]['before']=[{'text':read(ROOT/'reference/names.json')['characters']['protagonist']['value']+'의 여정'}]
            with self.assertRaises((ValueError,jsonschema.ValidationError)):
                compile_story(plan)

    def test_07_original_revisits_optional_companions_and_learning_have_connections(self):
        sections = {s['id']:s for s in self.story['sections']}
        by_id = {r['id']:s['id'] for s in self.story['sections'] for r in s['records']}
        for line,target in [(1075,'06-antares'),(1029,'07-return'),(1278,'07-learning'),(1223,'07-choices'),(730,'08-prophecy'),(156,'08-evil'),(54,'08-draconian')]:
            file = 'LORESPEC.PAS'
            event = next(e for e in self.events.values() if e['source']['file']==file and e['source']['line_start']==line)
            self.assertEqual(by_id[event['statement_id']],target)
        self.assertFalse(self.story['coverage']['single_playthrough_verified'])
        self.assertFalse(self.story['coverage']['reader_prose_complete'])
        self.assertTrue(sections['07-return']['records'])
        invitation = sections['01-invitation']
        self.assertEqual(self.story['sections'][0]['id'], '01-invitation')
        self.assertTrue(invitation['show_literal_text'])
        intro = ''.join(r['original'].get('text_template',r['original'].get('text','')) for r in invitation['records'])
        self.assertTrue('공간적으로는 다르게 진화해 온 또다른 지구' in intro)
        self.assertTrue('운명을 피하려 하지 마십시오.' in intro)

    def test_08_temple_quizzes_metafiction_and_the_ending_are_not_omitted(self):
        sections = {s['id']:s for s in self.story['sections']}
        temple = [r for r in sections['side-temple']['records'] if r['kind']=='display_event']
        self.assertEqual(len(temple),220)
        text = ''.join(r['original'].get('text_template', r['original'].get('text','')) for r in self.records())
        for original in ('CONFIG.SYS가 없으면 부팅이 안된다','버그를 찾거나 난이도를 조절하기 위해서','영원히 안녕','결코 그만이 동정의 대상이 아니오'):
            self.assertTrue(original in text, original)
        finding = next(f for f in self.story['findings'] if f['id']=='temple-access')
        self.assertIn('at(20,6)',finding['note'])

    def test_09_dynamic_names_are_refs_but_unspecified_values_remain_expressions(self):
        self.assertTrue(any({'ref':{'catalog':'characters','id':'protagonist'}} in r['display_parts'] for r in self.records()))
        self.assertTrue(any('expression' in part for r in self.records() for part in r['display_parts']))
        claim = next(r for r in self.records() if r['source']['file']=='LORESPEC.PAS' and r['source'].get('line_start')==1904 and r['kind']=='display_event')
        self.assertEqual(claim['display_parts'][0]['source']['bindings'][0]['ref']['id'],'necromancer')

    def test_10_generated_outputs_refuse_to_overwrite_manual_edits(self):
        with tempfile.TemporaryDirectory(prefix='lore-source-guard-') as temp, patch('source_story.OUTPUT',Path(temp)):
            export()
            export(check=True)
            path = Path(temp)/'manuscript.json'
            path.write_text('manual edit',encoding='utf-8')
            with self.assertRaisesRegex(ValueError,'manually edited'):
                export()

    def test_11_connected_reading_contains_all_original_groups_without_print_or_choices(self):
        page = story_document(self.story)
        self.assertIn('원작 전체 스크립트',page)
        self.assertIn('2,483'.replace(',',''),page)
        self.assertIn('href="#chapter15"',page)
        self.assertIn('원작 조건:',page)
        self.assertTrue('오래전 부터 만날 운명이었던 당신에게 드리는 글' in page)
        self.assertIn('게임의 제작자',page)
        self.assertIn('{{',page)
        self.assertNotIn('onclick="print()"',page)
        self.assertNotIn('data-choice=',page)


if __name__=='__main__': unittest.main()

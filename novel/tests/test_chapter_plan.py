"""Macro-first authoring: mandatory chapters, original gates and real scene bindings."""
import copy
import json
import unittest
from unittest.mock import patch

import jsonschema

from interactive import Session, documents
from materials import ROOT, read
from writing import BOARD, CHAPTERS, WRITING, html_doc, validate_chapters
from characters import load_characters
from reference import load_references
from text_refs import indexes, literals, render


class ChapterPlanTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.plan = read(CHAPTERS)
        cls.session = Session()
        cls.profiles = load_characters()
        cls.data, cls.literals = indexes(cls.profiles,load_references()), literals()

    def validate(self, plan, runtime=False):
        return validate_chapters(plan, story=self.session.story if runtime else None,
                                 main_story=self.session.overlay['main_story'] if runtime else None)

    def test_01_all_titles_and_main_beats_exist_without_claiming_future_prose(self):
        result = self.validate(self.plan, runtime=True)
        self.assertEqual(result['chapters'], 15)
        self.assertEqual(result['runtime_bound'], ['chapter01','chapter02','chapter03'])
        self.assertFalse(result['future_prose_complete'])
        self.assertEqual([c['number'] for c in self.plan['chapters']], list(range(1,16)))
        self.assertTrue(all(c['mandatory'] and c['exit_requires_all'] for c in self.plan['chapters']))
        self.assertTrue(all(b['scene_nodes'] is None for c in self.plan['chapters'][3:] for b in c['required_beats']))
        self.assertEqual(self.session.story['meta']['title'], self.plan['chapters'][0]['title'])

    def test_02_every_original_board_unit_is_preserved_once(self):
        assigned = [u for c in [*self.plan['chapters'], *self.plan['side_stories']] for u in c['unit_ids']]
        self.assertEqual(len(assigned), len(set(assigned)))
        self.assertEqual(set(assigned), {u['id'] for u in read(BOARD)['units']})
        plan = copy.deepcopy(self.plan)
        plan['side_stories'] = []
        with self.assertRaisesRegex(ValueError, 'preserve every'):
            self.validate(plan)

    def test_03_a_main_chapter_cannot_become_skippable(self):
        for key in ['mandatory', 'exit_requires_all']:
            plan = copy.deepcopy(self.plan)
            plan['chapters'][1][key] = False
            with self.assertRaises(jsonschema.ValidationError): self.validate(plan)
        plan = copy.deepcopy(self.plan)
        plan['side_stories'][0]['unit_ids'].append('last_shelter')
        with self.assertRaisesRegex(ValueError, 'main source units'):
            self.validate(plan)

    def test_04_two_seals_are_both_required_in_either_order(self):
        chapter = self.plan['chapters'][8]
        self.assertEqual(set(chapter['unit_ids']), {'evil_god_seal','muddy_seal'})
        self.assertEqual([b['after'] for b in chapter['required_beats']], [[],[]])
        plan = copy.deepcopy(self.plan)
        plan['chapters'][8]['required_beats'][1]['after'] = [chapter['required_beats'][0]['id']]
        with self.assertRaisesRegex(ValueError, 'parallel main objectives'):
            self.validate(plan)

    def test_05_unwritten_chapter_cannot_claim_fake_implemented_scenes(self):
        for mode in ['fake_scene', 'fake_runtime']:
            plan = copy.deepcopy(self.plan)
            if mode == 'fake_scene': plan['chapters'][3]['required_beats'][0]['scene_nodes'] = ['made_up/scene']
            else: plan['chapters'][3]['implementation'] = 'runtime_bound'
            with self.assertRaisesRegex(ValueError, 'unwritten chapter|future chapter'):
                self.validate(plan)

    def test_06_macro_plan_cannot_omit_a_runtime_main_scene(self):
        plan = copy.deepcopy(self.plan)
        plan['chapters'][0]['required_beats'][1]['scene_nodes'].remove('prologue/audience')
        with self.assertRaisesRegex(ValueError, 'complete ordered runtime backbone'):
            self.validate(plan, runtime=True)

    def test_07_missing_milestone_or_cyclic_dependency_is_rejected(self):
        plan = copy.deepcopy(self.plan)
        plan['chapters'][1]['required_beats'].pop()
        with self.assertRaisesRegex(ValueError, 'omitted source milestone'):
            self.validate(plan)
        plan = copy.deepcopy(self.plan)
        chapter = plan['chapters'][1]
        chapter['required_beats'][0]['after'] = [chapter['required_beats'][-1]['id']]
        with self.assertRaisesRegex(ValueError, 'cyclic chapter'):
            self.validate(plan)

    def test_08_titles_are_authored_and_mutable_names_need_references(self):
        plan = copy.deepcopy(self.plan)
        plan['chapters'][0]['metadata']['addition'] = False
        with self.assertRaises(ValueError): self.validate(plan)
        plan = copy.deepcopy(self.plan)
        hero = read(ROOT/'reference/names.json')['characters']['protagonist']['value']
        plan['chapters'][0]['title'] = [{'text': hero+'의 여행'}]
        with self.assertRaisesRegex(ValueError, 'use a reference'): self.validate(plan)
        self.validate(read(WRITING/'templates/chapters.template.json'))

    def test_09_original_required_progress_order_cannot_be_reversed(self):
        plan = copy.deepcopy(self.plan)
        plan['chapters'][2], plan['chapters'][3] = plan['chapters'][3], plan['chapters'][2]
        for i in [2,3]:
            chapter = plan['chapters'][i]
            old_id, new_id = chapter['id'], 'chapter'+str(i+1).zfill(2)
            chapter['id'], chapter['number'] = new_id, i+1
            for beat in chapter['required_beats']:
                beat['id'] = beat['id'].replace(old_id+'/',new_id+'/')
                beat['after'] = [p.replace(old_id+'/',new_id+'/') for p in beat['after']]
        with self.assertRaisesRegex(ValueError, 'original required progress gate|future chapter'):
            self.validate(plan)

    def test_10_reader_has_current_title_no_print_button_or_future_outline(self):
        simple = html_doc('title', '<p>body</p>')
        self.assertNotIn('onclick="print()"', simple)
        page = documents()['chapter01-interactive.html']
        title = render(self.plan['chapters'][0]['title'],self.data,self.literals,self.profiles,())
        self.assertIn('<h1>제1장 · '+title+'</h1>', page)
        self.assertNotIn('인쇄 / PDF 저장', page)
        self.assertNotIn('onclick="print()"', page)
        self.assertNotIn('"required_beats"', page)
        self.assertIn(render(self.plan['chapters'][1]['title'],self.data,self.literals,self.profiles,author=True),page)
        self.assertIn(render(self.plan['chapters'][2]['title'],self.data,self.literals,self.profiles,author=True),page)
        for chapter in self.plan['chapters'][3:]:
            self.assertNotIn(json.dumps(chapter['title'],ensure_ascii=False), page)
            self.assertNotIn(render(chapter['title'],self.data,self.literals,self.profiles,author=True), page)

    def test_11_renaming_central_title_changes_the_reader_without_prose_edits(self):
        plan = copy.deepcopy(self.plan)
        plan['chapters'][0]['title'] = [{'text': '새로 정한 첫 장의 제목'}]
        with patch('interactive.read',side_effect=lambda path:copy.deepcopy(plan) if path==CHAPTERS else read(path)):
            page = documents()['chapter01-interactive.html']
        self.assertIn('<h1>제1장 · 새로 정한 첫 장의 제목</h1>',page)
        self.assertNotIn('<h1>제1장 · 부탁을 받은 사람들</h1>',page)


if __name__ == '__main__': unittest.main()

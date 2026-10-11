"""Subsection stories preserve the main contract; candidates are not runtime."""
import copy
import unittest

import jsonschema

from chapter_subsections import PLAN, TEMPLATE, validate_subsections, subsection_document
from chapter_stories import STORIES
from characters import load_characters
from materials import ROOT, read
from reference import load_references
from text_refs import indexes, literals, render
from writing import CHAPTERS


class ChapterSubsectionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.plan, cls.chapters, cls.macro = read(PLAN), read(CHAPTERS), read(STORIES)
        cls.profiles, cls.references = load_characters(), load_references()
        cls.data, cls.raw = indexes(cls.profiles, cls.references), literals()

    def validate(self, plan):
        return validate_subsections(plan, self.chapters, self.macro, self.profiles, self.references)

    def test_01_all_chapters_have_main_content_not_fake_choices_or_finished_prose(self):
        report = self.validate(self.plan)
        self.assertEqual((report['chapters'], report['subsections'], report['required_beats'], report['branch_candidates']), (15, 88, 44, 29))
        self.assertFalse(report['branches_implemented'])
        self.assertFalse(report['detailed_prose_complete'])
        for c in self.plan['chapters']:
            for u in c['units']:
                self.assertTrue(u['mandatory'])
                self.assertNotIn('choices', u)
                self.assertGreater(len(render(u['main_content'], self.data, self.raw, self.profiles, author=True)), 85)

    def test_02_missing_reordered_unknown_and_duplicate_chapters_are_rejected(self):
        for mode in ('missing', 'order', 'unknown', 'duplicate'):
            p = copy.deepcopy(self.plan)
            if mode == 'missing': p['chapters'].pop()
            elif mode == 'order': p['chapters'][:2] = reversed(p['chapters'][:2])
            elif mode == 'unknown': p['chapters'][0]['chapter_id'] = 'made_up'
            else: p['chapters'].append(p['chapters'][0])
            with self.assertRaisesRegex(ValueError, 'chapter'): self.validate(p)

    def test_03_required_beats_and_parent_sources_cannot_be_lost_or_borrowed(self):
        for mode in ('beat', 'exit', 'source', 'foreign_source'):
            p = copy.deepcopy(self.plan)
            c = p['chapters'][0]
            if mode == 'beat': c['units'][0]['completes_beats'] = []
            elif mode == 'exit': c['exit_requires_beats'].pop()
            elif mode == 'source': c['units'][0]['source_section_refs'] = ['01-cave']
            else: c['units'][0]['source_section_refs'].append('02-request')
            with self.assertRaisesRegex(ValueError, 'beat|source'): self.validate(p)

    def test_04_links_and_dependencies_cannot_skip_or_cycle(self):
        for mode in ('skip', 'cycle', 'foreign', 'early_beat', 'orphan'):
            p = copy.deepcopy(self.plan)
            u = p['chapters'][0]['units']
            if mode == 'skip': u[0]['reading_next'] = u[2]['id']
            elif mode == 'cycle': u[0]['after'] = [u[1]['id']]
            elif mode == 'foreign': u[1]['after'] = ['chapter02/p01']
            elif mode == 'early_beat': u[1]['after'] = []
            else: u[3]['after'] = []
            with self.assertRaisesRegex(ValueError, 'skip|cyclic|dependency|prerequisite|connect'): self.validate(p)

    def test_05_candidates_must_rejoin_and_fixed_units_have_no_false_choice(self):
        for mode in ('join', 'variation', 'carry', 'fixed'):
            p = copy.deepcopy(self.plan)
            c = p['chapters'][0]['units'][3]['branch']
            if mode == 'join': c['rejoin_before'] = 'chapter02/p01'
            elif mode == 'variation': c['variation_scope'] = None
            elif mode == 'carry': c['carry_keys'] = []
            else: p['chapters'][0]['units'][0]['branch']['carry_keys'] = ['fake']
            with self.assertRaisesRegex(ValueError, 'branch|fixed'): self.validate(p)

    def test_06_both_seals_remain_independent_and_exit_requires_both(self):
        c = self.plan['chapters'][8]
        self.assertEqual(c['units'][3]['after'], [c['units'][0]['id']])
        self.assertEqual(set(c['units'][-1]['after']), {c['units'][2]['id'], c['units'][5]['id']})
        for mode in ('missing', 'serial', 'early_exit', 'repeated'):
            p = copy.deepcopy(self.plan)
            c = p['chapters'][8]
            if mode == 'missing': c['parallel_groups'] = []
            elif mode == 'serial': c['units'][3]['after'] = [c['units'][2]['id']]
            elif mode == 'early_exit': c['units'][-1]['after'].pop()
            else: c['parallel_groups'][0]['blocks'][1].append(c['units'][1]['id'])
            with self.assertRaisesRegex(ValueError, 'parallel'): self.validate(p)

    def test_07_unmarked_additions_public_or_runtime_claims_and_stale_parent_fail(self):
        for mode in ('addition', 'public', 'runtime', 'skippable', 'unlocked', 'stale', 'parent'):
            p = copy.deepcopy(self.plan)
            if mode == 'addition': p['chapters'][0]['units'][0]['metadata']['addition'] = False
            elif mode == 'public': p['visibility'] = 'reader'
            elif mode == 'runtime': p['workflow']['runtime_binding'] = 'implemented'
            elif mode == 'skippable': p['chapters'][0]['units'][0]['mandatory'] = False
            elif mode == 'unlocked': p['chapters'][0]['units'][3]['branch']['main_result_locked'] = False
            elif mode == 'stale': p['macro_revision'] -= 1
            else: p['chapters'][0]['inherit_continuity_from'] = 'storyboard/chapter-stories.json#/chapters/1'
            with self.assertRaises((ValueError, jsonschema.ValidationError)): self.validate(p)

    def test_08_names_are_references_and_chapter_titles_are_not_copied(self):
        p = copy.deepcopy(self.plan)
        hero = read(ROOT/'reference/names.json')['characters']['protagonist']['value']
        for text in ([{'text': hero+'의 이야기'}], [{'ref': {'catalog': 'characters', 'id': 'made_up'}}]):
            p['chapters'][0]['units'][0]['main_content'] = text
            with self.assertRaisesRegex(ValueError, 'reference'): self.validate(p)
        p = copy.deepcopy(self.profiles)
        p['characters']['protagonist']['writing_name']['value'] = '하나'
        text = render(self.plan['chapters'][0]['units'][0]['main_content'], indexes(p, self.references), self.raw, p, author=True)
        self.assertIn('하나는', text)
        self.assertNotIn(hero, text)
        self.assertTrue(all('title' not in c for c in self.plan['chapters']))

    def test_09_template_and_author_only_reading_document(self):
        self.assertEqual(self.validate(read(TEMPLATE))['chapters'], 1)
        chapters = copy.deepcopy(self.chapters)
        chapters['chapters'][0]['title'] = [{'text': '중앙에서 바꾼 제목'}]
        page = subsection_document(self.plan, chapters, self.profiles, self.references)
        self.assertIn('제1장 · 중앙에서 바꾼 제목', page)
        self.assertIn('작가 전용', page)
        self.assertIn('전편 스포일러', page)
        self.assertNotIn('onclick="print()"', page)
        self.assertIn('두 봉인 탐색은 모두 필수이며 순서는 자유', page)

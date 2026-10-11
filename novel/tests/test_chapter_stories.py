"""Macro narrative is authored, reference-bound and separate from the reader."""
import copy
import json
import unittest

import jsonschema

from chapter_stories import STORIES, TEMPLATE, STAGES, story_document, validate_stories
from characters import load_characters
from materials import ROOT, read
from reference import load_references
from text_refs import indexes, literals, render
from writing import CHAPTERS


class ChapterStoriesTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.draft, cls.plan = read(STORIES), read(CHAPTERS)
        cls.profiles, cls.references = load_characters(), load_references()
        cls.data, cls.raw = indexes(cls.profiles, cls.references), literals()

    def validate(self, draft):
        return validate_stories(draft, self.plan, self.profiles, self.references)

    def test_01_all_chapters_have_macro_stories_not_fake_completed_prose(self):
        report = self.validate(self.draft)
        self.assertEqual((report['chapters'], report['story_paragraphs'], report['required_beats']), (15, 60, 44))
        self.assertFalse(report['branches_designed'])
        self.assertFalse(report['detailed_prose_complete'])
        self.assertTrue(all(r['mandatory'] for r in self.draft['chapters']))
        for row in self.draft['chapters']:
            text = ''.join(render(row['story'][stage], self.data, self.raw, self.profiles, author=True) for stage in STAGES)
            self.assertGreater(len(text), 600)
            self.assertNotIn('title', row)

    def test_02_omitted_unknown_or_reordered_chapter_is_rejected(self):
        for mode in ('missing', 'unknown', 'reordered'):
            draft = copy.deepcopy(self.draft)
            if mode == 'missing': draft['chapters'].pop()
            elif mode == 'unknown': draft['chapters'][0]['chapter_id'] = 'made_up'
            else: draft['chapters'][1], draft['chapters'][2] = draft['chapters'][2], draft['chapters'][1]
            with self.assertRaisesRegex(ValueError, 'chapter'):
                self.validate(draft)

    def test_03_each_required_beat_must_be_preserved_in_its_chapter(self):
        for mode in ('missing', 'borrowed'):
            draft = copy.deepcopy(self.draft)
            if mode == 'missing': draft['chapters'][0]['beat_refs'].pop()
            else: draft['chapters'][0]['beat_refs'][0] = draft['chapters'][1]['beat_refs'][0]
            with self.assertRaisesRegex(ValueError, 'required beat'):
                self.validate(draft)

    def test_04_causal_handoff_cannot_skip_or_end_early(self):
        for next_id in ('chapter03', None):
            draft = copy.deepcopy(self.draft)
            draft['chapters'][0]['handoff']['next_chapter'] = next_id
            with self.assertRaisesRegex(ValueError, 'handoff'):
                self.validate(draft)

    def test_05_both_seals_remain_flexible_order_required_objectives(self):
        group = self.draft['chapters'][8]['parallel_beat_groups']
        self.assertEqual(group, [['chapter09/first_seal', 'chapter09/second_seal']])
        draft = copy.deepcopy(self.draft)
        draft['chapters'][8]['parallel_beat_groups'][0].reverse()
        self.validate(draft)
        for mode in ('missing', 'unrelated'):
            draft = copy.deepcopy(self.draft)
            if mode == 'missing': draft['chapters'][8]['parallel_beat_groups'] = []
            else: draft['chapters'][8]['parallel_beat_groups'][0][0] = 'chapter08/access'
            with self.assertRaisesRegex(ValueError, 'flexible-order'):
                self.validate(draft)

    def test_06_no_unmarked_addition_public_outline_or_fake_branch_completion(self):
        for mode in ('unmarked', 'public', 'implemented'):
            draft = copy.deepcopy(self.draft)
            if mode == 'unmarked': draft['chapters'][0]['metadata']['addition'] = False
            elif mode == 'public': draft['visibility'] = 'reader'
            else: draft['workflow']['branch_design'] = 'implemented'
            with self.assertRaises((ValueError, jsonschema.ValidationError)):
                self.validate(draft)

    def test_07_hardcoded_names_and_unknown_entity_refs_are_rejected(self):
        hero = read(ROOT/'reference/names.json')['characters']['protagonist']['value']
        for text in ([{'text': hero+'의 이야기'}], [{'ref': {'catalog':'characters', 'id':'made_up'}}]):
            draft = copy.deepcopy(self.draft)
            draft['chapters'][0]['story']['opening'] = text
            with self.assertRaisesRegex(ValueError, 'reference'):
                self.validate(draft)

    def test_08_common_template_and_central_title_reference(self):
        self.assertEqual(self.validate(read(TEMPLATE))['chapters'], 1)
        plan = copy.deepcopy(self.plan)
        plan['chapters'][1]['title'] = [{'text': '중앙에서 바꾼 두 번째 장'}]
        page = story_document(self.draft, plan)
        self.assertIn('제2장 · 중앙에서 바꾼 두 번째 장', page)
        self.assertIn('작가 전용', page)
        self.assertIn('전편 스포일러', page)
        self.assertNotIn('onclick="print()"', page)

    def test_09_name_changes_apply_without_rewriting_macro_text(self):
        before = json.dumps(self.draft, ensure_ascii=False)
        profiles = copy.deepcopy(self.profiles)
        hero = profiles['characters']['protagonist']
        alternate = '새집필별칭가'
        hero['writing_name']['value'] = hero['display_name'] = hero['disclosure']['public_display_name'] = alternate
        data = indexes(profiles, self.references)
        text = render(self.draft['premise'], data, self.raw, profiles, author=True)
        self.assertTrue(text.startswith(alternate+'는'))
        self.assertEqual(before, json.dumps(self.draft, ensure_ascii=False))
        self.assertNotIn(alternate, before)

    def test_10_source_sections_must_exist_and_belong_to_the_same_chapter(self):
        for key in ('missing-section', '02-pyramid'):
            draft = copy.deepcopy(self.draft)
            draft['chapters'][0]['source_section_refs'][0] = key
            with self.assertRaisesRegex(ValueError, 'source section'):
                self.validate(draft)
        draft = copy.deepcopy(self.draft)
        draft['chapters'][0]['source_section_refs'].pop()
        self.validate(draft)  # Evidence selection is not a claim that every variant occurred.

    def test_11_mainline_links_document_learning_to_late_rank_change(self):
        refs = lambda value: [p['ref'] for p in value if 'ref' in p]
        rank = {'catalog':'terms', 'id':'semi_god'}
        self.assertIn(rank, refs(self.draft['chapters'][7]['story']['escalation']))
        self.assertIn(rank, refs(self.draft['chapters'][13]['story']['turning_point']))
        self.assertIn('14-panzer', self.draft['chapters'][13]['source_section_refs'])
        source = read(ROOT/'materials/scripts.json')
        script = next(u for u in source['source_units'] if u['file']=='LORESPEC.PAS')['original_source']
        self.assertIn('joinenemy(1,68); joinenemy(2,67);', script)
        self.assertIn("if player[i].name <> '' then player[i].class := 10;", script)
        self.assertEqual(read(ROOT/'reference/bestiary.json')['items']['enemy_68']['original_name']['value'], 'Lord Ahn')
        self.assertEqual(read(ROOT/'reference/bestiary.json')['items']['enemy_67']['original_name']['value'], 'Ancient Evil')


if __name__ == '__main__': unittest.main()

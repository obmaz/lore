import unittest

from materials import ROOT, read
from characters import load_characters
from reference import load_references
from text_refs import indexes, literals, validate_text, reject_fixed_names


class CausalReviewTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.review=read(ROOT/'writing/storyboard/causal-review.json')
        cls.macro=read(ROOT/'writing/storyboard/chapter-stories.json')
        cls.subsections=read(ROOT/'writing/storyboard/chapter-subsections.json')

    def test_all_chapters_and_source_sections_are_reviewed_without_new_story_facts(self):
        expected=self.macro['chapters']
        self.assertEqual([c['chapter_ref'] for c in self.review['chapters']],[c['chapter_id'] for c in expected])
        for row,chapter in zip(self.review['chapters'],expected):
            self.assertEqual(row['source_sections'],chapter['source_section_refs'])
            self.assertEqual(row['required_beats'],chapter['beat_refs'])
            self.assertEqual(row['next_chapter'],chapter['handoff']['next_chapter'])
            self.assertTrue(row['guard_notes'])
        self.assertEqual(self.review['policy']['approval'],'not_approved_by_structural_checks')
        self.assertTrue(self.review['metadata']['addition'])

    def test_review_pins_current_structure_and_style(self):
        inputs=self.review['inputs']
        self.assertEqual(inputs['macro_revision'],self.macro['revision'])
        self.assertEqual(inputs['subsection_revision'],self.subsections['revision'])
        self.assertEqual(inputs['style_revision'],read(ROOT/inputs['style'])['style']['revision'])
        for key in ['macro_story','subsections','source_manuscript','source_coverage','style']:
            self.assertTrue((ROOT/inputs[key]).is_file())
        self.assertEqual(self.subsections['macro_revision'],self.macro['revision'])

    def test_review_uses_valid_references_and_never_replaces_source_text(self):
        profiles=load_characters()
        data,raw=indexes(profiles,load_references()),literals()
        for row in self.review['chapters']:
            for text in [row['causal_link'],*row['guard_notes']]:
                validate_text(text,data,raw)
                reject_fixed_names(text,data)
        self.assertEqual(self.review['policy']['original_text'],'keep_all_occurrences_and_mutually_exclusive_paths')
        self.assertEqual({c['id'] for c in self.review['changes']},{'optional_visit_memory','parallel_seal_order'})


if __name__=='__main__':
    unittest.main()

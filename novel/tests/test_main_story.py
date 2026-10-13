"""Mandatory backbone: graph shortcuts, actual displayed prose, optional rejoins."""
import copy
import unittest

import jsonschema

from interactive import Session, SCHEMA, check_main_story_route, possible, validate_main_story
from materials import ROOT, read


class MainStoryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.session = Session()

    def sections(self, packet):
        return [*packet['history'], {'node_id': packet['node_id'],
                'visible_block_ids': [b['id'] for b in packet['visible_blocks']]}]

    def test_01_early_veteran_can_only_rejoin_before_lord(self):
        route = ['prologue/enter_courtyard', 'prologue/visit_tavern']
        route, packet = self.session.choose(route,'i/tavern_menu')
        self.assertEqual(packet['available_choices'],['i/late_veteran'])
        route,packet=self.session.choose(route,'i/late_veteran')
        self.assertEqual(packet['available_choices'], ['prologue/remember_veteran'])
        with self.assertRaises(ValueError):
            self.session.choose(route, 'i/late_veteran_back')
        route, _ = self.session.choose(route, 'prologue/remember_veteran')
        route, packet = self.session.choose(route, 'prologue/visit_lord')
        self.assertIn('prologue/lord_intro_dialogue', [b['id'] for b in packet['visible_blocks']])
        self.assertEqual(packet['main_story']['seen_scenes'][-1], 'prologue/audience')

    def test_02_graph_rejects_skipped_lord_and_reordered_core(self):
        for node_id, choice_id, target in [
            ('prologue/courtyard', 'prologue/visit_lord', 'lore_menace/assignment'),
            ('lore_menace/cave_entry', 'lore_menace/walk_deeper', 'lore_menace/center')]:
            story = copy.deepcopy(self.session.story)
            node = next(n for n in story['nodes'] if n['id'] == node_id)
            next(c for c in node['choices'] if c['id'] == choice_id)['target'] = target
            with self.assertRaisesRegex(ValueError, 'bypass/out-of-order'):
                validate_main_story(story, self.session.memory, self.session.overlay['main_story'])

    def test_03_graph_rejects_new_early_ending(self):
        story = copy.deepcopy(self.session.story)
        next(n for n in story['nodes'] if n['id'] == 'prologue/tavern')['kind'] = 'ending'
        with self.assertRaisesRegex(ValueError, 'premature boundary/ending'):
            validate_main_story(story, self.session.memory, self.session.overlay['main_story'])

    def test_04_first_visit_requires_visible_body_not_a_state_flag(self):
        route = ['prologue/enter_courtyard', 'prologue/visit_lord']
        sections = self.sections(self.session.replay(route))
        sections[-1]['visible_block_ids'].remove('prologue/lord_intro_dialogue')
        with self.assertRaisesRegex(ValueError, 'required body hidden'):
            check_main_story_route(self.session.story, self.session.overlay['main_story'], sections)
        with self.assertRaisesRegex(ValueError, 'bypass/out-of-order'):
            check_main_story_route(self.session.story, self.session.overlay['main_story'], sections[-1:])
        with self.assertRaisesRegex(ValueError, 'premature boundary/ending'):
            check_main_story_route(self.session.story, self.session.overlay['main_story'],
                                   [{'node_id': 'lore_menace/next_quest_boundary', 'visible_block_ids': []}])

    def test_05_first_visit_hidden_or_removed_core_is_rejected(self):
        for mutation in ['hide', 'remove', 'author_note']:
            story = copy.deepcopy(self.session.story)
            node = next(n for n in story['nodes'] if n['id'] == 'prologue/audience')
            block = next(b for b in node['blocks'] if b['id'] == 'prologue/lord_intro_dialogue')
            if mutation == 'hide': block['when'] = False
            elif mutation == 'remove': node['blocks'].remove(block)
            else: block['kind'] = 'author_note'
            with self.assertRaisesRegex(ValueError, 'required body'):
                validate_main_story(story, self.session.memory, self.session.overlay['main_story'])

    def test_06_revisit_does_not_require_first_visit_quotes_again(self):
        spine = self.session.overlay['main_story']
        sections = [{'node_id': r['node'], 'visible_block_ids': r['required_block_ids']} for r in spine['required_scenes']]
        center = next(i for i, s in enumerate(sections) if s['node_id'] == 'lore_menace/center')
        sections.insert(center + 1, {'node_id': 'i/treasure_hub', 'visible_block_ids': []})
        sections.insert(center + 2, {'node_id': 'lore_menace/center', 'visible_block_ids': ['i/center_return_from_detour']})
        result = check_main_story_route(self.session.story, spine, sections)
        self.assertTrue(result['complete'])
        self.assertEqual(len(result['seen_scenes']), 17)

    def test_07_unknown_conditions_are_not_pruned_and_guards_are_finite(self):
        self.assertIsNone(possible({'not': {'state': 'unknown', 'op': 'eq', 'value': 1}}, {}))
        self.assertFalse(possible({'all': [False, {'state': 'unknown', 'op': 'eq', 'value': 1}]}, {}))
        story = copy.deepcopy(self.session.story)
        effect = next(e for n in story['nodes'] for c in n['choices'] for e in c['effects'] if e['state'] == 'quest.lore_stage')
        effect['op'] = 'increment'
        with self.assertRaisesRegex(ValueError, 'finite set'):
            validate_main_story(story, self.session.memory, self.session.overlay['main_story'])

    def test_08_common_template_has_provenance_and_valid_shape(self):
        schema = read(SCHEMA)['properties']['main_story']
        template = read(ROOT/'writing/templates/main-story.template.json')
        jsonschema.Draft202012Validator(schema).validate(template)
        self.assertTrue(template['metadata']['addition'])
        invalid = copy.deepcopy(self.session.overlay)
        del invalid['main_story']
        with self.assertRaises(jsonschema.ValidationError):
            jsonschema.Draft202012Validator(read(SCHEMA)).validate(invalid)

    def test_09_shared_scene_cannot_reopen_the_pre_assignment_shortcut(self):
        story = copy.deepcopy(self.session.story)
        node = next(n for n in story['nodes'] if n['id'] == 'prologue/tavern')
        next(c for c in node['choices'] if c['id'] == 'i/late_veteran_back')['when'] = True
        with self.assertRaisesRegex(ValueError, 'bypass/out-of-order'):
            validate_main_story(story, self.session.memory, self.session.overlay['main_story'])


if __name__ == '__main__': unittest.main()

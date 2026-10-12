import copy
import json
import re
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import jsonschema

from materials import read
from side_stories import SideStorySession, SidePublicationFlow, PLAN, CORE_FLOW, export, reader_document


class SideStoryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.flow = SidePublicationFlow()
        cls.session = cls.flow.session
        cls.core_route = read(CORE_FLOW)['linear_editions'][0]['manual_route']

    def test_01_one_authored_proposed_story_in_every_chapter(self):
        stories = self.session.stories
        self.assertEqual(len(stories), 15)
        self.assertEqual(len({s['chapter_id'] for s in stories}), 15)
        for story in stories:
            self.assertEqual(story['origin'], 'authored')
            self.assertEqual(story['status'], 'proposed')
            self.assertTrue(story['metadata']['addition'])
            self.assertEqual(story['metadata']['knowledge_policy'], 'author_reference_not_character_knowledge')
        self.assertEqual(read(PLAN), self.session.proposal)

    def test_02_compiler_changes_only_own_boolean_and_keeps_core_source(self):
        base = self.session.base
        self.assertEqual(base.plan['decisions'], self.session.plan['decisions'][:len(base.plan['decisions'])])
        self.assertEqual(self.session.source_outline, base.outline)
        added = set(self.session.states) - set(base.states)
        self.assertEqual(added, {'side.'+s['id'] for s in self.session.stories})
        for decision in self.session.plan['decisions'][len(base.plan['decisions']):]:
            story = self.session.story_by_decision[decision['id']]
            for mode, option in zip(('take', 'skip'), decision['options']):
                self.assertIs(option['when'], True)
                self.assertEqual(option['participants'], [])
                self.assertEqual([(e['state'], e['op'], e['value']) for e in option['effects']],
                                 [('side.'+story['id'], 'set', mode == 'take')])

    def test_03_paired_core_and_mixed_paths_preserve_mandatory_history(self):
        report = self.session.safety_report
        self.assertEqual(report['core_complete_paths'], 96)
        self.assertEqual(report['witness_paths_checked'], 193)
        self.assertEqual(report['projected_complete_paths'], 3145728)
        self.assertFalse(report['cartesian_paths_enumerated'])
        self.assertTrue(report['mechanical_main_projection_preserved'])
        self.assertFalse(report['prose_approved'])

    def test_04_take_and_skip_have_different_bodies_and_only_their_callbacks(self):
        packets = {mode: self.session.replay(self.session.expand_route(self.core_route, mode)) for mode in ('take', 'skip')}
        for mode, packet in packets.items():
            self.assertEqual(packet['status'], 'complete')
            self.assertEqual(len(packet['visited_units']), 88)
            self.assertEqual(len(packet['completed_beats']), 44)
            for did, story in self.session.story_by_decision.items():
                choices = [h for h in packet['history'] if h.get('decision_id') == did]
                reactions = [h for h in packet['history'] if h['kind'] == 'reaction' and h['id'].startswith(did+'_')]
                self.assertEqual([h['id'] for h in choices], [did+'/'+mode])
                self.assertEqual([h['id'] for h in reactions], [did+'_'+mode])
                self.assertEqual(packet['state']['side.'+story['id']], mode == 'take')
        self.assertEqual(self.session.main_history(packets['take']), self.session.main_history(packets['skip']))
        self.assertNotEqual(packets['take']['history'], packets['skip']['history'])

    def test_05_save_restore_rejects_injected_state_and_out_of_order_choice(self):
        route = self.session.expand_route(self.core_route, 'take')
        saved = self.session.save(route)
        self.assertEqual(self.session.restore(saved), self.session.replay(route))
        saved['state'] = {'side.well_bucket': True}
        with self.assertRaises(ValueError): self.session.restore(saved)
        with self.assertRaises(ValueError): self.session.replay(['side_last_step/take'])

    def test_06_bad_metadata_duplicate_foreign_parallel_and_early_anchor_rejected(self):
        for mode in ('metadata', 'duplicate', 'foreign', 'parallel', 'early'):
            proposal = copy.deepcopy(self.session.proposal)
            if mode == 'metadata': proposal['stories'][0]['metadata']['addition'] = False
            elif mode == 'duplicate': proposal['stories'][1]['id'] = proposal['stories'][0]['id']
            elif mode == 'foreign': proposal['stories'][0]['anchor_unit'] = 'chapter02/p02'
            elif mode == 'parallel': proposal['stories'][8]['anchor_unit'] = next(iter(self.session.base.groups.values()))['entry']
            else: proposal['stories'][0]['reaction_unit'] = proposal['stories'][0]['anchor_unit']
            with self.subTest(mode=mode), self.assertRaises((ValueError, jsonschema.ValidationError)):
                SideStorySession(base=self.session.base, proposal=proposal)

    def test_07_combined_graph_has_all_choices_and_honest_witness_scope(self):
        report = self.flow.report
        self.assertEqual((report['decisions'], report['options'], report['runtime_paths_checked']), (21, 44, 193))
        self.assertTrue(report['acyclic'])
        self.assertFalse(report['publication_approved'])
        self.assertEqual(len(self.flow.editions['editions']), 2)
        for story in self.session.stories:
            self.assertIn(self.session.display(story['title']), self.flow.document())

    def test_08_generated_export_guard_does_not_overwrite_manual_edits(self):
        with tempfile.TemporaryDirectory(prefix='lore-sides-') as temp, patch('side_stories.OUTPUT', Path(temp)):
            export(flow=self.flow)
            self.assertTrue(export(check=True, flow=self.flow)['checked'])
            output = Path(temp)/'side-adventures.html'
            output.write_text('manual edit', encoding='utf-8')
            with self.assertRaisesRegex(ValueError, 'manually edited'): export(flow=self.flow)
            self.assertEqual(output.read_text(encoding='utf-8'), 'manual edit')

    def test_09_preview_has_15_stories_and_inert_safe_json(self):
        document = reader_document(self.flow)
        raw = re.search(r'<script type="application/json" id="side-data">(.*?)</script>', document, re.S).group(1)
        payload = json.loads(raw)
        self.assertEqual(len(payload['chapters']), 15)
        self.assertEqual(len(payload['stories']), 15)
        self.assertNotIn('<', raw)
        self.assertNotIn('fetch(', document)
        self.assertNotIn('localStorage', document)
        self.assertIn('창작', document)

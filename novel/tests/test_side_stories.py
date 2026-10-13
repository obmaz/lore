import copy
from collections import Counter
import json
import re
import tempfile
import unittest
import xml.etree.ElementTree as ET
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

    def test_01_two_authored_proposed_stories_in_every_chapter(self):
        stories = self.session.stories
        self.assertEqual(len(stories), 30)
        self.assertEqual(len({s['chapter_id'] for s in stories}), 15)
        self.assertEqual(set(Counter(s['chapter_id'] for s in stories).values()), {2})
        self.assertEqual(len(self.session.approach_by_decision), 5)
        for story in stories:
            self.assertEqual(story['origin'], 'authored')
            self.assertEqual(story['status'], 'proposed')
            self.assertTrue(story['metadata']['addition'])
            self.assertEqual(story['metadata']['knowledge_policy'], 'author_reference_not_character_knowledge')
        self.assertEqual(read(PLAN), self.session.proposal)

    def test_15_exclusive_nested_callbacks_share_one_row_and_one_join(self):
        chart=next(c for c in self.flow.charts if c['id']=='chapter13')
        groups=self.flow.graph['presentation']['groups']
        group=next(g for g in groups if any('loose_stair_approach' in key for key in g['node_ids']))
        self.assertEqual(len(group['node_ids']),3)  # skip or either nested approach
        self.assertTrue(group['proof']['at_most_one'])
        self.assertTrue(group['proof']['exhaustive'])
        self.assertTrue(group['proof']['required_visits_guaranteed'])
        self.assertFalse(group['bypass_possible'])
        ns={'s':'http://www.w3.org/2000/svg'}
        svg=ET.fromstring(self.flow.svg(chart['node_ids']))
        boxes={n.attrib['data-flow-node']:n for n in svg.findall('s:g',ns) if n.attrib.get('class')=='flow-node'}
        rows={boxes[key].find('s:rect',ns).attrib['y'] for key in group['node_ids']}
        self.assertEqual(len(rows),1)
        self.assertEqual(len({boxes[key].find('s:rect',ns).attrib['x'] for key in group['node_ids']}),3)
        self.assertIn(group['join_id'],boxes)
        self.assertTrue(set(group['hidden_merge_ids']).isdisjoint(boxes))
        edges={(e.attrib['data-from'],e.attrib['data-to']) for e in svg.findall('s:g',ns) if e.attrib.get('class')=='flow-edge'}
        for key in group['node_ids']:
            self.assertIn((group['entry_id'],key),edges)
            self.assertIn((key,group['join_id']),edges)
            self.assertEqual(boxes[key].attrib['data-exclusive-group'],group['id'])
        # Presentation must not rewrite replay/technical DAG or chart membership.
        logical={n['id'] for n in self.flow.nodes}
        self.assertTrue(set(group['hidden_merge_ids'])<=logical)
        self.assertTrue(set(group['hidden_merge_ids'])<=set(chart['node_ids']))

    def test_16_exclusivity_is_proven_not_inferred_from_two_witness_routes(self):
        a={'state':'side.loose_stair','op':'eq','value':True}
        inverse={**a,'op':'ne'}
        b={'state':'side.well_bucket','op':'eq','value':True}
        proof=self.flow.exclusive_conditions([a,inverse])
        self.assertTrue(proof['exhaustive'])
        self.assertIsNone(self.flow.exclusive_conditions([a,b]))
        self.assertIsNone(self.flow.exclusive_conditions([a,a]))
        self.assertIsNone(self.flow.exclusive_conditions([{'state':'companions.current','op':'contains','value':'skeleton'},a]))

    def test_17_partial_callback_chart_does_not_hide_unrelated_merge_nodes(self):
        group=next(g for g in self.flow.graph['presentation']['groups'] if len(g['node_ids'])==3)
        original={group['entry_id'],group['node_ids'][0],group['hidden_merge_ids'][0]}
        keys=list(original)
        edges=[e for e in self.flow.edges if e['from'] in original and e['to'] in original]
        out,shown,links,membership=self.flow.svg_presentation(original,keys,edges)
        self.assertEqual(out,original)
        self.assertEqual(shown,keys)
        self.assertEqual(links,edges)
        self.assertEqual(membership,{})

    def test_18_unproven_visit_and_participant_gates_keep_no_result_bypass(self):
        group=next(g for g in self.flow.graph['presentation']['groups'] if len(g['node_ids'])==3)
        rule=self.flow.resolve(next(n for n in self.flow.nodes if n['id']==group['node_ids'][0])['guard_ref'])
        for change in ({'requires_units':['chapter15/p06']},{'participants':['skeleton']}):
            with patch.dict(rule,change):
                result=next(g for g in self.flow.reaction_presentation()['groups'] if g['id']==group['id'])
                self.assertTrue(result['bypass_possible'])

    def test_02_compiler_changes_only_own_boolean_and_keeps_core_source(self):
        base = self.session.base
        self.assertEqual(base.plan['decisions'], self.session.plan['decisions'][:len(base.plan['decisions'])])
        self.assertEqual(self.session.source_outline, base.outline)
        added = set(self.session.states) - set(base.states)
        self.assertEqual(added, {'side.'+s['id'] for s in self.session.stories} | {'side.'+s['id']+'.approach' for s in self.session.approach_by_decision.values()})
        for decision in self.session.plan['decisions'][len(base.plan['decisions']):]:
            if decision['id'] in self.session.approach_by_decision:
                story=self.session.approach_by_decision[decision['id']]
                for index,option in enumerate(decision['options'][:2]):
                    self.assertEqual(option['when'],{'op':'eq','state':'side.'+story['id'],'value':True})
                    self.assertEqual([(e['state'],e['op'],e['value']) for e in option['effects']], [('side.'+story['id']+'.approach','set',bool(index))])
                bypass=decision['options'][2]
                self.assertEqual(bypass['effects'],[])
                self.assertEqual(bypass['when'],{'op':'eq','state':'side.'+story['id'],'value':False})
                continue
            story = self.session.story_by_decision[decision['id']]
            for mode, option in zip(('take', 'skip'), decision['options']):
                self.assertIs(option['when'], True)
                self.assertEqual(option['participants'], [])
                self.assertEqual([(e['state'], e['op'], e['value']) for e in option['effects']],
                                 [('side.'+story['id'], 'set', mode == 'take')])

    def test_03_paired_core_and_mixed_paths_preserve_mandatory_history(self):
        report = self.session.safety_report
        self.assertEqual(report['core_complete_paths'], 96)
        self.assertEqual(report['witness_paths_checked'], 198)
        self.assertEqual(report['projected_complete_paths'], 96*2**25*3**5)
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
                reactions = [h for h in packet['history'] if h['kind'] == 'reaction' and (h['id'] in (did+'_take',did+'_skip') or h['id'].startswith(did+'_approach_'))]
                self.assertEqual([h['id'] for h in choices], [did+'/'+mode])
                expected=did+'_approach_'+story['approach']['options'][0]['id'] if mode=='take' and 'approach' in story else did+'_'+mode
                self.assertEqual([h['id'] for h in reactions], [] if story['reaction_unit'] is None else [expected])
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
        self.assertEqual((report['decisions'], report['options'], report['runtime_paths_checked']), (41, 89, 198))
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

    def test_09_preview_has_30_stories_and_inert_safe_json(self):
        document = reader_document(self.flow)
        raw = re.search(r'<script type="application/json" id="side-data">(.*?)</script>', document, re.S).group(1)
        payload = json.loads(raw)
        self.assertEqual(len(payload['chapters']), 15)
        self.assertEqual(len(payload['stories']), 30)
        self.assertEqual(sum('approach' in s for s in payload['stories']),5)
        self.assertNotIn('<', raw)
        self.assertNotIn('fetch(', document)
        self.assertNotIn('localStorage', document)
        self.assertIn('창작', document)

    def test_10_cross_chapter_result_reference_is_visible_without_changing_read_nodes(self):
        chart=next(c for c in self.flow.charts if c['id']=='chapter09')
        original=list(chart['node_ids'])
        keys=self.flow.svg_keys(original)
        self.assertIn('reaction/side_return_knots_take',keys)
        self.assertIn('reaction/side_return_knots_skip',keys)
        self.assertNotIn('reaction/side_return_knots_take',original)
        svg=self.flow.svg(original)
        self.assertIn('다른 장 참고 · 10-1',svg)
        self.assertIn('후속 반응 발췌',svg)
        self.assertEqual(chart['node_ids'],original)
        self.assertIn('data-link="L',svg)
        # Repeat the geometry assertions on all 15 composed charts, including
        # external references; do not register another copy of that test class.
        import test_publication_flow
        test_publication_flow.PublicationFlowTests.test_13_all_dotted_svg_routes_are_orthogonal_and_avoid_box_interiors(self)

    def test_11_timeline_places_each_callback_in_its_real_chapter_not_an_external_stub(self):
        timeline=self.flow.graph['timeline'];found={}
        for chapter in timeline['chapters']:
            for row in chapter['rows']:
                for card in row.get('cards',[]):
                    if row['kind']=='reaction':found[card['node_id']]=(chapter['chapter_id'],row['unit_id'],row['group_id'],card['source_options'])
        for did,story in self.session.story_by_decision.items():
            if story['reaction_unit'] is None:
                self.assertFalse(any(key.startswith('reaction/'+did+'_') for key in found))
                continue
            for index,mode in enumerate(('take','skip')):
                if mode=='take' and 'approach' in story:continue
                self.assertEqual(found['reaction/'+did+'_'+mode],(story['reaction_unit'].split('/')[0],story['reaction_unit'],did,[did+'/'+mode]))
        for aid,story in self.session.approach_by_decision.items():
            group=timeline['groups'][aid]
            self.assertEqual(group['parent_option'],'side_'+story['id']+'/take')
            self.assertEqual(len(group['options']),2)
            for option in story['approach']['options']:
                self.assertEqual(found['reaction/'+aid+'_'+option['id']],(story['reaction_unit'].split('/')[0],story['reaction_unit'],aid,[aid+'/'+option['id']]))
        nodes={card['node_id'] for c in timeline['chapters'] for row in c['rows'] for card in row.get('cards',[])}
        self.assertFalse(any(key.endswith('/bypass') for key in nodes))
        self.assertEqual({key for key in nodes if key.startswith('option/')},{'option/'+key for key in self.flow.option_paths if not key.endswith('/bypass')})
        self.assertEqual({key for key in nodes if key.startswith('reaction/')},{'reaction/'+key for key in self.flow.reaction_paths})
        for chapter in timeline['chapters']:
            for row in chapter['rows']:
                if row['kind']=='reaction' and row['group_id'] in self.session.approach_by_decision:
                    self.assertEqual(len(row['cards']),2)

    def test_12_nested_alternatives_have_own_callbacks_and_skip_never_exposes_them(self):
        for aid,story in self.session.approach_by_decision.items():
            parent='side_'+story['id']
            for option in story['approach']['options']:
                route=self.session.expand_route(self.core_route,'skip',overrides={parent:'take'},approaches={aid:option['id']})
                packet=self.session.replay(route)
                self.assertIn(aid+'/'+option['id'],route)
                self.assertIn(aid+'_'+option['id'],[h.get('id') for h in packet['history']])
            route=self.session.expand_route(self.core_route,'skip')
            packet=self.session.replay(route)
            self.assertIn(aid+'/bypass',packet['automatic_options'])
            self.assertFalse(any(h['kind']=='reaction' and h['id'].startswith(aid+'_') for h in packet['history']))
            boundary=route.index(parent+'/skip')+1
            with self.assertRaises(ValueError):self.session.replay([*route[:boundary],aid+'/'+story['approach']['options'][0]['id']])

    def test_13_nested_schema_cannot_inject_core_writes_or_recruitment(self):
        for field in ('effects','participants','when'):
            proposal=copy.deepcopy(self.session.proposal)
            story=next(s for s in proposal['stories'] if 'approach' in s)
            story['approach']['options'][0][field]=[]
            with self.assertRaises(jsonschema.ValidationError):SideStorySession(base=self.session.base,proposal=proposal)

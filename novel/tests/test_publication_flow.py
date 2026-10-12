"""A reference-bound tree/DAG and actual route, not a second story source."""
import copy
import tempfile
import unittest
from pathlib import Path

import jsonschema

from publication_flow import PublicationFlow, export
from branch_system import BranchSession


class PublicationFlowTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.flow = PublicationFlow()

    def fresh(self):
        return PublicationFlow(session=self.flow.session)

    def test_01_tree_and_graph_preserve_all_main_units_and_runtime_paths(self):
        report = self.flow.report
        self.assertEqual((report['chapters'], report['subsections'], report['decisions'], report['options'], report['runtime_paths_checked']), (15,88,6,14,96))
        self.assertTrue(report['acyclic'])
        self.assertFalse(report['publication_approved'])
        self.assertEqual([c['number'] for c in self.flow.tree],list(range(1,16)))
        self.assertEqual(sum(len(c['children']) for c in self.flow.tree),88)

    def test_02_headings_and_bodies_are_refs_and_snapshots_not_new_authoring_text(self):
        for node in self.flow.nodes:
            self.assertEqual(node['label_rich_text'], self.flow.resolve(node['label_ref']))
            if node.get('content_ref'): self.flow.resolve(node['content_ref'])
        for edition in self.flow.editions['editions']:
            self.assertFalse(edition['publication_approved'])
            self.assertTrue(all(r['page'] is None for r in edition['rows']))
            self.assertEqual(len(edition['main_unit_order']),88)
            self.assertEqual(len(edition['completed_beats']),44)
        chapters = copy.deepcopy(self.flow.chapters)
        chapters['chapters'][0]['title'] = [{'text':'중앙에서 바꾼 장 제목'}]
        changed = PublicationFlow(session=self.flow.session,chapters=chapters)
        self.assertIn('중앙에서 바꾼 장 제목',changed.markdown())

    def test_03_two_decisions_inside_same_unit_merge_locally_before_next_main(self):
        edges = {(e['from'],e['to']) for e in self.flow.edges}
        self.assertIn(('merge/prepare','decision/company'),edges)
        self.assertNotIn(('merge/prepare','unit/chapter01/p06'),edges)
        self.assertIn(('merge/company','outcome/chapter01/p05'),edges)
        self.assertIn(('outcome/chapter01/p05','unit/chapter01/p06'),edges)

    def test_04_parallel_orders_use_scoped_instances_without_false_cycles(self):
        aliases = [n for n in self.flow.nodes if n['kind']=='unit' and n['unit_id']=='chapter09/p02']
        self.assertEqual({n['context'] for n in aliases},{'seal_order/evil_first','seal_order/muddy_first'})
        for choice in ('seal_order/evil_first','seal_order/muddy_first'):
            prefix=['prepare/self','company/leave','aid/together','spica_company/continue',choice,'shelter_prepare/food']
            packet=self.flow.session.replay(prefix)
            seq=self.flow.trace(packet)
            self.assertIn('unit/chapter09/p02@'+choice,seq)
            self.assertIn('unit/chapter09/p04@'+choice,seq)
            self.assertIn('merge/seal_order',seq)

    def test_05_followup_edges_have_real_runtime_witnesses_not_broad_member_overlap(self):
        links=[e for e in self.flow.edges if e['kind']=='influence']
        self.assertGreaterEqual(len(links),7)
        self.assertNotIn(('option/company/join','reaction/aid_cook_memory'),[(e['from'],e['to']) for e in links])
        for edge in links:
            seq=self.flow.trace(self.flow.session.replay(edge['witness_route']))
            self.assertLess(seq.index(edge['from']),seq.index(edge['to']))

    def test_06_export_checks_freshness_and_refuses_manually_changed_generated_artifacts(self):
        with tempfile.TemporaryDirectory(prefix='lore-publication-flow-') as temporary:
            output=Path(temporary)
            self.assertFalse(export(output=output,flow=self.flow)['checked'])
            self.assertTrue(export(check=True,output=output,flow=self.flow)['checked'])
            plan=copy.deepcopy(self.flow.plan); plan['revision']+=1
            changed=PublicationFlow(plan=plan,session=self.flow.session)
            with self.assertRaisesRegex(ValueError,'stale'): export(check=True,output=output,flow=changed)
            # A legitimate changed-input regeneration keeps the prior output intact until checked.
            export(output=output,flow=changed)
            (output/'flow.md').write_text('manual edit',encoding='utf-8')
            with self.assertRaisesRegex(ValueError,'manually edited'): export(output=output,flow=changed)

    def test_07_unsafe_refs_dangling_edges_cycles_and_heading_drift_are_rejected(self):
        with self.assertRaisesRegex(ValueError,'unsafe'):
            self.flow.resolve({'file':'../../outside.json','pointer':'/value'})
        for mode in ('edge','cycle','label'):
            f=self.fresh()
            if mode=='edge': f.edges[0]['to']='does_not_exist'
            elif mode=='cycle': f.edge(f.graph['exit'],f.graph['entry'])
            else: f.nodes[0]['label_rich_text']=[{'text':'다른 제목'}]
            with self.assertRaisesRegex(ValueError,'edge|cycle|snapshot'): f.validate()

    def test_08_public_approved_partial_route_and_bad_caption_plan_are_rejected(self):
        for mode in ('public','approved','partial','caption'):
            plan=copy.deepcopy(self.flow.plan)
            if mode=='public':plan['visibility']='reader'
            elif mode=='approved':plan['linear_editions'][0]['status']='approved'
            elif mode=='partial':plan['linear_editions'][0]['manual_route']=[]
            else:plan['decision_titles'].pop('prepare')
            with self.assertRaises((ValueError,jsonschema.ValidationError)):
                PublicationFlow(plan=plan,session=self.flow.session)

    def test_09_markdown_and_offline_svg_show_titles_no_external_service_or_print_button(self):
        md=self.flow.markdown(); document=self.flow.document()
        self.assertEqual(md.count('```mermaid'),17)
        self.assertIn('소제목 트리',md)
        self.assertIn('출발 준비',md)
        self.assertIn('publication',self.flow.graph['references'][-1])
        self.assertIn('<svg ',document)
        self.assertIn('제1장',document)
        self.assertNotIn('<script',document)
        self.assertNotIn('onclick="print()"',document)
        self.assertIn('미정',document)

    def test_10_linear_edition_can_choose_other_order_without_changing_graph_or_canon(self):
        p=copy.deepcopy(self.flow.plan)
        p['linear_editions'][0]['manual_route'][3]='seal_order/muddy_first'
        f=PublicationFlow(plan=p,session=self.flow.session)
        keys=f.editions['editions'][0]['main_unit_order']
        self.assertLess(keys.index('chapter09/p04'),keys.index('chapter09/p02'))
        self.assertFalse(f.editions['editions'][0]['publication_approved'])
        self.assertEqual(len(f.tree),15)

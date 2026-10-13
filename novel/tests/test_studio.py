import copy
import html
import json
import re
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import jsonschema

from studio import build, document, export, package_path, validate_plan, verify_previews, readable_claims, PLAN, OUTPUT
from materials import ROOT, read
from publication_flow import PublicationFlow
from side_stories import SidePublicationFlow


class StudioTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.flow = PublicationFlow()
        cls.side_flow = SidePublicationFlow(base=cls.flow.session)
        cls.data = build(publication=cls.flow,side_publication=cls.side_flow)

    def test_01_every_preview_is_available_without_opening_another_file(self):
        expected = {name for name in read(ROOT/'writing/previews/manifest.json')['artifacts'] if name.endswith('.html')}
        self.assertEqual({d['id'] for d in self.data['documents']},expected)
        self.assertEqual(len(expected),12)
        self.assertEqual({d['id'] for d in self.data['documents'] if d['reader_edition']},
                         {'chapter01-interactive.html','chapter01-web.html'})
        self.assertEqual({d['id'] for d in self.data['documents'] if d['branch_preview']},{'side-adventures.html'})
        for row in self.data['documents']:
            self.assertEqual(row['html'],(ROOT/row['source_ref']).read_text(encoding='utf-8'))

    def test_02_full_tree_and_graph_use_existing_titles_and_stable_ids(self):
        chapters = self.data['chapters']
        self.assertEqual(len(chapters),15)
        self.assertEqual(sum(len(c['units']) for c in chapters),88)
        for c in chapters:
            self.assertIn('<svg',c['svg'])
            for u in c['units']:
                self.assertEqual(u['title'],self.side_flow.session.display(self.side_flow.resolve(u['heading_ref'])))
                self.assertIn(u['source_ref']['file'],self.data['sources'])
        self.assertEqual(self.data['editions'],[*self.flow.editions['editions'],*self.side_flow.editions['editions']])

    def test_03_settings_include_master_relationships_and_original_addition_markers(self):
        counts = {c:sum(r['category']==c for r in self.data['settings']) for c in ('characters','relationships','equipment','abilities','bestiary')}
        self.assertEqual(counts,{'characters':53,'relationships':35,'equipment':24,'abilities':45,'bestiary':75})
        hero = next(r for r in self.data['settings'] if r['id']=='characters/protagonist')
        self.assertEqual(hero['title'],'서진')
        self.assertIn('창작 추가',hero['html'])
        self.assertIn('허용 복선',''.join(r['html'] for r in self.data['settings']))

    def test_04_inert_json_cannot_close_script_or_inject_parent_html(self):
        data=copy.deepcopy(self.data)
        data['plan']['title']='</script><script>alert(1)</script>'
        data['documents'][0]['html']='</script><img src=x onerror=alert(1)>'
        output=document(data)
        raw=re.search(r'<script id="studio-data" type="application/json">(.*?)</script>',output,re.S).group(1)
        self.assertNotIn('<',raw)
        self.assertEqual(json.loads(raw),data)
        self.assertNotIn('<title></script>',output)

    def test_05_public_or_duplicate_nav_or_unknown_default_is_rejected(self):
        for mode in ('public','duplicate','default'):
            plan=copy.deepcopy(self.data['plan'])
            if mode=='public': plan['visibility']='reader'
            elif mode=='duplicate': plan['navigation'][1]=plan['navigation'][0]
            else: plan['default_document']='not-real.html'
            with self.assertRaises((ValueError,jsonschema.ValidationError)):
                build(publication=self.flow,plan=plan)

    def test_06_output_is_deterministic_offline_and_read_only(self):
        output=document(self.data)
        self.assertEqual(output,document(self.data))
        for network in ('fetch(', 'src="http', 'href="http', '@import', 'url(http', 'localStorage'):
            self.assertNotIn(network,output)
        self.assertIn('sandbox="allow-scripts allow-downloads"',output)
        self.assertNotIn('allow-same-origin',output)
        self.assertNotIn('window.print(',output)
        self.assertIn('공개 /novel',output)
        self.assertEqual(validate_plan()['views'],7)

    def test_direct_entry_resizing_and_shared_style(self):
        output=document(self.data)
        self.assertNotIn('id="open-studio"',output)
        self.assertNotIn('id="author-gate"',output)
        self.assertIn('<div id="workspace">',output)
        self.assertIn('role="separator"',output)
        self.assertIn('setPointerCapture',output)
        self.assertNotIn("['timeline','비교 타임라인']",output)
        self.assertNotIn('같은 장의 주요 내용</button>',output)
        style=self.data['sources']['writing/project.json']['style']
        self.assertGreaterEqual(style['revision'],1)
        self.assertIn('outline',style['stage_policy'])
        self.assertIn('prose',style['stage_policy'])
        nested=self.data['graph_details']['decision/side_gate_lantern_approach']['options']
        self.assertEqual(len(nested),2)
        self.assertTrue(all(not o['id'].endswith('/bypass') for o in nested))
        self.assertIn('fact-card fact-long',readable_claims([dict(self.flow.session.profiles['characters']['mad_joe']['writing']['traits'][0],field='personality')]))

    def test_07_export_matches_and_preserves_manually_changed_output(self):
        with tempfile.TemporaryDirectory(prefix='lore-studio-') as temp:
            with patch('studio.build',return_value=self.data):
                report=export(output=temp)
                self.assertFalse(report['checked'])
                self.assertTrue(export(check=True,output=temp)['checked'])
                path=Path(temp)/'index.html'
                path.write_text('manual edit',encoding='utf-8')
                with self.assertRaisesRegex(ValueError,'manually edited'): export(output=temp)
                self.assertEqual(path.read_text(),'manual edit')

    def test_08_paths_cannot_escape_independent_package(self):
        for path in ('../outside.json','/etc/passwd'):
            with self.assertRaisesRegex(ValueError,'escapes novel'): package_path(path)

    def test_09_committed_bundle_is_fresh_and_public_reader_contains_no_studio(self):
        with patch('studio.build',return_value=self.data):
            self.assertTrue(export(check=True)['checked'])
        reader=(ROOT/'writing/previews/chapter01-interactive.html').read_text(encoding='utf-8')
        self.assertNotIn('studio-data',reader)
        self.assertNotIn('studio/generated',reader)

    def test_10_readable_sections_keep_metadata_and_actual_graph_questions(self):
        hero=next(row for row in self.data['settings'] if row['id']=='characters/protagonist')
        self.assertEqual(set(hero['sections']),{'핵심 설정','원작 정보','관계 · 공개'})
        self.assertIn('fact-evidence',hero['sections']['핵심 설정'])
        self.assertIn('창작 추가',hero['sections']['핵심 설정'])
        first=[d for d in self.data['chapters'][0]['decisions'] if not d['id'].startswith('side_')]
        self.assertEqual([d['id'] for d in first],['prepare','company'])
        self.assertEqual(first[0]['prompt'],self.flow.session.display(self.flow.session.plan['decisions'][0]['prompt']))

    def test_11_unified_view_keeps_all_chapter_filtered_branch_details(self):
        self.assertNotIn('branches',[r['id'] for r in self.data['plan']['navigation']])
        for c in self.data['chapters']:
            details=c['branch_html']
            decisions=[d for d in self.side_flow.session.plan['decisions'] if d['unit_id'].split('/')[0]==c['id']]
            self.assertEqual(details.count('class="unit branch-rule"'),len(decisions))
            self.assertEqual(details.count('class="branch-option"'),sum(len(d['options']) for d in decisions))
            self.assertIn('공통 분기 규칙',details)
            for d in decisions:
                self.assertIn(html.escape(self.flow.session.display(d['prompt'])),details)
                for o in d['options']:
                    self.assertIn(html.escape(self.flow.session.display(o['body'])),details)
                    self.assertIn(html.escape(self.flow.session.display(o['label'])),c['svg'])
            for r in self.side_flow.session.plan['reactions']:
                if r['unit_id'].split('/')[0]==c['id']:
                    self.assertIn(html.escape(self.flow.session.display(r['text'])),details)
        runtime=(ROOT/'writing/studio/studio.js').read_text(encoding='utf-8')
        self.assertNotIn('branch-questions',runtime)
        self.assertNotIn('이 장의 질문과 선택',runtime)
        self.assertIn("view==='branches'?'graph'",runtime)

    def test_12_dense_claims_keep_values_and_provenance_without_empty_cards(self):
        profile=self.flow.session.profiles['characters']['mad_joe']
        claims=[profile['korean_name'],*profile['biography'].values()]
        output=readable_claims(claims)
        self.assertEqual(output.count('data-field='),len(claims))
        for c in claims:
            self.assertIn('data-field="'+c['field']+'"',output)
            self.assertIn(html.escape(c['metadata']['note']),output)
        unknown=readable_claims([profile['biography']['age']])
        self.assertIn('<div class="fact-status"></div>',unknown)
        self.assertIn('분류: 미상 · 검토 상태: 미상',unknown)
        long_claim=copy.deepcopy(profile['biography']['age'])
        long_claim['value']={'note':'</details><script>alert(1)</script>'}
        long_claim['metadata']['note']='</details><script>alert(2)</script>'
        rendered=readable_claims([long_claim])
        self.assertIn('fact-card fact-long',rendered)
        self.assertNotIn('<script>',rendered)
        self.assertIn('&lt;script&gt;',rendered)

    def test_13_graph_detail_body_and_rules_come_from_exact_original_references(self):
        details=self.data['graph_details']
        for node in self.side_flow.nodes:
            if node['kind'] not in ('option','reaction'):continue
            row=details[node['id']]
            self.assertEqual(row['source_ref'],node['content_ref'])
            self.assertEqual(row['body'],self.side_flow.session.display(self.side_flow.resolve(node['content_ref'])))
            rule=self.side_flow.resolve(node['guard_ref'])
            self.assertEqual(row['rules']['when'],rule['when'])
        self.assertEqual(details['option/side_return_knots/take']['rules']['origin'],'authored')
        self.assertTrue(details['option/side_return_knots/take']['rules']['metadata']['addition'])

    def test_14_timeline_groups_and_all_card_bodies_are_reference_bound(self):
        self.assertEqual(len(self.data['timeline']['chapters']),15)
        for gid,group in self.data['timeline']['groups'].items():
            self.assertEqual(group['title'],self.side_flow.session.display(self.side_flow.resolve(group['title_ref'])))
            for option in group['options']:
                self.assertEqual(option['label'],self.side_flow.session.display(self.side_flow.resolve(option['label_ref'])))
        for node in self.side_flow.nodes:
            if node['kind'] in ('unit','outcome'):
                self.assertEqual(self.data['graph_details'][node['id']]['body'],self.side_flow.session.display(self.side_flow.resolve(node['content_ref'])))


if __name__=='__main__': unittest.main()

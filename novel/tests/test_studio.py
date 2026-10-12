import copy
import json
import re
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import jsonschema

from studio import build, document, export, package_path, validate_plan, verify_previews, PLAN, OUTPUT
from materials import ROOT, read
from publication_flow import PublicationFlow


class StudioTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.flow = PublicationFlow()
        cls.data = build(publication=cls.flow)

    def test_01_every_preview_is_available_without_opening_another_file(self):
        expected = {name for name in read(ROOT/'writing/previews/manifest.json')['artifacts'] if name.endswith('.html')}
        self.assertEqual({d['id'] for d in self.data['documents']},expected)
        self.assertEqual(len(expected),27)
        for row in self.data['documents']:
            self.assertEqual(row['html'],(ROOT/row['source_ref']).read_text(encoding='utf-8'))

    def test_02_full_tree_and_graph_use_existing_titles_and_stable_ids(self):
        chapters = self.data['chapters']
        self.assertEqual(len(chapters),15)
        self.assertEqual(sum(len(c['units']) for c in chapters),88)
        for c in chapters:
            self.assertIn('<svg',c['svg'])
            for u in c['units']:
                self.assertEqual(u['title'],self.flow.session.display(self.flow.resolve(u['heading_ref'])))
                self.assertIn(u['source_ref']['file'],self.data['sources'])
        self.assertEqual(self.data['editions'],self.flow.editions['editions'])

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
        self.assertEqual(validate_plan()['views'],8)

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
        first=self.data['chapters'][0]['decisions']
        self.assertEqual([d['id'] for d in first],['prepare','company'])
        self.assertEqual(first[0]['prompt'],self.flow.session.display(self.flow.session.plan['decisions'][0]['prompt']))


if __name__=='__main__': unittest.main()

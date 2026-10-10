import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from export_reference import claim_html, documents
from materials import ROOT


class ReferenceExportTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.docs,cls.manifest = documents(['enter_courtyard','visit_lord'])

    def test_safe_file_has_no_author_payload_or_future_roster(self):
        safe = self.docs['reference-safe.html']
        self.assertNotIn('<template id="author-content">',safe)
        self.assertNotIn('id="author-mode"',safe)
        for secret in ['false_necromancer','hunter_spouse','world_prophecy','reported_friendship','joe_departure','사칭자']:
            self.assertNotIn(secret,safe)
        self.assertNotIn('관계 목록 · 역방향 중복 제외',safe)

    def test_author_data_is_in_inert_template_not_initial_view(self):
        author = self.docs['reference.html']
        main = author.split('<main id="content">',1)[1].split('</main>',1)[0]
        self.assertNotIn('사칭자',main)
        self.assertIn('<template id="author-content">',author)
        self.assertIn('작가 전용 · 전편 스포일러 포함',author)
        self.assertIn('허용 복선',author)
        self.assertNotIn('id="author-mode" checked',author)

    def test_full_catalog_counts_and_metadata_are_preserved(self):
        self.assertEqual(self.manifest['counts'],{'characters':49,'relationships':35,'directed_links':48,
                                                  'equipment':20,'abilities':45,'bestiary':75,'quests':19})
        author = self.docs['reference.html']
        for text in ['창작 추가','추론 추가','음역 추가','인물의 증언','문서의 설명','LORETALK.PAS','퀘스트 흐름']:
            self.assertIn(text,author)

    def test_rendering_is_deterministic_and_offline(self):
        docs,manifest = documents(['enter_courtyard','visit_lord'])
        self.assertEqual(docs,self.docs)
        self.assertEqual(manifest,self.manifest)
        for doc in docs.values():
            for network in ['src="http','href="http','fetch(','@import','url(http']:
                self.assertNotIn(network,doc)

    def test_untrusted_setting_text_is_escaped(self):
        claim = {'value':'<script>alert("x")</script>','origin':'authored','status':'proposed','evidence':[],
                 'metadata':{'kind':'new_setting','addition':True,'note':'<img src=x onerror=alert(1)>'}}
        rendered = claim_html(claim)
        self.assertNotIn('<script>',rendered)
        self.assertNotIn('<img',rendered)
        self.assertIn('&lt;script&gt;',rendered)

    def test_export_check_rejects_modified_output(self):
        with tempfile.TemporaryDirectory(prefix='lore-reference-export-') as temp:
            output = Path(temp)
            for name,body in self.docs.items():
                (output/name).write_text(body,encoding='utf-8')
            (output/'manifest.json').write_text(json.dumps(self.manifest),encoding='utf-8')
            command = [sys.executable,str(ROOT/'tools/export_reference.py'),'--output',temp,'--check']
            self.assertEqual(subprocess.run(command,capture_output=True).returncode,0)
            (output/'reference-safe.html').write_text('modified',encoding='utf-8')
            result = subprocess.run(command,text=True,capture_output=True)
            self.assertNotEqual(result.returncode,0)
            self.assertIn('reference output differs',result.stderr)


if __name__=='__main__':
    unittest.main()

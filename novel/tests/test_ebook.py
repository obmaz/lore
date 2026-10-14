import base64
import copy
import hashlib
import io
import json
import re
import unittest
import zipfile
from xml.etree import ElementTree as ET
from materials import ROOT,read
from cover_art import PLAN as COVER_PLAN,load_covers
from ebook import OUTPUT,PLAN,payload_from_page,validate_epub


class EbookTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.plan=read(PLAN);cls.report=read(OUTPUT/'report.json')
        cls.book=(OUTPUT/cls.plan['filename']).read_bytes()
        cls.archive=zipfile.ZipFile(io.BytesIO(cls.book))
        cls.payload=payload_from_page((ROOT/'writing/previews/chapter01-web.html').read_text())

    @classmethod
    def tearDownClass(cls):cls.archive.close()

    def test_epub_has_uncompressed_first_mimetype_and_valid_xml_package(self):
        self.assertTrue(validate_epub(self.book)['valid_package'])
        self.assertEqual(self.archive.namelist()[0],'mimetype')
        self.assertEqual(self.archive.getinfo('mimetype').compress_type,zipfile.ZIP_STORED)

    def test_epub_uses_four_identical_shared_images(self):
        covers=load_covers()
        a=json.loads(re.search(r'id="chapter-data">(.*?)</script>',(ROOT/'writing/previews/chapter01-interactive.html').read_text(),re.S)[1])
        self.assertEqual(a['covers'],self.payload['covers'])
        for key,image in covers['images'].items():
            body=(ROOT/image['file']).read_bytes()
            self.assertEqual(self.archive.read('OEBPS/images/'+image['file'].split('/')[-1]),body)
            self.assertEqual(base64.b64decode(self.payload['covers']['images'][key]['src'].split(',',1)[1]),body)
            self.assertTrue(image['metadata']['addition'])

    def test_chapter_scope_no_choice_ui_subtitles_or_speaker_labels(self):
        for chapter in self.plan['chapter_ids']:
            document=ET.fromstring(self.archive.read('OEBPS/'+chapter+'.xhtml'))
            ns={'h':'http://www.w3.org/1999/xhtml'}
            self.assertEqual(len(document.findall('.//h:h1',ns)),1)
            self.assertEqual(document.findall('.//h:h2',ns),[])
            self.assertEqual(document.findall('.//h:script',ns),[])
            self.assertEqual(document.findall('.//h:button',ns),[])
            self.assertEqual(document.findall('.//h:blockquote',ns),[])
            self.assertEqual(document.findall('.//h:small',ns),[])
            paragraphs=''.join(''.join(p.itertext())for p in document.findall('.//h:p',ns))
            self.assertNotIn('이 게임',paragraphs)
            self.assertNotIn('선택:',paragraphs)
        self.assertNotIn('OEBPS/chapter04.xhtml',self.archive.namelist())
        self.assertEqual(self.report['required_main_scenes'],43)
        self.assertFalse(self.report['canonical_or_approved'])
        self.assertFalse(self.report['all_alternative_paths_included'])

    def test_linear_branch_does_not_mix_companion_or_rigel_outcomes(self):
        decisions=[d['choice_id']for d in self.report['decisions']]
        self.assertIn('lore_menace/accept_skeleton',decisions)
        self.assertIn('lastditch_pyramid/decline_polaris',decisions)
        self.assertIn('gaia_evil_seal/aid_rigel',decisions)
        self.assertNotIn('gaia_evil_seal/join_rigel',decisions)
        self.assertNotIn('gaia_evil_seal/leave_rigel',decisions)
        self.assertEqual(len(decisions),len(set(decisions)))

    def test_chosen_original_content_and_replacement_are_auditable(self):
        self.assertTrue(self.report['source_content_preserved_for_selected_route'])
        self.assertIn('prologue/lord_intro_dialogue',self.report['chosen_source_blocks'])
        self.assertIn('prologue/lord_intro_dialogue',self.report['script_override_ids'])
        self.assertIn('gaia_evil_seal/aid_result_647',self.report['chosen_source_blocks'])
        text=self.archive.read('OEBPS/chapter01.xhtml').decode()
        self.assertIn('나는 동욱이오.',text)
        self.assertIn('새로운 여정',text)
        self.assertNotIn('"relationships"',text)

    def test_output_hash_matches_export_and_embedded_offline_download(self):
        manifest=read(OUTPUT/'manifest.json')
        self.assertEqual(manifest['artifacts'][self.plan['filename']],hashlib.sha256(self.book).hexdigest())
        source=(ROOT/'writing/previews/novel-reader.html').read_text()
        expected='data:application/epub+zip;base64,'+base64.b64encode(self.book).decode()
        self.assertIn(expected,source)
        self.assertIn('download="'+self.plan['filename']+'"',source)

    def test_cover_hash_changes_and_unmarked_art_fail(self):
        for mode in ['hash','mark']:
            doc=copy.deepcopy(read(COVER_PLAN))
            if mode=='hash':doc['images']['main']['sha256']='0'*64
            else:doc['images']['main']['metadata']['addition']=False
            with self.assertRaises(ValueError):load_covers(doc)


if __name__=='__main__':unittest.main()

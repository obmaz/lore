import base64
import copy
import hashlib
import io
import json
import re
import unittest
import zipfile
from unittest.mock import patch
from xml.etree import ElementTree as ET

from materials import ROOT,read
from ebook import OUTPUT,payload_from_page,validate_epub
from epub_interactive import PLAN,READER,assemble


class InteractiveEpubTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.plan=read(PLAN);cls.report=read(OUTPUT/'interactive-report.json')
        cls.book=(OUTPUT/cls.plan['filename']).read_bytes()
        cls.zip=zipfile.ZipFile(io.BytesIO(cls.book))
        cls.doc=ET.fromstring(cls.zip.read('OEBPS/interactive.xhtml'))
        cls.payload=json.loads(cls.doc.find('.//{http://www.w3.org/1999/xhtml}script[@id="chapter-data"]').text)
        cls.page=(ROOT/'writing/previews/chapter01-web.html').read_text()

    @classmethod
    def tearDownClass(cls):cls.zip.close()

    def test_package_version_manifest_scripted_and_non_linear_entry(self):
        self.assertTrue(validate_epub(self.book)['valid_package'])
        opf=ET.fromstring(self.zip.read('OEBPS/package.opf'));ns={'o':'http://www.idpf.org/2007/opf'}
        self.assertEqual(opf.attrib['version'],'3.0')
        item=opf.find('o:manifest/o:item[@id="interactive"]',ns)
        self.assertEqual(item.attrib['properties'],'scripted')
        self.assertEqual(opf.find('o:spine/o:itemref[@idref="interactive"]',ns).attrib['linear'],'no')
        self.assertIn(b'interactive.xhtml',self.zip.read('OEBPS/reading-note.xhtml'))

    def test_shared_reader_and_same_story_state_data_no_original_edits(self):
        self.assertEqual(self.zip.read('OEBPS/reader.js'),READER.read_bytes())
        original=payload_from_page(self.page)
        for key in original:
            if key not in ('covers','fingerprint'):self.assertEqual(self.payload[key],original[key],key)
        self.assertNotEqual(self.payload['fingerprint'],original['fingerprint'])
        self.assertEqual(self.report['reader_fingerprint'],original['fingerprint'])
        self.assertEqual(self.payload['runtime']['target'],'epub')
        for image in self.payload['covers']['images'].values():self.assertIn('OEBPS/'+image['src'],self.zip.namelist())

    def test_fallback_is_the_exact_validated_linear_manuscript(self):
        with zipfile.ZipFile(OUTPUT/'lore-B-chapters01-03.epub')as linear:
            for key in self.plan['chapter_ids']:self.assertEqual(self.zip.read('OEBPS/'+key+'.xhtml'),linear.read('OEBPS/'+key+'.xhtml'))
        self.assertIn(b'chapter01.xhtml',self.zip.read('OEBPS/interactive.xhtml'))
        self.assertEqual(self.doc.find('.//{http://www.w3.org/1999/xhtml}div[@id="epub-app"]').attrib['hidden'],'hidden')

    def test_scope_no_author_master_or_unwritten_chapter_and_honest_compatibility(self):
        self.assertEqual(len(self.payload['chapters']),3)
        self.assertEqual(len(self.payload['main_story']),43)
        self.assertNotIn('relationships',self.payload)
        self.assertNotIn('OEBPS/chapter04.xhtml',self.zip.namelist())
        self.assertFalse(self.report['ridi_device_tested'])
        self.assertFalse(self.report['canonical_or_approved'])
        self.assertFalse(self.report['all_paths_rendered_or_proven'])
        self.assertIn('리디 앱에서의 실제 작동은 아직 확인하지 못했습니다',self.zip.read('OEBPS/reading-note.xhtml').decode())

    def test_download_hash_and_embedded_offline_bytes(self):
        manifest=read(OUTPUT/'manifest.json')
        self.assertEqual(manifest['artifacts'][self.plan['filename']],hashlib.sha256(self.book).hexdigest())
        self.assertEqual(manifest['public_downloads'][self.plan['filename']],self.plan['public_path'])
        reader=(ROOT/'writing/previews/novel-reader.html').read_text()
        link=re.search(r'<a id="download-b-choice-epub"[^>]+>',reader)[0]
        self.assertIn('download="'+self.plan['filename']+'"',link)
        self.assertIn('data:application/epub+zip;base64,'+base64.b64encode(self.book).decode(),link)

    def test_unreviewed_compatibility_claim_is_rejected(self):
        plan=copy.deepcopy(self.plan);plan['ridi_support']='supported'
        with patch('epub_interactive.read',return_value=plan):
            with self.assertRaisesRegex(ValueError,'unreviewed'):
                assemble(self.page,b'',{})


if __name__=='__main__':unittest.main()

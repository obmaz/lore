import itertools
import json
import unittest
from unittest.mock import patch
from export_dos_creation_class import OUT,main


class CreationClassNativeTest(unittest.TestCase):
    def test_fingerprints(self):
        with patch('sys.argv',['export_dos_creation_class','--check']):main()

    def test_full_native_scope(self):
        d=json.loads(OUT.read_text())
        self.assertEqual({(r['key'],r['mask']) for r in d['cases']},set(itertools.product(range(256),range(128))))
        self.assertEqual(len(d['source']['labels']),10)
        self.assertEqual(len(d['source']['characters']),10)

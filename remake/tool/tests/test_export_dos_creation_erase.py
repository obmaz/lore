"""LORECRET.PAS Last: native file helpers/IOResult and optional Halt branch."""
import json
import unittest
from export_dos_creation_erase import build, OUT

class CreationEraseTests(unittest.TestCase):
    def test_original_file_helpers_and_error_branch_reproduce_all_cases(self):
        data=build()
        self.assertEqual(data,json.loads(OUT.read_text()))
        self.assertEqual(len(data['cases']),40)
        for row in data['cases']:
            self.assertEqual(any(op[0]=='halt' for op in row['trace']),row['exists'] and row['error']!=0)
            self.assertEqual(any(op[0]=='erase' for op in row['trace']),row['exists'])

if __name__=='__main__':unittest.main()

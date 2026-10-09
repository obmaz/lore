import json
import unittest
import export_dos_common_screen as native

class CommonScreenTests(unittest.TestCase):
    def test_unchanged_native_replay_matches_committed_evidence(self):
        data=native.build()
        self.assertEqual(data,json.loads(native.OUT.read_text()))
        self.assertEqual(len(data['wait']),60)
        self.assertEqual(len(data['print']),24)
        for row in data['wait']:
            reads=[op[1] for op in row['trace'] if op[0]=='read']
            self.assertEqual(reads,row['pending']+row['fresh'])
            self.assertEqual(row['c'],row['fresh'][-1])
            self.assertEqual(row['afterPage'],row['page'])
        for row in data['print']:
            if row['kind']=='aux':
                self.assertEqual(row['afterHany'],row['hany']+(16 if row['newline'] else 0))
        self.assertEqual(len([op for op in data['borders'] if op[0]=='line']),156)

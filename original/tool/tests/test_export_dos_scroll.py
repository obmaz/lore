"""LORESUB.PAS Scroll native fixture regeneration and source call boundaries."""
import json
import unittest
from export_dos_scroll import build, OUT

class ScrollTests(unittest.TestCase):
    def test_original_scroll_replays_all_cases(self):
        data=build()
        self.assertEqual(data,json.loads(OUT.read_text()))
        self.assertEqual(len(data['cases']),384)
        for row in data['cases']:
            trace=row['trace']
            self.assertEqual([op[1] for op in trace if op[0]=='read'],row['queue'])
            self.assertEqual(row['afterPage'],1-row['page'])
            self.assertEqual(trace[-3:],[['visible',1-row['page']],['silence'],['fill',1,8]])
            self.assertEqual([op for op in trace if op[0]=='tone'],[['tone',20]] if row['sound'] else [])
            dark=row['position']==2 and row['torch']==0
            draws=[op for op in trace if op[0]=='put']
            self.assertEqual(len(draws),0 if dark else 81+(2 if row['character'] else 0))

if __name__=='__main__':unittest.main()

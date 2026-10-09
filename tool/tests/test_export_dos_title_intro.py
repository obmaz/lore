"""LOREHELP.PAS closed native graphics/scroll/keyboard branches."""
import json
import unittest
from export_dos_title_intro import build, OUT

class TitleIntroTests(unittest.TestCase):
    def test_original_traces_and_all_byte_scroll_selectors(self):
        data=build()
        self.assertEqual(data,json.loads(OUT.read_text()))
        self.assertEqual(len(data['cases']),275)
        scroll=[r for r in data['cases'] if r['kind']=='scroll']
        self.assertEqual([r['mode'] for r in scroll],list(range(256)))
        self.assertEqual(len({r['planeSha256'] for r in scroll[2:]}),1)
        story=[r for r in data['cases'] if r['kind']=='story' and r['falsePolls']==9999][0]
        self.assertEqual(sum(a[1] for a in story['trace'] if a[0]=='delay'),52420)

if __name__=='__main__':unittest.main()

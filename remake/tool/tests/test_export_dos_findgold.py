import json
import unittest
import export_dos_findgold as e

class FindGoldTest(unittest.TestCase):
    def test_original_bounded_decimal_and_page_order(self):
        data=json.loads(e.OUT.read_text())
        self.assertEqual(len(data['cases']),220)
        for row in data['cases']:
            self.assertEqual(row['events'][2],['print',7,'당신은 금화 '+str(row['money'])[:9]+'개를 발견했다.'])
            self.assertEqual(row['events'][2],row['events'][4])
            self.assertEqual(row['events'][1],['page',1-row['page']])
            self.assertEqual(row['events'][3],['page',row['page']])
            self.assertEqual(row['afterGold'],((row['gold']+row['money']+2**31)%2**32)-2**31)

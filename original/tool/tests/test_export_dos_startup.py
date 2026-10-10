import json
import unittest
import export_dos_startup as native

class StartupTests(unittest.TestCase):
    def test_unchanged_executable_replays_committed_startup_and_help(self):
        data=native.build()
        self.assertEqual(data,json.loads(native.OUT.read_text()))
        self.assertEqual(len(data['main']),96)
        self.assertEqual(len(data['title']),120)
        for row in data['title']:
            if row['arg'] in ['/?','-?','?']:
                self.assertEqual(row['trace'][-1],['halt',0])
                delays=[op[1] for op in row['trace'] if op[0]=='delay']
                self.assertEqual(sum(delays),min(row['delayLimit'],129)*50)
                self.assertEqual(len([op for op in row['trace'] if op[0]=='exec']),int(row['endExists']))
            elif row['arg'] in ['/c','/C']:
                self.assertEqual(row['stop'],0x7908)
                self.assertEqual(row['c'],49)
            else:self.assertEqual(row['stop'],0x73dc)

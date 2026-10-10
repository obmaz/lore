import json
import unittest

from source_map26_final import ROOT, OUTPUT, extract, fixture, final_path


class FinalSourceTest(unittest.TestCase):
    def test_source_fixture_is_current(self):
        data = fixture()
        self.assertEqual(json.loads(OUTPUT.read_text(encoding='utf-8')), data)
        self.assertEqual(data['monsters'], list(range(69, 76)))
        self.assertEqual(data['faces'], [5, 6, 5])
        self.assertEqual(data['northSteps'], 3)
        self.assertEqual(data['randomCalls'], 0)

    def test_all_result_bytes_keep_defeat_priority(self):
        for result in range(256):
            for dead in (False, True):
                expected = 'exit' if result == 255 else 'retry' if result and not dead else 'farewell'
                self.assertEqual(final_path(result, dead), expected)

    def test_changed_guards_fail(self):
        source = ROOT / 'repo_source/LORE_1993_src'
        spec = (source / 'LORESPEC.PAS').read_bytes().decode('johab')
        entry = (source / 'LOREENT.PAS').read_bytes().decode('johab')
        for changed in (spec.replace('(not enemy[7].dead)', '(not enemy[6].dead)'),
                        spec.replace('enemynumber := 7;', 'enemynumber := random(7);')):
            with self.assertRaises(ValueError):
                extract(changed, entry)


if __name__ == '__main__':
    unittest.main()

import unittest
import export_source_sub_labels as labels


class SourceSubLabelsTest(unittest.TestCase):
    def test_original_literal_scope(self):
        data = labels.build()['labels']
        self.assertEqual(len(data['ReturnClass']['values']), 10)
        self.assertEqual(len(data['ReturnWeapon']['values']), 10)
        self.assertEqual(len(data['ReturnDefense']['values']), 6)
        self.assertEqual(len(data['ReturnMagic']['values']), 45)
        self.assertIsNone(data['ReturnMagic']['default'])
        self.assertEqual(data['ReturnWeapon']['membership'], [0, 2, 3, 4, 6, 7, 8, 9])
        self.assertEqual(data['ReturnMagic']['then'], {'Josa': '', 'Mokjuk': '를'})
        self.assertEqual(data['ReturnMagic']['else'], {'Josa': '으', 'Mokjuk': '을'})

    def test_fixture_is_current(self):
        import json
        self.assertEqual(json.loads(labels.OUT.read_text()), labels.build())

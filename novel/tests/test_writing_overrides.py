import copy
import unittest

from characters import load_characters
from disclosure import project_character
from export_reference import title_of, writing_claims
from reference import load_references
from text_refs import indexes, resolve, writing_value


class WritingOverrideTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.profiles = load_characters()
        cls.references = load_references()

    def test_lord_replacement_reaches_title_reader_and_original_is_preserved(self):
        profile = self.profiles['characters']['lord_ahn']
        self.assertEqual(title_of(profile), '동욱')
        self.assertEqual(resolve({'catalog':'characters','id':'lord_ahn'},
            indexes(self.profiles,self.references),self.profiles), '동욱')
        self.assertEqual(profile['canonical_name']['value'], 'Lord Ahn')
        self.assertEqual(writing_claims(profile)[0]['value'], '동욱')

    def test_unset_values_fall_back_and_new_fields_and_zero_are_valid(self):
        profile = copy.deepcopy(self.profiles['characters']['lord_ahn'])
        self.assertEqual(writing_value(profile,'species'),profile['biography']['species']['value'])
        for field,value in [('age',0),('origin','새 출신 설정')]:
            profile['writing_overrides'][field]=dict(copy.deepcopy(profile['writing_overrides']['name']),field=field,value=value)
            self.assertEqual(writing_value(profile,field),value)
            self.assertEqual(next(c['value'] for c in writing_claims(profile) if c['field']==field),value)
        self.assertIsNone(profile['biography']['age']['value'])

    def test_replacement_does_not_reveal_hidden_identity_or_biography(self):
        profiles = copy.deepcopy(self.profiles)
        profile = profiles['characters']['false_necromancer']
        profile['writing_overrides']=copy.deepcopy(profiles['characters']['lord_ahn']['writing_overrides'])
        profile['writing_overrides']['name']['value']='숨겨진 별칭'
        sealed=project_character(profiles,'false_necromancer',['illusion_encounter'])
        self.assertNotIn('writing_overrides',sealed)
        data=indexes(profiles,self.references)
        self.assertNotEqual(resolve({'catalog':'characters','id':'false_necromancer'},data,profiles,['illusion_encounter']),'숨겨진 별칭')
        revealed=profile['disclosure']['after_events']
        self.assertEqual(resolve({'catalog':'characters','id':'false_necromancer'},data,profiles,revealed),'숨겨진 별칭')

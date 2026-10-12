import hashlib
import unittest

from materials import ROOT,load_materials,quest_document,source_document
from project_audit import audit,export


class ProjectStructureTests(unittest.TestCase):
    def test_roles_and_source_policy(self):
        report=audit()
        self.assertEqual(report['unclassified'],[])
        self.assertFalse(report['source_policy']['external_game_required'])
        self.assertEqual(report['cleanup']['deleted_original_materials'],[])
        self.assertTrue(all(not row['automatic_deletion'] for row in report['files']))
        registry=next(row for row in report['files'] if row['file']=='characters/registry.json')
        self.assertIn({'kind':'output_hash_guard','file':'reference/generated_manifest.json'},registry['consumers'])

    def test_examples_are_not_current_manuscripts(self):
        from story_continuity import DEFAULT
        self.assertEqual(DEFAULT,ROOT/'authoring/examples/prologue.json')
        self.assertFalse((ROOT/'authoring/drafts/prologue.json').exists())
        self.assertTrue(DEFAULT.is_file())

    def test_embedded_full_sources_match_original_byte_hashes(self):
        catalog,manifest=load_materials()
        self.assertEqual(manifest['counts'],{'source_files':14,'literal_occurrences':2483})
        for unit in catalog['source_units']:
            doc=source_document(unit['file'])
            self.assertEqual(doc['original_source'],unit['original_source'])
            self.assertEqual(hashlib.sha256(doc['original_source'].encode(unit['encoding'])).hexdigest(),unit['sha256'])

    def test_another_lore_is_internal_and_ranges_are_checked(self):
        doc=quest_document('another_lore')
        self.assertFalse(doc['external_file_required'])
        events=[event for m in doc['quest']['milestones'] for event in m['original_display_events']]
        self.assertEqual(len(events),220)
        part=source_document('LORETALK.PAS',741,1053)
        self.assertEqual(len(part['original_source'].splitlines()),313)
        self.assertIn('Print',part['original_source'])
        for file,start,end in [('../LORETALK.PAS',1,2),('LORETALK.PAS',0,2),('LORETALK.PAS',741,740),('LORETALK.PAS',1,999999)]:
            with self.assertRaises(ValueError):source_document(file,start,end)
        with self.assertRaises(ValueError):quest_document('../another_lore')

    def test_role_map_is_fresh(self):
        self.assertTrue(export(check=True)['checked'])

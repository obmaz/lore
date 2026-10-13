import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

from materials import ROOT, load_materials


class IndependentNovelTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix="lore-novel-independent-")
        cls.standalone = Path(cls.temp.name) / "novel"
        shutil.copytree(ROOT, cls.standalone, ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def run_tool(self, name, *args):
        env = dict(os.environ)
        env.pop("PYTHONPATH", None)
        result = subprocess.run([sys.executable, f"tools/{name}.py", *args], cwd=self.standalone,
                                env=env, text=True, capture_output=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout

    def test_validate_without_game_repository_or_root_tools(self):
        self.assertEqual([p.name for p in Path(self.temp.name).iterdir()], ["novel"])
        self.assertIn('"nodes": 6', self.run_tool("validate_story_authoring"))
        self.assertEqual(json.loads(self.run_tool("characters"))["characters"], 53)
        self.assertEqual(json.loads(self.run_tool("reference")), {"equipment": 24, "abilities": 45, "bestiary": 75})

    def test_path_context_without_original_files(self):
        accepted = json.loads(self.run_tool("story_continuity", "--route", "enter_courtyard", "visit_prison", "accept_joe", "visit_lord"))
        direct = json.loads(self.run_tool("story_continuity", "--route", "enter_courtyard", "visit_lord"))
        self.assertIn("mad_joe", accepted["character_profiles"])
        self.assertNotIn("mad_joe", direct["character_profiles"])
        self.assertEqual(accepted["state"]["companions.optional_recruits"], ["mad_joe"])

    def test_spoiler_filtered_card_without_game_sources(self):
        card = json.loads(self.run_tool("characters","--view","writer","--character","false_necromancer","--events","illusion_encounter"))
        self.assertEqual(list(card),["fortress_mage"])
        self.assertEqual(card["fortress_mage"]["relationships"],[])
        self.assertNotIn("사칭자",json.dumps(card,ensure_ascii=False))

    def test_reference_documents_match_without_game_sources(self):
        report = json.loads(self.run_tool("export_reference","--check"))
        self.assertEqual(report['characters'],53)
        self.assertEqual(report['relationships'],35)

    def test_writing_boards_and_previews_without_game_sources(self):
        report = json.loads(self.run_tool('writing','validate'))
        self.assertEqual(report['board']['units'],18)
        self.assertEqual(report['pilot']['coverage'],'partial')
        self.assertEqual(report['source_connected']['literal_occurrences'],2483)
        self.assertEqual(report['source_connected']['missing_display_event_ids'],[])
        self.assertTrue(json.loads(self.run_tool('writing','export','--check'))['checked'])

    def test_new_quest_uses_shared_template_without_overwrite(self):
        # The shared checkout must return to its committed input set before
        # later freshness tests; only delete this test's temporary new draft.
        for name in ('gaia_quake.json','gaia_quake.continuity.json'):
            self.addCleanup((self.standalone/'writing/quests'/name).unlink,missing_ok=True)
        result = json.loads(self.run_tool('writing','new-quest','--quest-id','gaia_quake'))
        self.assertEqual(len(result['created']),2)
        self.assertIn('gaia_quake_draft_v1',(self.standalone/'writing/quests/gaia_quake.json').read_text())
        before = (self.standalone/'writing/quests/gaia_quake.json').read_bytes()
        result = subprocess.run([sys.executable,'tools/writing.py','new-quest','--quest-id','gaia_quake'],cwd=self.standalone,text=True,capture_output=True)
        self.assertNotEqual(result.returncode,0)
        self.assertIn('refusing overwrite',result.stderr)
        self.assertEqual(before,(self.standalone/'writing/quests/gaia_quake.json').read_bytes())

    def test_subsection_branches_execute_without_original_or_remake(self):
        report = json.loads(self.run_tool('branch_system', 'validate'))
        self.assertEqual((report['main_units'], report['complete_paths']), (88, 96))
        packet = json.loads(self.run_tool('branch_system', 'replay', '--summary', '--route',
                                          'prepare/self', 'company/leave', 'aid/together'))
        self.assertEqual(packet['decision_id'], 'spica_company')
        self.assertNotIn('skeleton', packet['state']['party.members'])

    def test_publication_flow_is_independent_and_matches_generated_files(self):
        report = json.loads(self.run_tool('publication_flow','export','--check'))
        self.assertEqual((report['chapters'],report['subsections'],report['runtime_paths_checked']),(15,88,96))
        self.assertFalse(report['publication_approved'])

    def test_studio_bundle_is_independent_and_fresh(self):
        report=json.loads(self.run_tool('studio','export','--check'))
        self.assertEqual((report['documents'],report['chapters']),(10,15))
        self.assertEqual(report['visibility'],'author_only')

    def test_all_original_text_is_reconstructable_from_snapshot(self):
        catalog, manifest = load_materials()
        self.assertEqual(manifest["counts"], {"source_files": 14, "literal_occurrences": 2483})
        for unit in catalog["source_units"]:
            self.assertEqual(hashlib.sha256(unit["original_source"].encode("johab")).hexdigest(), unit["sha256"])
        index = json.loads((ROOT / "materials/quests.json").read_text())
        self.assertEqual(len(index["quests"]), 19)
        for quest in index["quests"]:
            self.assertTrue((ROOT / "materials" / quest["file"]).is_file())


if __name__ == "__main__": unittest.main()

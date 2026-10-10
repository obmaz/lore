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
        self.assertEqual(json.loads(self.run_tool("characters"))["characters"], 24)

    def test_path_context_without_original_files(self):
        accepted = json.loads(self.run_tool("story_continuity", "--route", "enter_courtyard", "visit_prison", "accept_joe", "visit_lord"))
        direct = json.loads(self.run_tool("story_continuity", "--route", "enter_courtyard", "visit_lord"))
        self.assertIn("mad_joe", accepted["character_profiles"])
        self.assertNotIn("mad_joe", direct["character_profiles"])
        self.assertEqual(accepted["state"]["companions.optional_recruits"], ["mad_joe"])

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

"""Check the real Pages assembly script with isolated, prebuilt game fixtures."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import textwrap
import unittest

ROOT = Path(__file__).resolve().parents[2]


class PagesDeploymentTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="lore-pages-assembly-")
        self.addCleanup(self.temp.cleanup)
        self.checkout = Path(self.temp.name)
        workflow = (ROOT / ".github/workflows/deploy-pages.yml").read_text()
        match = re.search(r"      - name: Assemble independent site paths\n        run: \|\n(.*?)(?=\n      - name:)", workflow, re.S)
        self.assertIsNotNone(match)
        self.script = textwrap.dedent(match.group(1))
        self.novel = self.checkout / "novel"
        manifest = json.loads((ROOT / "novel/writing/previews/manifest.json").read_text())
        files = [*manifest["source_sha256"], "writing/previews/manifest.json", "writing/previews/chapter01-interactive.html"]
        for relative in files:
            target = self.novel / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / "novel" / relative, target)
        # Fake game outputs: assembly must copy them without invoking any build.
        for game in ("original", "remake"):
            docs = self.checkout / game / "docs"
            docs.mkdir(parents=True)
            (docs / "index.html").write_text('<base href="/lore/">' + game)
            (docs / "prebuilt.bin").write_bytes(game.encode())

    def assemble(self):
        return subprocess.run(["bash", "-e", "-o", "pipefail", "-c", self.script],
                              cwd=self.checkout, capture_output=True, text=True)

    def test_only_reader_is_published_and_game_outputs_are_preserved(self):
        result = self.assemble()
        self.assertEqual(result.returncode, 0, result.stderr)
        site = self.checkout / "site"
        self.assertEqual(sorted(p.name for p in (site / "novel").iterdir()), ["index.html"])
        self.assertEqual((site / "novel/index.html").read_bytes(),
                         (self.novel / "writing/previews/chapter01-interactive.html").read_bytes())
        self.assertTrue((site / ".nojekyll").is_file())
        for game in ("original", "remake"):
            self.assertEqual((site / game / "prebuilt.bin").read_bytes(), game.encode())
            self.assertEqual((site / game / "index.html").read_text(), '<base href="/lore/' + game + '/">' + game)
            self.assertEqual((self.checkout / game / "docs/index.html").read_text(), '<base href="/lore/">' + game)

    def test_stale_source_stops_before_publishing_reader(self):
        (self.novel / "writing/interactive/reader.js").write_text("changed input")
        result = self.assemble()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Novel reading export is stale", result.stderr)
        self.assertFalse((self.checkout / "site/novel/index.html").exists())

    def test_modified_reader_is_not_published(self):
        (self.novel / "writing/previews/chapter01-interactive.html").write_text("changed output")
        result = self.assemble()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("reader differs", result.stderr)
        self.assertFalse((self.checkout / "site/novel/index.html").exists())

    def test_manifest_cannot_read_outside_novel(self):
        manifest_path = self.novel / "writing/previews/manifest.json"
        manifest = json.loads(manifest_path.read_text())
        manifest["source_sha256"]["../outside.txt"] = hashlib.sha256(b"not public").hexdigest()
        manifest_path.write_text(json.dumps(manifest))
        result = self.assemble()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Novel reading export is stale", result.stderr)
        self.assertFalse((self.checkout / "site/novel/index.html").exists())


if __name__ == "__main__":
    unittest.main()

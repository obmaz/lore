"""Check Pages assembly consumes fresh builds and validates novel exports."""
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
        files = [*manifest["source_sha256"], "writing/previews/manifest.json", "writing/previews/novel-reader.html"]
        studio_manifest = json.loads((ROOT / 'novel/writing/studio/generated/manifest.json').read_text())
        files += [*studio_manifest['source_sha256'], 'writing/studio/generated/manifest.json',
                  'writing/studio/generated/index.html', 'writing/studio/publication.json']
        for relative in files:
            target = self.novel / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / "novel" / relative, target)
        # Assembly uses verified CI builds, never historical committed docs.
        for game in ("original", "remake"):
            build = self.checkout / game / "build/web"
            build.mkdir(parents=True)
            (build / "index.html").write_text('<base href="/lore/">' + game)
            (build / "fresh.bin").write_bytes(game.encode())
            docs = self.checkout / game / "docs"
            docs.mkdir(parents=True)
            (docs / "index.html").write_text('stale committed build')
            (docs / "stale.bin").write_bytes(b'old release')

    def assemble(self):
        return subprocess.run(["bash", "-e", "-o", "pipefail", "-c", self.script],
                              cwd=self.checkout, capture_output=True, text=True)

    def test_reader_and_public_studio_are_separate_and_game_outputs_are_preserved(self):
        result = self.assemble()
        self.assertEqual(result.returncode, 0, result.stderr)
        site = self.checkout / "site"
        self.assertEqual(sorted(p.name for p in (site / "novel").iterdir()), ["downloads", "index.html", "studio"])
        self.assertEqual((site / "novel/index.html").read_bytes(),
                         (self.novel / "writing/previews/novel-reader.html").read_bytes())
        self.assertEqual(sorted(p.name for p in (site / 'novel/studio').iterdir()),['index.html'])
        self.assertEqual((site / 'novel/studio/index.html').read_bytes(),
                         (self.novel / 'writing/studio/generated/index.html').read_bytes())
        self.assertEqual(sorted(p.name for p in (site/'novel/downloads').iterdir()),['lore-B-chapters01-03.epub'])
        self.assertEqual((site/'novel/downloads/lore-B-chapters01-03.epub').read_bytes(),
                         (self.novel/'writing/ebooks/generated/lore-B-chapters01-03.epub').read_bytes())
        self.assertNotIn('studio-data',(site / 'novel/index.html').read_text())
        self.assertTrue((site / ".nojekyll").is_file())
        for game in ("original", "remake"):
            self.assertEqual((site / game / "fresh.bin").read_bytes(), game.encode())
            self.assertFalse((site / game / "stale.bin").exists())
            self.assertEqual((site / game / "index.html").read_text(), '<base href="/lore/' + game + '/">' + game)
            self.assertEqual((self.checkout / game / "docs/index.html").read_text(), 'stale committed build')

    def test_missing_build_cannot_fall_back_to_committed_docs(self):
        shutil.rmtree(self.checkout / 'remake/build/web')
        result = self.assemble()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.checkout / 'site/remake/stale.bin').exists())

    def test_validation_and_manual_deployment_are_separate(self):
        validate = (ROOT / '.github/workflows/validate.yml').read_text()
        deploy = (ROOT / '.github/workflows/deploy-pages.yml').read_text()
        self.assertIn('  push:\n    branches: [main]', validate)
        for command in ['flutter analyze --no-pub', 'flutter test --no-pub',
                        'python3 tool/build_web_release.py']:
            self.assertIn(command, validate)
        self.assertIn('actions/upload-artifact@', validate)
        self.assertNotIn('  push:', deploy)
        self.assertIn('  workflow_dispatch:', deploy)
        self.assertIn("head_sha: context.sha", deploy)
        self.assertIn("run.conclusion === 'success'", deploy)
        self.assertEqual(deploy.count('run-id: ${{ steps.validation.outputs.run_id }}'), 2)
        self.assertIn('tool/build_web_release.py --check-only', deploy)

    def test_stale_source_stops_before_publishing_reader(self):
        (self.novel / "writing/interactive/reader.js").write_text("changed input")
        result = self.assemble()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Novel reading export is stale", result.stderr)
        self.assertFalse((self.checkout / "site/novel/index.html").exists())

    def test_modified_reader_is_not_published(self):
        (self.novel / "writing/previews/novel-reader.html").write_text("changed output")
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

    def test_modified_studio_is_not_published(self):
        (self.novel / 'writing/studio/generated/index.html').write_text('changed output')
        result=self.assemble()
        self.assertNotEqual(result.returncode,0)
        self.assertIn('studio differs',result.stderr)
        self.assertFalse((self.checkout / 'site/novel/studio/index.html').exists())

    def test_stale_studio_source_stops_publication(self):
        (self.novel / 'writing/previews/chapter01-web.html').write_text('changed preview')
        result=self.assemble()
        self.assertNotEqual(result.returncode,0)
        self.assertIn('studio export is stale',result.stderr)
        self.assertFalse((self.checkout / 'site/novel/studio/index.html').exists())

    def test_studio_requires_explicit_public_policy(self):
        policy=self.novel / 'writing/studio/publication.json'
        value=json.loads(policy.read_text());value['audience']='private'
        policy.write_text(json.dumps(value))
        result=self.assemble()
        self.assertNotEqual(result.returncode,0)
        self.assertIn('not explicitly configured',result.stderr)

    def test_studio_manifest_cannot_read_outside_novel(self):
        path=self.novel / 'writing/studio/generated/manifest.json'
        value=json.loads(path.read_text())
        value['source_sha256']['../outside.txt']=hashlib.sha256(b'not public').hexdigest()
        path.write_text(json.dumps(value))
        result=self.assemble()
        self.assertNotEqual(result.returncode,0)
        self.assertIn('studio export is stale',result.stderr)
        self.assertFalse((self.checkout / 'site/novel/studio/index.html').exists())

    def test_modified_epub_is_not_published(self):
        (self.novel/'writing/ebooks/generated/lore-B-chapters01-03.epub').write_bytes(b'changed ebook')
        result=self.assemble()
        self.assertNotEqual(result.returncode,0)
        self.assertIn('export is stale',result.stderr)
        self.assertFalse((self.checkout/'site/novel/downloads/lore-B-chapters01-03.epub').exists())

    def test_epub_cannot_publish_to_an_unreviewed_path(self):
        path=self.novel/'writing/ebooks/generated/manifest.json'
        value=json.loads(path.read_text());value['public_path']='/outside/unreviewed.epub'
        path.write_text(json.dumps(value))
        # Preserve the parent guard deliberately so this reaches the EPUB gate.
        preview=self.novel/'writing/previews/manifest.json';parent=json.loads(preview.read_text())
        parent['source_sha256']['writing/ebooks/generated/manifest.json']=hashlib.sha256(path.read_bytes()).hexdigest()
        preview.write_text(json.dumps(parent))
        studio_path=self.novel/'writing/studio/generated/manifest.json'
        studio=json.loads(studio_path.read_text())
        studio['source_sha256']['writing/previews/manifest.json']=hashlib.sha256(preview.read_bytes()).hexdigest()
        studio_path.write_text(json.dumps(studio))
        result=self.assemble()
        self.assertNotEqual(result.returncode,0)
        self.assertIn('EPUB publication path',result.stderr)
        self.assertFalse((self.checkout/'site/novel/downloads/lore-B-chapters01-03.epub').exists())


if __name__ == "__main__":
    unittest.main()

"""Reject stale or incomplete loader artifacts before Pages publication."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from build_web_release import check_wasm


class WebReleaseIntegrityTest(unittest.TestCase):
    def bundle(self, root, hashes):
        (root / 'flutter_bootstrap.js').write_text(
            '_flutter.buildConfig = ' + json.dumps({'wasmHashes': hashes}) + ';')

    def test_application_and_renderer_payloads_must_both_match(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'main.dart.wasm').write_bytes(b'application')
            (root / 'canvaskit').mkdir()
            (root / 'canvaskit/skwasm.wasm').write_bytes(b'renderer')
            digest = hashlib.sha256(b'application').hexdigest()
            self.bundle(root, {'main.dart.wasm': digest,
                              'skwasm.wasm': hashlib.sha256(b'renderer').hexdigest()})
            self.assertEqual(check_wasm(root), digest)
            (root / 'canvaskit/skwasm.wasm').write_bytes(b'stale renderer')
            with self.assertRaisesRegex(ValueError, 'skwasm.wasm'):
                check_wasm(root)

    def test_old_bootstrap_cannot_publish_new_application(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'main.dart.wasm').write_bytes(b'new release')
            self.bundle(root, {'main.dart.wasm': hashlib.sha256(b'old release').hexdigest()})
            with self.assertRaisesRegex(ValueError, 'SHA-256 mismatch'):
                check_wasm(root)

    def test_missing_application_hash_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.bundle(root, {})
            with self.assertRaisesRegex(ValueError, 'Missing main.dart.wasm'):
                check_wasm(root)


if __name__ == '__main__':
    unittest.main()

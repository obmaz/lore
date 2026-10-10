#!/usr/bin/env python3
"""Build /lore/ and copy to Pages only after bootstrap/WASM integrity agrees."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def check_wasm(build):
    bootstrap = (build / 'flutter_bootstrap.js').read_text()
    match = re.search(r'_flutter\.buildConfig\s*=\s*(\{.*?\});', bootstrap)
    if match is None:
        raise ValueError('Missing Flutter build configuration')
    hashes = json.loads(match.group(1))['wasmHashes']
    if 'main.dart.wasm' not in hashes:
        raise ValueError('Missing main.dart.wasm integrity hash')
    for name, expected in hashes.items():
        relative = Path(name)
        if relative.is_absolute() or '..' in relative.parts:
            raise ValueError(f'Invalid WASM path: {name}')
        path = build / relative
        if not path.is_file() and name != 'main.dart.wasm':
            path = build / 'canvaskit' / relative
        actual = hashlib.sha256(path.read_bytes()).hexdigest()
        if actual != expected:
            raise ValueError(f'Bootstrap/WASM SHA-256 mismatch: {name}')
    return hashes['main.dart.wasm']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--flutter', default='flutter')
    parser.add_argument('--check-only', action='store_true')
    args = parser.parse_args()
    build = ROOT / 'build/web'
    if args.check_only:
        print('Release WASM integrity verified:', check_wasm(build))
        return
    command = [args.flutter, 'build', 'web', '--release', '--wasm',
               '--base-href', '/lore/', '--no-web-resources-cdn']
    # Flutter can generate bootstrap from the previous output before copying
    # the new compiler artifact. One cached build regenerates its hashes.
    for attempt in range(2):
        subprocess.run(command, cwd=ROOT, check=True)
        try:
            digest = check_wasm(build)
            break
        except ValueError:
            if attempt == 1:
                raise
    for source in build.iterdir():
        destination = ROOT / 'docs' / source.name
        if source.is_dir():
            shutil.copytree(source, destination, dirs_exist_ok=True)
        else:
            shutil.copy2(source, destination)
    print('Verified Pages release copied:', digest)


if __name__ == '__main__':
    main()

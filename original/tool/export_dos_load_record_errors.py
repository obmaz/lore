"""Native complete Load party/player missing and short-record failures, four slots.

The shared DOS byte/file engine executes original Reset/Read/Close/IOResult and
captures nested ErrorMessage arguments. It stops before the separately replayed
text/Halt body. This is not a claim about modern JSON parse memory matching
partial DOS record writes after a fatal read.
"""
import argparse
import hashlib
import json
from export_dos_load_font_errors import ROOT, START, END, build as run_profiles

OUT = ROOT / 'test/fixtures/dos_load_record_errors.json'


def build():
    cases = []
    base = None
    for slot in range(1, 5):
        base = run_profiles([(1, False, f'{kind}{slot}.dat', mode)
            for kind in ['party', 'player'] for mode in ['missing', 'truncated']], slot=slot)
        cases.extend(dict(row, slot=slot) for row in base['cases'])
    return dict(scope=__doc__, engineScope=base['scope'], exeSha256=base['exeSha256'],
        fragment=base['fragment'], resources=base['resources'], cases=cases)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if args.check:
        data = json.loads(OUT.read_text())
        root = ROOT / 'repo_source/LORE_1993_runtime'
        exe = (root / 'LORE.EXE').read_bytes()
        assert data['scope'] == __doc__
        assert data['exeSha256'] == hashlib.sha256(exe).hexdigest()
        assert data['fragment'] == dict(start=START, end=END, sha256=hashlib.sha256(exe[START:END]).hexdigest())
        assert data['resources'] == {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(root.iterdir())
            if p.suffix.upper() in ['.FNT', '.MAP']}
        assert len(data['cases']) == 16
    else: OUT.write_text(json.dumps(build(), separators=(',', ':'))+'\n')


if __name__ == '__main__': main()

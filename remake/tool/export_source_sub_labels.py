#!/usr/bin/env python3
"""Independent presentation literals / set operands from LORESUB.PAS.

This is source evidence, not executable runtime rules or native glyph evidence.
ReturnMagic's missing default has intentionally undefined original behavior;
only its defined labels and grammatical-set branch are exported.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path
from audit_lorespec import decode

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'repo_source/LORE_1993_src/LORESUB.PAS'
OUT = ROOT / 'test/fixtures/source_sub_labels.json'


def build():
    raw = SOURCE.read_bytes()
    source = '\n'.join(decode(line) for line in raw.splitlines())
    result = {'source_sha256': hashlib.sha256(raw).hexdigest(), 'labels': {}}
    for name in ['ReturnClass', 'ReturnWeapon', 'ReturnDefense', 'ReturnMagic']:
        match = re.search(r'^Function ' + name + r'\b[^\n]*\n\s*begin\b.*?'
                          r'(?=\nFunction |\nProcedure )', source, re.S | re.M)
        if match is None:
            raise ValueError(name)
        body = match[0]
        pairs = re.findall(r"(\d+)\s*:\s*" + name + r"\s*:=\s*'([^']*)'", body)
        expected_count = {'ReturnClass': 10, 'ReturnWeapon': 10,
                          'ReturnDefense': 6, 'ReturnMagic': 45}[name]
        if len(pairs) != expected_count:
            raise ValueError(f'{name}: expected {expected_count} labels')
        default = re.search(r"else " + name + r" := '([^']*)'", body)
        result['labels'][name] = dict(values=dict(pairs),
                                     default=default[1] if default else None)
        membership = re.search(r'if \w+ in \[([^]]+)\]', body)
        if membership:
            values = []
            for part in membership[1].split(','):
                bounds = [int(value) for value in part.split('..')]
                values.extend(range(bounds[0], bounds[-1] + 1))
            assignments = re.findall(r"(Josa|Mokjuk) := '([^']*)'", body)
            result['labels'][name]['membership'] = values
            result['labels'][name]['then'] = dict(assignments[:2])
            result['labels'][name]['else'] = dict(assignments[2:])
    result['sex'] = {}
    for name, kind, variable, field in [
            ('ReturnSex', 'Function', 'ReturnSex', 'number'),
            ('ReturnSexData', 'Procedure', 'SexData', 'person')]:
        body = re.search(r'^' + kind + ' ' + name + r'\b[^\n]*\n\s*begin\b.*?'
                         r'(?=\nFunction |\nProcedure )', source, re.S | re.M)[0]
        match = re.search(r'if player\[' + field + r'\]\.sex = male then '
                          + variable + r" := '([^']*)'\s*else " + variable
                          + r" := '([^']*)'", body)
        if match is None:
            raise ValueError(name + ': expected exact sex predicate')
        result['sex'][name] = {'male': match[1], 'else': match[2]}
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    text = json.dumps(build(), ensure_ascii=False, indent=2) + '\n'
    if args.check:
        if not OUT.exists() or OUT.read_text() != text:
            raise SystemExit('Source label fixture is stale')
    else:
        OUT.write_text(text)


if __name__ == '__main__':
    main()

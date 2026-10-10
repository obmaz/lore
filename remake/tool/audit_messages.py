#!/usr/bin/env python3
"""원작 소스의 한글 문자열이 포트에 얼마나 옮겨졌는지 **전수 대조**한다.

원작 `*_1993_src/*.PAS`(Johab)에서 한글이 든 문자열 리터럴을 모두 뽑아,
포트(`lib/`, `assets/data/*.json`, `test/`)에 같은 문구가 있는지 검사한다.

사용법:
    python3 tool/audit_messages.py               # 요약
    python3 tool/audit_messages.py LOREMENU      # 해당 유닛의 누락 문구 출력
    python3 tool/audit_messages.py --all         # 전체 누락 문구 출력
"""
from __future__ import annotations

import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(ROOT, 'repo_source', 'LORE_1993_src')

# 게임 본편 유닛 (개발 도구/그래픽 유틸은 제외)
GAME_UNITS = [
    'LORESPEC.PAS',
    'LORETALK.PAS',
    'LORESUB.PAS',
    'LOREMENU.PAS',
    'LOREBATT.PAS',
    'LORECRET.PAS',
    'LORECHT.PAS',
    'LORECHT2.PAS',
    'LOREENT.PAS',
    'LOREEND.PAS',
    'LOREHELP.PAS',
]
DEV_UNITS = [
    'FOEDITOR.PAS',
    'LOOKFOE.PAS',
    'GFE.PAS',
    'MOVEFONT.PAS',
    'ADLIB.PAS',
    'SOUNDRV.PAS',
    'MOUSE.PAS',
    'ME.PAS',
    'LORE.PAS',
    'LOREMAIN.PAS',
    'VOICE.PAS',
    'UHANX.PAS',
]

HANGUL = re.compile(r'[\uac00-\ud7a3]')
LITERAL = re.compile(rb"'((?:[^'\n]|'')*)'")
# 포트의 Dart 문자열 리터럴
DART_LITERAL = re.compile(r"'((?:[^'\\\n]|\\.)*)'|\"((?:[^\"\\\n]|\\.)*)\"", re.S)


def norm(text: str) -> str:
    """공백을 모두 제거해 비교용으로 정규화한다(원작은 줄바꿈으로 문장이 나뉜다)."""
    return re.sub(r'\s+', '', text.replace("''", "'"))


def decode(raw: bytes) -> str:
    try:
        return raw.decode('johab')
    except Exception:  # noqa: BLE001
        return raw.decode('latin-1')


def original_literals(path: str) -> list[str]:
    with open(path, 'rb') as fh:
        blob = fh.read()
    out = []
    for m in LITERAL.finditer(blob):
        text = decode(m.group(1))
        if norm(text) and HANGUL.search(text):
            out.append(text)
    return out


def port_texts() -> list[str]:
    """포트의 모든 문구(스텝 JSON + Dart 리터럴)."""
    items: list[str] = []

    def walk(node):
        if isinstance(node, str):
            items.append(node)
        elif isinstance(node, dict):
            for v in node.values():
                walk(v)
        elif isinstance(node, list):
            for v in node:
                walk(v)

    data_dir = os.path.join(ROOT, 'assets', 'data')
    if os.path.isdir(data_dir):
        for name in sorted(os.listdir(data_dir)):
            if name.endswith('.json'):
                with open(os.path.join(data_dir, name), encoding='utf-8') as fh:
                    walk(json.load(fh))

    for folder in ('lib', 'test'):
        base = os.path.join(ROOT, folder)
        for dirpath, _dirs, files in os.walk(base):
            for name in files:
                if not name.endswith('.dart'):
                    continue
                with open(os.path.join(dirpath, name), encoding='utf-8') as fh:
                    src = fh.read()
                for m in DART_LITERAL.finditer(src):
                    items.append(m.group(1) or m.group(2) or '')
    return [norm(i) for i in items if norm(i)]


def main() -> int:
    units = GAME_UNITS + DEV_UNITS
    corpus = port_texts()
    joined = '\n'.join(corpus)
    only = [a for a in sys.argv[1:] if not a.startswith('-')]
    show_all = '--all' in sys.argv

    total = covered = 0
    report = []
    for unit in units:
        path = os.path.join(SRC_DIR, unit)
        if not os.path.exists(path):
            continue
        lits = original_literals(path)
        uniq = list(dict.fromkeys(norm(x) for x in lits))
        missing = [x for x in uniq if x not in corpus and x not in joined]
        total += len(uniq)
        covered += len(uniq) - len(missing)
        report.append((unit, len(uniq), len(missing), missing))

    print('원작 문구 이관 현황 (공백 무시 대조)')
    for unit, n, miss, _items in report:
        pct = 100.0 * (n - miss) / n if n else 100.0
        mark = '✅' if miss == 0 else '⏳'
        print(f'  {mark} {unit:<16} {n - miss:>4}/{n:<4} ({pct:5.1f}%)  누락 {miss}')
    pct = 100.0 * covered / total if total else 100.0
    print(f'\n합계 {covered}/{total} ({pct:.1f}%)')

    for unit, _n, _miss, items in report:
        want = show_all or any(unit.startswith(o) or o.startswith(unit[:6]) for o in only)
        if not want or not items:
            continue
        print(f'\n=== {unit} 누락 {len(items)}개 ===')
        for item in items:
            print(' -', item)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

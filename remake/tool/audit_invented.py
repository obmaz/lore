#!/usr/bin/env python3
"""포트에만 있고 **원작에 없는 문구**를 찾는다(역방향 감사).

`tool/audit_messages.py` 는 "원작 → 포트" 방향(원작 문구가 전부 이관됐는가)을
검사한다. 이 도구는 반대 방향으로, 포트의 메시지가 전부 원작의 문자열 리터럴을
이어붙인 것인지 확인한다.

원작은 한 문장을 여러 `Print` 호출로 쪼개므로 리터럴을 이어붙여 비교한다
(`덧붙임` 판정에서 쓰는 방식과 동일). 포트 메시지 하나를 원작 리터럴들로
**탐욕적 최장 일치**로 덮어 보고, 덮이지 않는 부분을 보고한다.

사용법:
    python3 tool/audit_invented.py            # 요약(활성 항목만)
    python3 tool/audit_invented.py --list     # 항목별 자세히
    python3 tool/audit_invented.py --all      # 꺼둔 보존 항목까지 포함
    python3 tool/audit_invented.py --min 4    # 4글자 이상 미일치만
"""
from __future__ import annotations

import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(ROOT, 'repo_source', 'LORE_1993_src')
HANGUL = re.compile(r'[가-힣]')


def decode(raw: bytes) -> str:
    for enc in ('cp1361', 'cp949'):
        try:
            return raw.decode(enc)
        except Exception:
            continue
    return raw.decode('cp949', 'replace')


def norm(text: str) -> str:
    """공백 제거(원작은 한 문장을 쪼개 놓았다)."""
    return re.sub(r'\s+', '', text)


def original_literals() -> tuple[list[str], str]:
    """원작 `.PAS` 들의 문자열 리터럴(등장 순서, 중복 제거 없음)."""
    lits: list[str] = []
    for name in sorted(os.listdir(SRC_DIR)):
        if not name.upper().endswith('.PAS'):
            continue
        text = decode(open(os.path.join(SRC_DIR, name), 'rb').read())
        for m in re.finditer(r"'([^']*)'", text):
            s = m.group(1).replace("''", "'")
            n = norm(s)
            if n:
                lits.append(n)
    return lits, ' '.join(lits)


def coverage(message: str, lits: list[str]) -> list[str]:
    """메시지에서 원작 리터럴로 덮이지 않는 조각들.

    원작은 한 문장을 `Print` 여러 번으로 쪼개므로 길이 제한 없이 모든 리터럴을
    일치 대상으로 쓴다(짧은 리터럴도 문장의 일부일 수 있다). 보고는 호출 쪽에서
    길이로 거른다.

    탐욕적 매칭은 `방패를`(긴 것) 처럼 중간에 걸리는 리터럴을 먼저 집어 삼켜
    오탐을 만든다. 여기서는 **덮이지 않는 문자 수를 최소화**하는 DP 로 최적
    분해를 찾는다.
    """
    by_len: dict[int, set[str]] = {}
    for s in lits:
        if s:
            by_len.setdefault(len(s), set()).add(s)
    lengths = sorted(by_len)

    text = norm(message)
    n = len(text)
    # cost[i] = i..끝을 덮지 못해 남는 최소 문자 수, nxt[i] = 그때 다음 위치
    # 어떤 길이의 리터럴이든 붙일 수 있으므로 **모든 길이**를 시도한다
    # (가장 긴 것만 쓰면 `방패` + `를 훔쳐…` 같은 최적 분해를 놓친다).
    INF = n + 1
    cost = [INF] * (n + 1)
    nxt = [0] * (n + 1)
    cost[n] = 0
    for i in range(n - 1, -1, -1):
        for ln in lengths:
            if i + ln <= n and text[i:i + ln] in by_len[ln]:
                c = cost[i + ln]
                if c < cost[i]:
                    cost[i] = c
                    nxt[i] = i + ln
        c = 1 + cost[i + 1]
        if c < cost[i]:
            cost[i] = c
            nxt[i] = i + 1
    gaps: list[str] = []
    i = 0
    while i < n:
        j = nxt[i]
        if j == i + 1 and not any(
                i + ln <= n and text[i:i + ln] in by_len[ln] for ln in lengths):
            k = j
            while k < n and nxt[k] == k + 1 and not any(
                    k + ln <= n and text[k:k + ln] in by_len[ln]
                    for ln in lengths):
                k += 1
            gaps.append(text[i:k])
            i = k
        else:
            i = j
    return gaps


def port_messages(include_disabled: bool = False) -> list[tuple[str, str, str]]:
    """(스크립트 id, 종류, 문구).

    `disabled` 항목은 원문 보존용 기록이므로 기본적으로 건너뛴다(실제로 게임에
    나오는 문구만 검사). `--all` 로 포함시킬 수 있다.
    """
    data = json.load(open(os.path.join(ROOT, 'test/fixtures/legacy_rules/scripts.json')))
    out: list[tuple[str, str, str]] = []

    def walk(node, sid: str):
        if isinstance(node, dict):
            for k, v in node.items():
                if k in ('say', 'title') and isinstance(v, str):
                    out.append((sid, k, v))
                elif k == 'text' and isinstance(v, str):
                    out.append((sid, 'choice', v))
                else:
                    walk(v, sid)
        elif isinstance(node, list):
            for x in node:
                walk(x, sid)

    for entry in data['scripts']:
        if entry.get('disabled') and not include_disabled:
            continue
        walk(entry.get('steps'), entry['id'])
    return out


def main() -> int:
    verbose = '--list' in sys.argv
    include_disabled = '--all' in sys.argv
    min_len = 2
    if '--min' in sys.argv:
        min_len = int(sys.argv[sys.argv.index('--min') + 1])
    lits, _ = original_literals()
    msgs = port_messages(include_disabled)
    offenders: list[tuple[str, str, str, list[str]]] = []
    for sid, kind, text in msgs:
        if not HANGUL.search(text):
            continue
        gaps = [g for g in coverage(text, lits) if HANGUL.search(g)]
        gaps = [g for g in gaps if len(g) >= min_len]
        if gaps:
            offenders.append((sid, kind, text, gaps))
    print(f'원작 리터럴 {len(lits)}개 / 포트 메시지 {len(msgs)}개' + ('' if include_disabled else ' (활성 항목만)'))
    print(f'원작에 없는 문구가 있는 메시지: {len(offenders)}개')
    total = sum(len(g) for _, _, _, g in offenders)
    print(f'미일치 조각 총 {total}개 (최소 {min_len}글자)')
    if verbose:
        for sid, kind, text, gaps in offenders:
            print(f'\n[{sid}] ({kind})')
            print(f'    문구: {text}')
            for g in gaps:
                print(f'    ? {g}')
    else:
        for sid, kind, text, gaps in offenders:
            print(f'{sid}\t{kind}\t{text[:80]}\t{"/".join(gaps)[:120]}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

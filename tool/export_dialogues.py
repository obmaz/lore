#!/usr/bin/env python3
"""`lib/game/lore_dialogue_manager.dart`의 단순 좌표 대화를 `assets/data/dialogues.json`으로 추출한다.

추출 대상은 "단일 좌표 → 단일 문자열 반환" 형태뿐이다.
(플래그/퀘스트 단계에 따라 분기하는 대화는 Dart 코드에 그대로 남겨 두고,
 로더는 JSON → Dart 순으로 조회한다.)

사용법:
    python3 tool/export_dialogues.py
"""
import json
import re
import sys

SRC = 'lib/game/lore_dialogue_manager.dart'
OUT = 'assets/data/dialogues.json'

# 메서드 → 맵 번호
METHOD_MAP = {
    '_getCastleLoreDialogue': 6,
    '_getLastditchDialogue': 7,
    '_getGaiaTerraDialogue': 9,
    '_getWaterFieldDialogue': 10,
    '_getDen2Dialogue': 12,
    '_getNoticeDenDialogue': 17,
    '_getLockupDenDialogue': 18,
}

METHOD_RE = re.compile(r'String\? (_get\w+Dialogue)\(')
ENTRY_RE = re.compile(
    r"if \(tx == (\d+) && ty == (\d+)\) \{\s*return ('(?:[^'\\]|\\.)*');\s*\}",
    re.S,
)


def unescape_dart(literal: str) -> str:
    """Dart 문자열 리터럴(작은따옴표, 이스케이프 포함)을 실제 문자열로 변환."""
    body = literal[1:-1]
    out = []
    i = 0
    while i < len(body):
        c = body[i]
        if c == '\\' and i + 1 < len(body):
            nxt = body[i + 1]
            mapping = {'n': '\n', 't': '\t', 'r': '\r', "'": "'", '"': '"', '\\': '\\', '$': '$'}
            out.append(mapping.get(nxt, nxt))
            i += 2
            continue
        out.append(c)
        i += 1
    return ''.join(out)


def main() -> int:
    src = open(SRC, encoding='utf-8').read()

    entries = []
    for m in METHOD_RE.finditer(src):
        method = m.group(1)
        map_id = METHOD_MAP.get(method)
        if map_id is None:
            continue
        # 해당 메서드 본문 범위
        start = m.end()
        nxt = METHOD_RE.search(src, start)
        body = src[start:nxt.start() if nxt else len(src)]

        for x, y, literal in ENTRY_RE.findall(body):
            text = unescape_dart(literal)
            # Dart 문자열 보간($heroName)은 런타임에 치환되도록 플레이스홀더로 바꾼다.
            text = text.replace('$heroName', '{hero}')
            entries.append({'map': map_id, 'x': int(x), 'y': int(y), 'text': text})

    entries.sort(key=lambda e: (e['map'], e['x'], e['y']))
    data = {
        'version': 1,
        'description': (
            '원작 LORETALK.PAS의 좌표 기반 NPC 대사. 게임은 이 파일을 먼저 조회하고, '
            '플래그/퀘스트 분기가 필요한 대화는 코드(lore_dialogue_manager.dart)로 처리한다.'
        ),
        'dialogues': entries,
    }
    with open(OUT, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write('\n')

    print(f'wrote {OUT}: {len(entries)} entries')
    for e in entries:
        print(f"  map {e['map']:2d} ({e['x']},{e['y']}) {e['text'][:60]}")
    return 0


if __name__ == '__main__':
    sys.exit(main())

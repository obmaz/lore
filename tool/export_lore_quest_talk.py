#!/usr/bin/env python3
"""원작 `LORETALK.PAS` 의 **상태 분기** 대화(party.etc 비트/퀘스트 단계)를
스크립트 JSON으로 옮기는 도구.

`--report`(기본)로 생성 결과를 확인하고, `--write` 면
`assets/data/scripts.json` 에 병합한다(대상 좌표의 기존 `talk-*` 대체).

지원 구문:
  - `if party.etc[N] and bitM = 0 / = 1`  → `require.flagNot` / `require.flag`
  - `if party.etc[N] < v` / `= v`         → `require.quest {name, lt/eq/gte}`
  - `case party.etc[N] of v : begin ... end;` → 팔마다 스크립트 1개
  - `inc(party.etc[N])`                   → `{"questStep": {"name": X, "inc": 1}}`
  - `experience + n`                      → `{"exp": n}`
  - `map[x,y] := v` / `for i := a to b do map[x,i] := v` → `setTile` / `setTileArea`
  - `Print/cPrint/talk` 텍스트는 원문 그대로(색/하이라이트 인자만 제거,
    `player[1].name` → `{hero}`)
"""
from __future__ import annotations

import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from export_lore_talk import QUEST_INC, decode  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'repo_source', 'LORE_1993_src', 'LORETALK.PAS')
# `party.etc[50] bit4`(무기고) 설정은 LORESPEC.PAS 쪽 이벤트에 있다.
SRC_SPEC = os.path.join(ROOT, 'repo_source', 'LORE_1993_src', 'LORESPEC.PAS')
JSON_PATH = os.path.join(ROOT, 'assets', 'data', 'scripts.json')

# 원작 `party.etc[N]` → 포트의 퀘스트 이름 (LoreDialogueManager.questSteps)
QUEST_BY_ETC = {10: 'lordahn', 13: 'lastditch', 14: 'gaia', 15: 'water'}

# 원작 `party.etc[N] and bitM` → 포트의 불리언 플래그 이름
FLAG_BY_ETC_BIT = {
    (50, 1): 'jrAntaresSecretFound',
    (50, 4): 'weaponRoomVisited',
    (50, 5): 'menaceInfoGiven',
    (30, 1): 'loreChallengeAccepted',
    (30, 2): 'loreChallengeBlessed',
    (43, 4): 'programmerMet',
}

ARM = re.compile(r'^(\d+)\s*:\s*(begin)?\s*(.*)$')
CASE_HEAD = re.compile(r'case\s+party\.etc\[(\d+)\]\s+of')
LINE_TILE = re.compile(r'map\[(\d+)\s*,\s*(\d+)\]\s*:=\s*(\d+)')
RANGE_TILE = re.compile(
    r'for\s+i\s*:=\s*(\d+)\s+to\s+(\d+)\s+do\s+map\[(\d+)\s*,\s*i\]\s*:=\s*(\d+)'
)
# `for i := 49 to 53 do map[i,88] := 44;` (열 방향)
RANGE_TILE_X = re.compile(
    r'for\s+i\s*:=\s*(\d+)\s+to\s+(\d+)\s+do\s+map\[i\s*,\s*(\d+)\]\s*:=\s*(\d+)'
)
CALLOUT = re.compile(r'^\s*(?:Print|cPrint|talk|Talk|message|Message)\s*\(', re.I)
# 문자열 리터럴 | 누적 변수 s | player[n].name (순서 보존)
PIECE = re.compile(
    r"'((?:[^']|'')*)'|(?<![\w.])(s)(?![\w.])|(player\[\d+\]\.name)"
)
SETVAR = re.compile(r"^\s*s\s*:=\s*(.*?);\s*$", re.I)


def load_lines(path: str = SRC) -> list[str]:
    with open(path, 'rb') as fh:
        return decode(fh.read()).splitlines()


def statement(line: str) -> str:
    """`if ... then talk('..')` / `else talk('..')` 에서 실행문만 남긴다."""
    m = re.search(r'\bthen\s+(.*)$', line, re.I)
    target = m.group(1) if m else line
    return re.sub(r'^\s*else\s+', '', target, flags=re.I)


def _join_pieces(body: str, vars_: dict[str, str]) -> str:
    parts = []
    for piece in PIECE.finditer(body):
        lit, var_s, hero = piece.group(1), piece.group(2), piece.group(3)
        if lit is not None:
            parts.append(lit.replace("''", "'"))
        elif var_s:
            parts.append(vars_.get('s', ''))
        elif hero:
            parts.append('{hero}')
    return ''.join(parts)


def extract_text(line: str, vars_: dict[str, str]) -> str | None:
    """한 줄에서 원작 대사를 뽑는다(없으면 None). 순서/연결을 그대로 유지한다."""
    target = statement(line)
    m = SETVAR.match(target)
    if m:
        vars_['s'] = _join_pieces(m.group(1), vars_)
        return None
    if not CALLOUT.match(target):
        return None
    body = target[target.find('(') + 1 :]
    text = _join_pieces(body, vars_)
    return text or None


def texts(lines: list[str], first: int, last: int) -> list[str]:
    """1-based `first..last` 줄에서 원작 대사를 순서대로 뽑는다."""
    out: list[str] = []
    vars_: dict[str, str] = {}
    for raw in lines[first - 1 : last]:
        text = extract_text(raw, vars_)
        if text:
            out.append(text)
    return out


def text(lines: list[str], n: int) -> str:
    got = texts(lines, n, n)
    if not got:
        raise SystemExit(f'{n}번째 줄에서 대사를 찾지 못했습니다: {lines[n - 1]}')
    return got[0]


def literal(lines: list[str], n: int) -> str:
    """`m[1] := '...'` 처럼 select 선택지 문구를 뽑는다."""
    m = re.search(r"'((?:[^']|'')*)'", lines[n - 1])
    if not m:
        raise SystemExit(f'{n}번째 줄에서 문구를 찾지 못했습니다: {lines[n - 1]}')
    return m.group(1).replace("''", "'")


def say(items: list[str]) -> list[dict]:
    return [{'say': t} for t in items]


def tiles(line: str) -> list[dict]:
    out: list[dict] = []
    for x, y, v in LINE_TILE.findall(line):
        out.append({'setTile': {'x': int(x), 'y': int(y), 'tile': int(v)}})
    for a, b, x, v in RANGE_TILE.findall(line):
        out.append(
            {
                'setTileArea': {
                    'xMin': int(x),
                    'xMax': int(x),
                    'yMin': int(a),
                    'yMax': int(b),
                    'tile': int(v),
                }
            }
        )
    for a, b, y, v in RANGE_TILE_X.findall(line):
        out.append(
            {
                'setTileArea': {
                    'xMin': int(a),
                    'xMax': int(b),
                    'yMin': int(y),
                    'yMax': int(y),
                    'tile': int(v),
                }
            }
        )
    return out


def with_map(steps: list[dict], map_id: int) -> list[dict]:
    for st in steps:
        for key in ('setTile', 'setTileArea'):
            if key in st:
                st[key]['map'] = map_id
    return steps


def quest(name: str, **cond) -> dict:
    out: dict = {'name': name}
    for key in ('eq', 'lt', 'gte'):
        if cond.get(key) is not None:
            out[key] = cond[key]
    return {'quest': out}


def scripts_for_arms(
    lines: list[str],
    map_id: int,
    x: int,
    y: int,
    etc_n: int,
    first: int,
    last: int,
) -> list[dict]:
    """`case party.etc[N] of` 팔을 팔마다 스크립트 1개로 만든다."""
    quest_name = QUEST_BY_ETC[etc_n]
    arms: list[tuple[int, list[dict]]] = []
    i = first - 1
    while i < last and not CASE_HEAD.search(lines[i]):
        i += 1
    i += 1
    depth = 0
    value: int | None = None
    steps: list[dict] = []

    def flush() -> None:
        nonlocal value, steps
        if value is not None and any('say' in s for s in steps):
            arms.append((value, steps))
        value, steps = None, []

    while i < last:
        raw = lines[i]
        stripped = raw.strip()
        if depth == 0 and re.fullmatch(r'end\s*;?', stripped, re.I):
            break  # case 문 종료
        m = ARM.match(stripped)
        if m and depth == 0:
            flush()
            value = int(m.group(1))
            if m.group(2):
                depth = 1
            else:  # `6 : talk(' ...');` 한 줄 팔
                t = extract_text(m.group(3), {})
                if t:
                    steps.append({'say': t})
                flush()
            i += 1
            continue
        if value is not None and depth > 0:
            depth += len(re.findall(r'\bbegin\b', raw, re.I))
            depth -= len(re.findall(r'\bend\b', raw, re.I))
            if QUEST_INC.search(raw):
                steps.append({'questStep': {'name': quest_name, 'inc': 1}})
            exp = re.search(r'experience\s*\+\s*(\d+)', raw)
            if exp:
                steps.append({'exp': int(exp.group(1))})
            if 'PressAnyKey' not in raw and 'Scroll' not in raw:
                t = extract_text(raw, {})
                if t:
                    steps.append({'say': t})
            if depth <= 0:
                flush()
            i += 1
            continue
        i += 1
    flush()
    return [
        {
            'id': f'talk-{map_id}-{x}-{y}-q{v}',
            'trigger': 'talk',
            'map': map_id,
            'x': x,
            'y': y,
            'once': False,
            'require': quest(quest_name, eq=v),
            'steps': st,
        }
        for v, st in arms
    ]


def build() -> tuple[list[dict], set[tuple[int, int, int]], set[str]]:
    lines = load_lines()
    spec = load_lines(SRC_SPEC)
    out: list[dict] = []
    replace_ids: set[str] = set()

    def add(entry: dict) -> None:
        entry.setdefault('trigger', 'talk')
        entry.setdefault('once', False)
        entry['steps'] = with_map(entry['steps'], entry['map'])
        out.append(entry)

    # ---------- 맵 6 : CASTLE LORE ----------
    # (51,72) 피라밋 안내 (etc[50] bit5)
    add({
        'id': 'talk-6-51-72', 'map': 6, 'x': 51, 'y': 72,
        'require': {'flagNot': FLAG_BY_ETC_BIT[(50, 5)]},
        'steps': say(texts(lines, 31, 37))
        + [{'flag': FLAG_BY_ETC_BIT[(50, 5)]}],
    })
    add({
        'id': 'talk-6-51-72-b', 'map': 6, 'x': 51, 'y': 72,
        'require': {'flag': FLAG_BY_ETC_BIT[(50, 5)]},
        'steps': say(texts(lines, 42, 43)),
    })
    # (63,76) Jr. Antares (etc[50] bit1) + 숨은 통로 개방
    add({
        'id': 'talk-6-63-76', 'map': 6, 'x': 63, 'y': 76,
        'require': {'flagNot': FLAG_BY_ETC_BIT[(50, 1)]},
        'steps': say(texts(lines, 106, 125))
        + with_map(tiles(lines[125]), 6)  # 126: for i := 79 to 81 do map[62,i] := 44
        + with_map(tiles(lines[126]), 6)  # 127: map[62,82]:=0; map[62,83]:=14
        + [{'flag': FLAG_BY_ETC_BIT[(50, 1)]}],
    })
    # (42,78)/(42,80) 무기고 안내 (etc[50] bit4)
    for y in (78, 80):
        add({
            'id': f'talk-6-42-{y}', 'map': 6, 'x': 42, 'y': y,
            'require': {'flagNot': FLAG_BY_ETC_BIT[(50, 4)]},
            'steps': say(texts(lines, 243, 245)),
        })
        add({
            'id': f'talk-6-42-{y}-b', 'map': 6, 'x': 42, 'y': y,
            'require': {'flag': FLAG_BY_ETC_BIT[(50, 4)]},
            'steps': say(texts(lines, 248, 249)),
        })
    # (50,51)/(52,51) 도전 (etc[30] bit1 / etc[10] 단계)
    challenge_tiles = with_map(
        tiles(lines[267]) + tiles(lines[268]) + tiles(lines[269]), 6
    )
    for x in (50, 52):
        add({
            'id': f'talk-6-{x}-51-a', 'map': 6, 'x': x, 'y': 51,
            'require': {'flag': FLAG_BY_ETC_BIT[(30, 1)]},
            'steps': say(texts(lines, 260, 260)),
        })
        add({
            'id': f'talk-6-{x}-51-b', 'map': 6, 'x': x, 'y': 51,
            'require': {
                **quest('lordahn', lt=3),
                'flagNot': FLAG_BY_ETC_BIT[(30, 1)],
            },
            'steps': say(texts(lines, 261, 261)),
        })
        add({
            'id': f'talk-6-{x}-51-c', 'map': 6, 'x': x, 'y': 51,
            'require': {
                **quest('lordahn', gte=3),
                'flagNot': FLAG_BY_ETC_BIT[(30, 1)],
            },
            'steps': [
                {
                    'choice': {
                        'prompt': text(lines, 263) + '\n' + text(lines, 264),
                        'options': [
                            {
                                'text': text(lines, 272),
                                'steps': challenge_tiles
                                + say(texts(lines, 274, 274))
                                + [{'flag': FLAG_BY_ETC_BIT[(30, 1)]}],
                            },
                            {
                                'text': text(lines, 280),
                                'steps': say(texts(lines, 282, 282)),
                            },
                        ],
                    }
                }
            ],
        })
    # (51,87) 성문 축복 (etc[30] bit2)
    add({
        'id': 'talk-6-51-87', 'map': 6, 'x': 51, 'y': 87,
        'require': {'flagNot': FLAG_BY_ETC_BIT[(30, 2)]},
        'steps': with_map(tiles(lines[286]), 6)
        + say(texts(lines, 288, 288))
        + [{'flag': FLAG_BY_ETC_BIT[(30, 2)]}],
    })
    add({
        'id': 'talk-6-51-87-b', 'map': 6, 'x': 51, 'y': 87,
        'require': {'flag': FLAG_BY_ETC_BIT[(30, 2)]},
        'steps': say(texts(lines, 292, 292)),
    })
    # (48..54, 31..37) 성문 안내 (etc[10] 단계)
    add({
        'id': 'talk-6-gate-a', 'map': 6, 'xMin': 48, 'xMax': 54,
        'yMin': 31, 'yMax': 37,
        'require': quest('lordahn', eq=0),
        'steps': say(texts(lines, 294, 294)),
    })
    add({
        'id': 'talk-6-gate-b', 'map': 6, 'xMin': 48, 'xMax': 54,
        'yMin': 31, 'yMax': 37,
        'require': quest('lordahn', gte=1),
        'steps': say(texts(lines, 295, 295)),
    })
    # (51,28) Lord Ahn 알현 (etc[10] 0~6)
    out.extend(scripts_for_arms(lines, 6, 51, 28, 10, 297, 396))
    # (41,79) 기본 무기 지급 (LORESPEC.PAS:243 `on(41,79)`, etc[50] bit4 설정)
    # 이전에 요약 이관했던 `castle-arm-41-79`(문구 병합/플래그 불일치)를 대체한다.
    replace_ids.add('castle-arm-41-79')
    add({
        'id': 'lore-weapon-room', 'map': 6, 'x': 41, 'y': 79, 'trigger': 'step',
        'require': {'flagNot': FLAG_BY_ETC_BIT[(50, 4)]},
        'steps': [
            {'flag': FLAG_BY_ETC_BIT[(50, 4)]},
            {'setTile': {'map': 6, 'x': 41, 'y': 79, 'tile': 44}},
            {'nudge': {'dx': -1, 'dy': 0}},
            {'nudge': {'dx': -1, 'dy': 0}},
            {'nudge': {'dx': -1, 'dy': 0}},
        ]
        + say(texts(spec, 252, 253))
        + [
            {
                'equip': {
                    'kind': 'weapon',
                    'index': 1,
                    'power': 5,
                    'onlyUnarmed': True,
                }
            },
        ],
    })

    # ---------- 맵 7 : LASTDITCH ----------
    for x, y in ((36, 19), (36, 21), (41, 18), (41, 20), (41, 22), (40, 41)):
        add({
            'id': f'talk-7-{x}-{y}-a', 'map': 7, 'x': x, 'y': y,
            'require': quest('lastditch', eq=0),
            'steps': say(texts(lines, 404, 404)),
        })
        add({
            'id': f'talk-7-{x}-{y}-b', 'map': 7, 'x': x, 'y': y,
            'require': quest('lastditch', gte=1),
            'steps': say(texts(lines, 405, 405)),
        })
    # (37,41) Polaris 영입 (etc[13] < 2)
    replace_ids.add('polaris-join')
    add({
        'id': 'polaris-join', 'map': 7, 'x': 37, 'y': 41,
        'require': quest('lastditch', lt=2),
        'steps': say(texts(lines, 407, 408))
        + [
            {
                'choice': {
                    'prompt': text(lines, 409),
                    'options': [
                        {
                            'text': literal(lines, 411),
                            'steps': [
                                {'join': 'polaris', 'flag': 'polarisJoined'}
                            ]
                            + with_map(tiles(lines[430]), 7),  # 431: map[37,41] := 44
                        },
                        {
                            'text': literal(lines, 412),
                            'steps': [{'say': '당신이 바란다면 ...'}],
                        },
                    ],
                }
            }
        ],
    })
    # (38,17) 성주 (etc[13] 0~3)
    out.extend(scripts_for_arms(lines, 7, 38, 17, 13, 440, 479))

    # ---------- 맵 9 : VALIANT PEOPLES ----------
    for x, y in ((34, 24), (37, 24), (41, 24), (35, 27), (38, 27), (41, 27)):
        add({
            'id': f'talk-9-{x}-{y}-a', 'map': 9, 'x': x, 'y': y,
            'require': quest('gaia', eq=0),
            'steps': say(texts(lines, 511, 511)),
        })
        add({
            'id': f'talk-9-{x}-{y}-b', 'map': 9, 'x': x, 'y': y,
            'require': quest('gaia', gte=1),
            'steps': say(texts(lines, 512, 512)),
        })
    # (42,25) 성주 (etc[14] 0~6)
    out.extend(scripts_for_arms(lines, 9, 42, 25, 14, 513, 579))

    # ---------- 맵 10 : WATER FIELD ----------
    # (40,56) Lore Hunter 영입 (etc[38] bit4)
    add({
        'id': 'lorehunter-join', 'map': 10, 'x': 40, 'y': 56,
        'require': {'flagNot': 'loreHunterJoined'},
        'steps': say(texts(lines, 609, 613))
        + [
            {
                'choice': {
                    'prompt': text(lines, 614),
                    'options': [
                        {
                            'text': literal(lines, 616),
                            'steps': [
                                {'join': 'lore_hunter',
                                 'flag': 'loreHunterJoined'}
                            ]
                            + with_map(tiles(lines[635]), 10),  # 636: map[40,56] := 44
                        },
                        {
                            'text': literal(lines, 617),
                            'steps': [{'say': '당신이 바란다면 ...'}],
                        },
                    ],
                }
            }
        ],
    })
    # (25,18) 성주 (etc[15] 0~5)
    out.extend(scripts_for_arms(lines, 10, 25, 18, 15, 640, 705))

    # ---------- 맵 24 : Ancient Evil 도시 ----------
    add({
        'id': 'talk-24-33-10', 'map': 24, 'x': 33, 'y': 10,
        'steps': say(texts(lines, 727, 735))
        + with_map(tiles(lines[736]), 24)  # 737: map[33,10] := 47
        + [{'flag': FLAG_BY_ETC_BIT[(43, 4)]}],
    })

    coords = {
        (e['map'], e['x'], e['y'])
        for e in out
        if e.get('x') is not None and e.get('y') is not None
    }
    return out, coords, replace_ids


def main() -> int:
    entries, coords, replace_ids = build()
    if '--write' not in sys.argv:
        print(json.dumps(entries, ensure_ascii=False, indent=1))
        return 0

    with open(JSON_PATH, encoding='utf-8') as fh:
        data = json.load(fh)
    scripts = data['scripts'] if isinstance(data, dict) else data
    new_ids = {e['id'] for e in entries}
    kept, dropped = [], []
    for s in scripts:
        key = (s.get('map'), s.get('x'), s.get('y'))
        sid = str(s.get('id', ''))
        managed = key in coords and sid.startswith('talk-')
        if sid in new_ids or sid in replace_ids or managed:
            dropped.append(sid)
            continue
        kept.append(s)
    # 기존 스크립트의 **순서를 그대로 유지**한다(같은 좌표에 여러 스크립트가
    # 있을 때 `find` 는 앞선 것을 고르므로 순서가 곧 우선순위다).
    merged = kept + entries
    if isinstance(data, dict):
        data['scripts'] = merged
    else:
        data = merged
    with open(JSON_PATH, 'w', encoding='utf-8') as fh:
        json.dump(data, fh, ensure_ascii=False, indent=2)
        fh.write('\n')
    print(f'추가/대체 {len(entries)}개, 제거 {len(dropped)}개, 총 {len(merged)}개')
    if dropped:
        print('제거:', ', '.join(sorted(dropped)))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

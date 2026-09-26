#!/usr/bin/env python3
"""원작 `LOREENT.PAS`(맵 진입/표지판)를 포털·표지판·진입 이벤트로 옮긴다.

원작 규칙(`LOREMAIN.PAS:195` 의 `case map[x,y] of`):
  - town   : 22 = 진입(entermode), 23 = 푯말(sign)
  - ground : 22 = 푯말, 51 이상(48~50 제외) = 진입
  - den/keep: 53 = 푯말, 54 = 진입 (52 는 specialevent)

진입/표지판 **좌표는 맵 데이터(.MAP)에서 직접 뽑고**, 대사·연출은
`LOREENT.PAS` 원문을 그대로 옮긴다.

사용법:
    python3 tool/export_lore_ent.py            # 미리보기
    python3 tool/export_lore_ent.py --write    # portals.json/scripts.json 갱신
"""
from __future__ import annotations

import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from export_lore_quest_talk import extract_text, load_lines  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'repo_source', 'LORE_1993_src', 'LOREENT.PAS')
MAPS_JSON = os.path.join(ROOT, 'assets', 'data', 'maps.json')
PORTALS_JSON = os.path.join(ROOT, 'assets', 'data', 'portals.json')
SCRIPTS_JSON = os.path.join(ROOT, 'assets', 'data', 'scripts.json')

ARM = re.compile(r'^ {6}(\d+)\s*:\s*(begin|if)\b')  # entermode 의 최상위 맵 팔
SIGN_ARM = re.compile(r'^ {8,9}(\d+)\s*:\s*(begin|if)\b')
AT = re.compile(r'at\((\d+)\s*,\s*(\d+)\)')
WANT = re.compile(r"wantenter\('([^']*)'\)")
TARGET = re.compile(r'map\s*:=\s*(\d+)\s*;\s*xaxis\s*:=\s*(\d+)\s*;\s*yaxis\s*:=\s*(\d+)')
FLAG_SET = re.compile(r'party\.etc\[(\d+)\]\s*:=\s*party\.etc\[(\d+)\]\s*or\s+bit(\d+)')
ENEMY = re.compile(r'joinenemy\(\s*[^,]+,\s*(\d+)\s*\)')

# 원작 `party.etc[N] bitM` → 포트 플래그 이름
ETC_FLAG = {
    (44, 1): 'frostDragonDefeated',
    (44, 2): 'dungeonOfEvilCleared',
    (42, 7): 'ancientEvilSpeechGiven',
    (42, 1): 'swampKeepBossDefeated',
    (43, 3): 'evilShelterBossDefeated',
    (45, 7): 'lavaLeverLeftPulled',
    (45, 8): 'lavaLeverRightPulled',
}

SIGN_HEADER = '푯말에 쓰여있기로 ...'


def texts(lines: list[str], first: int, last: int) -> list[str]:
    out: list[str] = []
    vars_: dict[str, str] = {}
    for raw in lines[first - 1 : last]:
        t = extract_text(raw, vars_)
        if t:
            out.append(t)
    return out


def map_meta() -> dict[int, dict]:
    with open(MAPS_JSON, encoding='utf-8') as fh:
        data = json.load(fh)
    return {m['mapId']: m for m in data['maps']}


def load_grid(file_name: str) -> tuple[int, int, list[list[int]]]:
    with open(os.path.join(ROOT, 'assets', 'maps', f'{file_name}.MAP'), 'rb') as fh:
        data = fh.read()
    xmax, ymax = data[0], data[1]
    return (
        xmax,
        ymax,
        [[data[2 + y * xmax + x] for x in range(xmax)] for y in range(ymax)],
    )


def tiles_for(map_id: int, meta: dict[int, dict]) -> dict[str, list[tuple[int, int]]]:
    """원작 타일 규칙으로 진입/푯말 좌표를 뽑는다."""
    info = meta[map_id]
    xmax, ymax, grid = load_grid(info['fileName'])
    cat = info['category']
    ents: list[tuple[int, int]] = []
    signs: list[tuple[int, int]] = []
    for y in range(ymax):
        for x in range(xmax):
            v = grid[y][x]
            if cat == 'town':
                if v == 22:
                    ents.append((x + 1, y + 1))
                elif v == 23:
                    signs.append((x + 1, y + 1))
            elif cat == 'ground':
                if v == 22:
                    signs.append((x + 1, y + 1))
                elif v >= 51:
                    ents.append((x + 1, y + 1))
            else:
                if v == 53:
                    signs.append((x + 1, y + 1))
                elif v == 54:
                    ents.append((x + 1, y + 1))
    return {'entrances': ents, 'signs': signs}


def slice_arms(lines: list[str], pattern: re.Pattern) -> list[tuple[int, list[str]]]:
    """`case party.map of` 팔을 (맵 번호, 줄 목록)으로 나눈다."""
    arms: list[tuple[int, list[str]]] = []
    current: int | None = None
    depth = 0
    for raw in lines:
        m = pattern.match(raw)
        if m and depth == 0:
            if current is not None:
                arms.append((current, body))
            current = int(m.group(1))
            body = [raw]
            depth = 1
            continue
        if current is None:
            continue
        body.append(raw)
        depth += len(re.findall(r'\bbegin\b', raw, re.I))
        depth -= len(re.findall(r'\bend\b', raw, re.I))
    if current is not None:
        arms.append((current, body))
    return arms


def parse_entermode() -> dict[int, dict]:
    """맵별 `at(x,y)` → (이름, 목적지) 블록."""
    lines = load_lines(SRC)
    start = next(i for i, l in enumerate(lines) if l.startswith('Procedure entermode'))
    end = next(i for i, l in enumerate(lines) if l.startswith('Procedure sign'))
    arms = slice_arms(lines[start:end], ARM)
    out: dict[int, dict] = {}
    for map_id, body in arms:
        blocks: list[dict] = []
        current: dict | None = None
        for raw in body:
            if current is None or (AT.search(raw) and current['ats']):
                cond = None
                if not AT.search(raw):
                    m2 = re.search(r'if\s+(y\s*[<>=]+\s*\d+)\s+then', raw)
                    cond = m2.group(1) if m2 else None
                current = {
                    'ats': [], 'name': None, 'target': None,
                    'lines': [], 'cond': cond,
                }
                blocks.append(current)
            if current is None:
                continue
            current['lines'].append(raw)
            for a, b in AT.findall(raw):
                if (int(a), int(b)) not in current['ats']:
                    current['ats'].append((int(a), int(b)))
            w = WANT.search(raw)
            if w and current['name'] is None:
                current['name'] = w.group(1)
            t = TARGET.search(raw)
            if t and current['target'] is None:
                current['target'] = (int(t.group(1)), int(t.group(2)), int(t.group(3)))
        out[map_id] = {'blocks': blocks}
    return out


def parse_signs() -> dict[int, dict]:
    """맵별 푯말 문구(`at(x,y)` 블록) + 맵 기본 문구(else)."""
    lines = load_lines(SRC)
    start = next(i for i, l in enumerate(lines) if l.startswith('Procedure sign'))
    arms = slice_arms(lines[start:], SIGN_ARM)
    out: dict[int, dict] = {}
    for map_id, body in arms:
        entries: list[dict] = []
        current: dict | None = None
        for raw in body:
            if AT.search(raw):
                current = {'coords': [], 'lines': []}
                entries.append(current)
            elif re.search(r'\belse\b', raw):
                current = {'coords': [], 'lines': [], 'default': True}
                entries.append(current)
            elif re.search(r"Print|message", raw):
                # 팔 시작 직후 첫 출력(맵 전체 문구, 예: 맵 19/23)만 arm 레벨로 본다.
                if current is None:
                    current = {'coords': [], 'lines': [], 'armLevel': True}
                    entries.append(current)
            if current is None:
                continue
            current['lines'].append(raw)
            for a, b in AT.findall(raw):
                if (int(a), int(b)) not in current['coords']:
                    current['coords'].append((int(a), int(b)))
            if 'else' in raw and 'print' in raw.lower():
                entries.append({'coords': [], 'lines': [raw], 'default': True})
        out[map_id] = {'entries': entries}
    return out


def y_filter(cond: str | None):
    """`y <= 6` / `y > 6` 같은 진입 조건을 좌표 필터로 바꾼다."""
    if not cond:
        return None
    m = re.search(r'y\s*(<=|>=|<|>)\s*(\d+)', cond)
    if not m:
        return None
    op, n = m.group(1), int(m.group(2))
    if op == '<=':
        return lambda p: p[1] <= n
    if op == '<':
        return lambda p: p[1] < n
    if op == '>=':
        return lambda p: p[1] >= n
    return lambda p: p[1] > n


def build() -> tuple[list[dict], list[dict], list[dict], set[str]]:
    """(포털, 퐷말, 진입 스크립트, 대체할 스크립트 id)"""
    meta = map_meta()
    entermode = parse_entermode()
    signs = parse_signs()

    portals: list[dict] = []
    for map_id in sorted(entermode):
        info = tiles_for(map_id, meta)
        for block in entermode[map_id]['blocks']:
            target = block['target']
            if target is None:
                continue
            name = block['name'] or f'map{map_id}'
            coords = block['ats'] if block['ats'] else info['entrances']
            filt = y_filter(block.get('cond'))
            if block['ats'] and len(block['ats']) == 1 and not block['ats'][0] in info['entrances']:
                continue
            for cx, cy in coords:
                if filt and not filt((cx, cy)):
                    continue
                portals.append({
                    'map': map_id,
                    'x': cx,
                    'y': cy,
                    'targetMap': target[0],
                    'targetX': target[1],
                    'targetY': target[2],
                    'name': name,
                })

    sign_rules: list[dict] = []
    for map_id in sorted(signs):
        info = tiles_for(map_id, meta)
        blocks = [
            e for e in signs[map_id]['entries'] if not e.get('default')
        ]
        defaults = [e for e in signs[map_id]['entries'] if e.get('default')]
        covered = {c for b in blocks for c in b['coords']}
        # `at` 없는 맵 전체 문구(예: 맵 19/23)는 그 맵의 모든 퐷말에 적용한다.
        arm_level = [e for e in signs[map_id]['entries'] if e.get('armLevel')]
        for block in arm_level:
            got = texts(block['lines'], 1, len(block['lines']))
            text = SIGN_HEADER + ('\n' + '\n'.join(got) if got else '')
            change = None
            for raw in block['lines']:
                m = re.search(r'map\[(\d+)\s*,\s*(\d+)\]\s*:=\s*(\d+)', raw)
                if m:
                    change = {
                        'map': map_id, 'x': int(m.group(1)), 'y': int(m.group(2)),
                        'tile': int(m.group(3)),
                    }
            targets = [c for c in info['signs'] if c not in covered]
            if not targets:
                # 원작에는 있으나 해당 맵에 퐷말 타일이 없는 분기(도달 불가).
                rule = {'map': map_id, 'mapDefault': True, 'text': text}
                if change:
                    rule['setTile'] = change
                sign_rules.append(rule)
                continue
            for cx, cy in targets:
                rule = {'map': map_id, 'x': cx, 'y': cy, 'text': text}
                if change:
                    rule['setTile'] = change
                sign_rules.append(rule)
                covered.add((cx, cy))
        for block in blocks:
            text = SIGN_HEADER
            lines_ = [
                l for l in block['lines']
                if 'y+y1' not in l and ",s," not in l and 'str(j,s)' not in l
            ]
            got = texts(lines_, 1, len(lines_))
            if got:
                text += '\n' + '\n'.join(got)
            for cx, cy in block['coords']:
                sign_rules.append({'map': map_id, 'x': cx, 'y': cy, 'text': text})
        if defaults:
            got = texts(defaults[0]['lines'], 1, len(defaults[0]['lines']))
            text = SIGN_HEADER + ('\n' + '\n'.join(got) if got else '')
            sign_rules.append({'map': map_id, 'mapDefault': True, 'text': text})

    scripts = build_enter_scripts(entermode)
    return portals, sign_rules, scripts, {'map6-gate-open'}


def build_enter_scripts(entermode: dict[int, dict]) -> list[dict]:
    lines = load_lines(SRC)
    out: list[dict] = []

    def say(items):
        return [{'say': t} for t in items]

    # --- 맵 6: 성문 개방 (LOREENT case 1 CASTLE LORE) ---
    out.append({
        'id': 'enter-6-castle-gate', 'trigger': 'enter', 'map': 6,
        'steps': [
            {'setTile': {'map': 6, 'x': 49, 'y': 52, 'tile': 47}},
            {'setTile': {'map': 6, 'x': 50, 'y': 52, 'tile': 44}},
            {'setTile': {'map': 6, 'x': 51, 'y': 52, 'tile': 44}},
            {'setTile': {'map': 6, 'x': 52, 'y': 52, 'tile': 44}},
            {'setTile': {'map': 6, 'x': 53, 'y': 52, 'tile': 47}},
            {'setTile': {'map': 6, 'x': 49, 'y': 53, 'tile': 47}},
            {'setTile': {'map': 6, 'x': 50, 'y': 53, 'tile': 44}},
            {'setTile': {'map': 6, 'x': 51, 'y': 53, 'tile': 44}},
            {'setTile': {'map': 6, 'x': 52, 'y': 53, 'tile': 44}},
            {'setTile': {'map': 6, 'x': 53, 'y': 53, 'tile': 45}},
            {'setTileArea': {'map': 6, 'xMin': 49, 'xMax': 53, 'yMin': 88,
                             'yMax': 88, 'tile': 44}},
        ],
    })
    # --- 맵 7: Polaris 합류 시 (37,41) 정리 ---
    out.append({
        'id': 'enter-7-polaris-tile', 'trigger': 'enter', 'map': 7,
        'require': {'flag': 'polarisJoined'},
        'steps': [{'setTile': {'map': 7, 'x': 37, 'y': 41, 'tile': 44}}],
    })
    # --- 맵 10/16: Lore Hunter 합류 시 (40,56) 정리 ---
    for map_id in (10, 16):
        out.append({
            'id': f'enter-{map_id}-hunter-tile', 'trigger': 'enter', 'map': map_id,
            'require': {'flag': 'loreHunterJoined'},
            'steps': [{'setTile': {'map': map_id, 'x': 40, 'y': 56, 'tile': 44}}],
        })
    # --- 맵 11: PYRAMID (etc[13] > 1) ---
    out.append({
        'id': 'enter-11-pyramid', 'trigger': 'enter', 'map': 11,
        'require': {'quest': {'name': 'lastditch', 'gte': 2}},
        'steps': [
            {'setTile': {'map': 11, 'x': 25, 'y': 44, 'tile': 50}},
            {'setTile': {'map': 11, 'x': 26, 'y': 44, 'tile': 50}},
        ],
    })
    # --- 맵 12: EVIL SEAL (etc[14] > 1) ---
    out.append({
        'id': 'enter-12-evilseal', 'trigger': 'enter', 'map': 12,
        'require': {'quest': {'name': 'gaia', 'gte': 2}},
        'steps': [{'setTile': {'map': 12, 'x': 18, 'y': 9, 'tile': 0}}],
    })
    # --- 맵 24: LAST SHELTER (etc[43] bit4) ---
    out.append({
        'id': 'enter-24-shelter', 'trigger': 'enter', 'map': 24,
        'require': {'flag': 'programmerMet'},
        'steps': [{'setTile': {'map': 24, 'x': 33, 'y': 10, 'tile': 47}}],
    })

    # --- 맵 5 → 23 : EVIL CONCENTRATION 수문장 Frost Dragon (etc[44] bit1) ---
    out.append({
        'id': 'portal-5-23-frostdragon', 'trigger': 'portal', 'map': 5,
        'require': {'flagNot': 'frostDragonDefeated'},
        'steps': say(texts(lines, 144, 147)) + [
            {'battle': {'monsters': [54, 54, 54, 54, 54, 54, 69],
                        'title': 'Frost Dragon',
                        'victoryFlag': 'frostDragonDefeated'}},
        ],
    })
    # --- 맵 23 → 25 : DUNGEON OF EVIL 입구 (etc[44] bit2) ---
    out.append({
        'id': 'portal-23-25-dungeon', 'trigger': 'portal', 'map': 23,
        'require': {'flagNot': 'dungeonOfEvilCleared'},
        'steps': say(texts(lines, 288, 299)) + [
            {'battle': {'monsters': [62, 62, 62, 62, 62, 62, 62, 70],
                        'title': 'ArchiDraconian',
                        'victoryFlag': 'dungeonOfEvilCleared'}},
        ],
    })
    # --- 맵 21 → 22 : 라바 게이트 판정 (etc[40]/etc[41] 홀수여야 열린다) ---
    out.append({
        'id': 'portal-21-22-lavagate', 'trigger': 'portal', 'map': 21,
        'require': {'notAllFlags': ['lavaGateKeyLeft', 'lavaGateKeyRight']},
        'steps': say(texts(lines, 205, 205)) + [{'block': True}],
    })
    # --- 맵 22 진입 : Ancient Evil 연출 + 전투 (etc[42] bit7) ---
    out.append({
        'id': 'enter-22-ancient-evil', 'trigger': 'enter', 'map': 22,
        'require': {'flagNot': 'ancientEvilSpeechGiven'},
        'steps': say(texts(lines, 237, 259)) + [
            {'battle': {'monsters': [68], 'title': 'Ancient Evil',
                        'victoryFlag': 'ancientEvilSpeechGiven'}},
        ],
    })
    # --- 맵 25 → 26 : 결전의 방 (DUNGEON OF EVIL 최종 관문) ---
    out.append({
        'id': 'portal-25-26-chamber', 'trigger': 'portal', 'map': 25,
        'steps': say(texts(lines, 336, 336)) + [
            {'battle': {'monsters': [63, 63, 63, 63, 63, 72],
                        'title': 'Necromancer',
                        'victoryFlag': 'bossNecromancerDefeated'}},
        ],
    })
    return out


def main() -> int:
    if '--write' in sys.argv:
        return write()
    meta = map_meta()
    entermode = parse_entermode()
    signs = parse_signs()

    print('=== 진입 (타일 + LOREENT 목적지) ===')
    total_ent = 0
    for map_id in sorted(entermode):
        info = tiles_for(map_id, meta)
        branch = entermode[map_id]['blocks']
        with_at = [b for b in branch if b['ats']]
        without = [b for b in branch if not b['ats']]
        for b in with_at:
            tile_ok = [c for c in b['ats'] if c in info['entrances']]
            total_ent += len(tile_ok)
            print(
                f"map{map_id:>3} {info['entrances'].index(tile_ok[0]) if tile_ok else '-'}"
                f" {b['name']} at={b['ats']} → {b['target']}  (타일 일치 {len(tile_ok)}/{len(b['ats'])})"
            )
        for b in without:
            total_ent += len(info['entrances'])
            print(
                f"map{map_id:>3} {b['name']} (at 없음) 타일진입={info['entrances']} → {b['target']}"
            )
    print(f'진입 타일 합계 {total_ent}개')

    print('\n=== 푯말 (원작 문구 추출) ===')
    for map_id in sorted(signs):
        info = tiles_for(map_id, meta)
        ents = signs[map_id]['entries']
        covered = {c for e in ents for c in e['coords']}
        missing = [c for c in info['signs'] if c not in covered]
        print(
            f"map{map_id:>3} 타일푯말={len(info['signs'])}개, 원작 문구 블록={len(ents)}개,"
            f" 미정의 좌표={missing}"
        )
        for e in ents:
            got = texts(e['lines'], 1, len(e['lines']))
            if got and not all('푯말' in g for g in got):
                print(f"   {e['coords'] or '기본'}: {got[:2]}")
    return 0


DART = os.path.join(ROOT, 'lib', 'game', 'lore_world_manager.dart')


def dart_str(text: str) -> str:
    """Dart 문자열 리터럴(여러 줄은 \n)."""
    body = (
        text.replace('\\', '\\\\')
        .replace("'", "\\'")
        .replace('\n', '\\n')
    )
    return f"'{body}'"


def write_dart_fallback(portals: list[dict], sign_rules: list[dict]) -> None:
    """JSON 과 항상 같은 결과를 내도록 내장 폴백 표를 재생성한다."""
    with open(DART, encoding='utf-8') as fh:
        src = fh.read()

    def portal_entry(p: dict) -> str:
        loc = (
            f'    x: {p["x"]},\n    y: {p["y"]},'
            if p.get('x') is not None
            else f'    yMin: {p["yMin"]},'
        )
        return (
            '  _BuiltInPortal(\n'
            f'    {p["map"]},\n'
            f'{loc}\n'
            f'    targetMap: {p["targetMap"]},\n'
            f'    targetX: {p["targetX"]},\n'
            f'    targetY: {p["targetY"]},\n'
            f'    name: {dart_str(p["name"])},\n'
            '  ),'
        )

    start = src.index('const List<_BuiltInPortal> _builtInPortals = [')
    end = src.index('\n];', start) + len('\n];')
    exits = [p for p in portals if False]
    with open(PORTALS_JSON, encoding='utf-8') as fh:
        data = json.load(fh)
    ordered = [p for p in data['portals'] if p.get('x') is None] + [
        p for p in data['portals'] if p.get('x') is not None
    ]
    block = (
        'const List<_BuiltInPortal> _builtInPortals = [\n'
        '  // 원작 LOREENT.PAS(진입) / LORESPEC.PAS(출구) 좌표.\n'
        '  // `tool/export_lore_ent.py --write` 가 JSON 에서 자동 생성한다.\n'
        + '\n'.join(portal_entry(p) for p in ordered)
        + '\n];'
    )
    src = src[:start] + block + src[end:]

    # 퐷말 폴백: getSignMessage 의 내장 분기를 생성된 규칙으로 교체
    sign_start = src.index('    if (mapId == 2) {', src.index('getSignMessage'))
    sign_end = src.index('    return null;\n  }', sign_start)
    lines = []
    covered: dict[int, list[dict]] = {}
    for rule in sign_rules:
        covered.setdefault(rule['map'], []).append(rule)
    for map_id in sorted(covered):
        rules = covered[map_id]
        lines.append(f'    if (mapId == {map_id}) {{')
        default = [r for r in rules if r.get('mapDefault')]
        for r in rules:
            if r.get('mapDefault'):
                continue
            lines.append(
                f'      if (x == {r["x"]} && y == {r["y"]}) {{'
                f' return {dart_str(r["text"])}; }}'
            )
        for r in default:
            lines.append(f'      return {dart_str(r["text"])};')
        lines.append('    }')
    src = src[:sign_start] + '\n'.join(lines) + '\n' + src[sign_end:]

    with open(DART, 'w', encoding='utf-8') as fh:
        fh.write(src)


def write() -> int:
    portals, sign_rules, scripts, replace_ids = build()
    with open(PORTALS_JSON, encoding='utf-8') as fh:
        data = json.load(fh)
    old_portals = data['portals']
    # 기존 출구 규칙(yMin 등 범위 조건)은 유지하고, 좌표 진입 규칙만 다시 만든다.
    kept = [p for p in old_portals if p.get('x') is None]
    data['portals'] = kept + portals
    data['signs'] = sign_rules
    with open(PORTALS_JSON, 'w', encoding='utf-8') as fh:
        json.dump(data, fh, ensure_ascii=False, indent=2)
        fh.write('\n')

    with open(SCRIPTS_JSON, encoding='utf-8') as fh:
        sdata = json.load(fh)
    merged = [
        s for s in sdata['scripts']
        if s.get('id') not in {e['id'] for e in scripts}
        and s.get('id') not in replace_ids
    ] + scripts
    sdata['scripts'] = merged
    with open(SCRIPTS_JSON, 'w', encoding='utf-8') as fh:
        json.dump(sdata, fh, ensure_ascii=False, indent=2)
        fh.write('\n')
    data['portals'] = kept + portals
    with open(PORTALS_JSON, 'w', encoding='utf-8') as fh:
        json.dump(data, fh, ensure_ascii=False, indent=2)
        fh.write('\n')
    write_dart_fallback(portals, sign_rules)
    print(
        f'포털 {len(portals)}개(출구 {len(kept)}개 유지), 퐷말 {len(sign_rules)}개,'
        f' 진입 스크립트 {len(scripts)}개 (내장 폴백 표 재생성)'
    )
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

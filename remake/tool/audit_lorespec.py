#!/usr/bin/env python3
"""원작 LORESPEC.PAS의 좌표 이벤트를 맵별로 뽑아내는 감사(audit) 도구.

`case party.map of` 블록과 `if on(x,y)` (또는 `at(x,y)`) 조건을 추적해
어떤 맵의 어떤 좌표에서 무슨 일이 일어나는지 요약한다.

사용법:
    python3 tool/audit_lorespec.py repo_source/LORE_1993_src/LORESPEC.PAS
    python3 tool/audit_lorespec.py repo_source/LORE_1993_src/LORESPEC.PAS --json
    python3 tool/audit_lorespec.py repo_source/LORE_1993_src/LORESPEC.PAS --coverage
    python3 tool/audit_lorespec.py repo_source/LORE_1993_src/LORETALK.PAS

`--coverage`는 test/fixtures/legacy_rules/scripts.json + portals.json 과 대조해 아직
이관하지 않은 좌표 이벤트가 있는지 보고한다(미커버가 있으면 종료코드 1).
"""
import json
import re
import sys

# 이벤트 효과로 간주하는 원작 함수/프로시저
EFFECTS = [
    'findgold',
    'join(',
    'wantenter',
    'wantexit',
    'plusgold',
    'specialevent',
    'party.gold',
    'party.food',
    'party.etc[',
    'map[',
    'loadmap',
    'gameover',
    'joinenemy',
    'silent_scroll',
    'scroll(',
]

CASE = re.compile(r'^(\s*)case\s+party\.map\s+of\b')
# `6 : begin` 처럼 begin 이 붙거나, `6 : if on(...)` 처럼 바로 문장이 오는 경우도 있다.
LABEL = re.compile(r'^(\s*)(\d+)\s*:\s*(begin|if\b.*)?\s*$')
ON = re.compile(r'\bon\((\d+)\s*,\s*(\d+)\)|\bat\((\d+)\s*,\s*(\d+)\)')

# 좌표 블록 안에서 관찰할 앞쪽 줄 수
WINDOW = 45


def decode(raw: bytes) -> str:
    try:
        return raw.decode('johab')
    except Exception:  # noqa: BLE001
        return raw.decode('latin-1')


def scan(path: str):
    """(이벤트 목록, 맵 시작 줄 목록)을 돌려준다.

    이벤트: [(map_id, line_no, x, y, [effects])]
    맵 시작: [(map_id, line_no)]
    """
    with open(path, 'rb') as source:
        lines = source.read().split(b'\n')
    decoded = [decode(line).rstrip() for line in lines]

    events = []
    map_starts = []
    case_indents = []  # 열려 있는 `case party.map of` 들여쓰기 스택
    current_map = None

    for idx, line in enumerate(decoded):
        if not line.strip():
            continue
        indent = len(line) - len(line.lstrip())

        m_case = CASE.match(line)
        if m_case:
            case_indents.append(len(m_case.group(1)))
            current_map = None
            continue

        # 열린 case 블록 정리: 같은 들여쓰기 이하의 `end` 를 만나면 블록 종료
        while case_indents and indent <= case_indents[-1] and re.match(
            r'^\s*end\b', line
        ):
            case_indents.pop()
        if not case_indents:
            current_map = None

        if case_indents:
            m_label = LABEL.match(line)
            if m_label and indent == case_indents[-1] + 3:
                current_map = int(m_label.group(2))
                map_starts.append((current_map, idx + 1))
                # `6 : if on(62,82) then ...` 처럼 라벨 뒤에 바로 조건이 오면
                # 같은 줄의 좌표도 이벤트로 잡아야 하므로 continue 하지 않는다.
                if not (m_label.group(3) or '').startswith('if'):
                    continue

        if current_map is None:
            continue

        on = ON.search(line)
        if not on:
            continue
        x = int(on.group(1) or on.group(3))
        y = int(on.group(2) or on.group(4))
        window = '\n'.join(decoded[idx:idx + WINDOW])
        found = [e for e in EFFECTS if e in window]
        events.append((current_map, idx + 1, x, y, found))
    return events, map_starts


def _covers(scripts, portals, map_id, x, y):
    """scripts.json / portals.json 이 해당 좌표를 다루는지 검사한다."""
    for s in scripts:
        if s['map'] != map_id:
            continue
        if s.get('x') is not None and s['x'] != x:
            continue
        if s.get('y') is not None and s['y'] != y:
            continue
        if s.get('xMin') is not None and x < s['xMin']:
            continue
        if s.get('xMax') is not None and x > s['xMax']:
            continue
        if s.get('yMin') is not None and y < s['yMin']:
            continue
        if s.get('yMax') is not None and y > s['yMax']:
            continue
        return s['id']
    for p in portals:
        if p['map'] != map_id:
            continue
        if 'x' in p and p['x'] != x:
            continue
        if 'y' in p and p['y'] != y:
            continue
        if 'yMin' in p and y < p['yMin']:
            continue
        return 'portal:' + p['name']
    return None


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    as_json = '--json' in sys.argv
    coverage = '--coverage' in sys.argv
    if not args:
        print(__doc__)
        return 1

    events, map_starts = scan(args[0])

    if coverage:
        scripts_path = 'test/fixtures/legacy_rules/scripts.json'
        portals_path = 'test/fixtures/legacy_rules/portals.json'
        scripts = json.load(open(scripts_path, encoding='utf-8'))['scripts']
        portals = json.load(open(portals_path, encoding='utf-8'))['portals']
        missing = [
            (m, x, y, e)
            for m, _line, x, y, e in events
            if _covers(scripts, portals, m, x, y) is None
        ]
        print(f'원작 좌표 이벤트 {len(events)}건 / 미커버 {len(missing)}건')
        for m, x, y, effects in missing:
            print(f'  맵 {m} ({x},{y}) -> {", ".join(effects) or "-"}')
        return 1 if missing else 0

    if as_json:
        print(json.dumps(
            {
                'maps': [{'map': m, 'line': line} for m, line in map_starts],
                'events': [
                    {'map': m, 'line': line, 'x': x, 'y': y, 'effects': e}
                    for m, line, x, y, e in events
                ],
            },
            ensure_ascii=False,
            indent=2,
        ))
        return 0

    starts = dict(map_starts)
    last_map = None
    for m, line, x, y, effects in events:
        if m != last_map:
            print(f'\n### MAP {m} (line {starts.get(m, "?")})')
            last_map = m
        print(f'  line {line:5d}  on({x},{y})  -> {", ".join(effects) or "-"}')
    print(f'\n총 {len(events)}개 좌표 이벤트 / 맵 {sorted(starts)}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

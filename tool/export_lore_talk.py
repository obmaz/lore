#!/usr/bin/env python3
"""원작 `LORETALK.PAS`(마을 NPC 대화)를 스크립트 JSON으로 옮기는 도구.

`case party.map of` → `if at(x,y) [and 조건] then ...` 구조를 읽어
`assets/data/lore_talk_scripts.json`(또는 `--report` 출력)을 만든다.

지원하는 원작 구문:
  - `Print(n,'문장')` / `talk('문장')` / `cPrint(n,m,'A','B')`
  - `s := '...'` 누적 + `talk(s+'...')` 연결
  - `player[1].name` → `{hero}` 치환
  - `if random(2) = 0 then A else B` → `randomSteps` 2분기
  - `party.etc[N] and bitM = 0` → `require.flagNot` / `> 0` → `require.flag`
  - `party.etc[N] := party.etc[N] or bitM` → `{"flag": ...}` 스텝

`select`(선택지)/`join`/`map[] :=`/반복문 등이 섞인 분기는 자동 변환이
어려우므로 건너뛰고 보고서에 표시한다(`--report`).

사용법:
    python3 tool/export_lore_talk.py --report
    python3 tool/export_lore_talk.py --emit tool/lore_talk_generated.json
"""
import json
import re
import sys

SRC = 'repo_source/LORE_1993_src/LORETALK.PAS'

# 자동 변환에서 제외할(수동 이관 대상) 키워드
COMPLEX = ['select(', 'join(', 'joinenemy(', 'whom(', 'choosewhom']

AT = re.compile(r"at\((\d+)\s*,\s*(\d+)\)")
FLAG_COND = re.compile(r"party\.etc\[(\d+)\]\s+and\s+bit(\d+)\s*(=|>)\s*0")
FLAG_SET = re.compile(r"party\.etc\[(\d+)\]\s*:=\s*party\.etc\[(\d+)\]\s*or\s+bit(\d+)")
PRINT = re.compile(r"^\s*(?:Print|cPrint|talk|Talk)\s*\(", re.I)
STRING = re.compile(r"'((?:[^']|'')*)'")
SETVAR = re.compile(r"^\s*s\s*:=\s*(.+?);\s*$", re.I)


def decode(raw: bytes) -> str:
    try:
        return raw.decode('johab')
    except Exception:  # noqa: BLE001
        return raw.decode('latin-1')


def unescape(lit: str) -> str:
    return lit.replace("''", "'")


def line_text(line: str, vars_: dict) -> str | None:
    """한 줄에서 원작 대사 문자열을 뽑아낸다(없으면 None)."""
    m = re.search(r"\bthen\s+(.*)$", line, re.I)
    target = m.group(1) if m else line
    if not PRINT.match(target):
        return None
    parts = []
    for s in STRING.finditer(target):
        parts.append(unescape(s.group(1)))
    if not parts:
        # talk(s+'...') 처럼 변수만 쓰는 경우
        if re.search(r"\bs\b", target):
            return vars_.get('s', '')
        return None
    text = ''
    if re.search(r"\bs\b\s*\+", target) or re.match(r"\s*(talk|Talk)\s*\(\s*s\b", target):
        text += vars_.get('s', '')
    text += ''.join(parts)
    if 'player[1].name' in target:
        text += '{hero}'
    return text


RANDOM_SPLIT = re.compile(
    r"if\s+random\(2\)\s*=\s*0\s*then\s+(.*?)\s*else\s+(.*?);", re.S
)


def split_random(text: str):
    """`if random(2) = 0 then A else B;` → (A문장, B문장) 또는 None."""
    m = RANDOM_SPLIT.search(text)
    if not m:
        return None
    return m.group(1).strip(), m.group(2).strip()


def parse_branch(lines, start, indent):
    """`if at(...)` 분기 1개를 읽어 (info, next_index)를 돌려준다."""
    header = lines[start]
    coords = [(int(a), int(b)) for a, b in AT.findall(header)]
    flag_req = None
    m = FLAG_COND.search(header)
    if m:
        name = f'etc{m.group(1)}_bit{m.group(2)}'
        flag_req = ('flagNot' if m.group(3) == '=' else 'flag', name)

    body = []
    depth = 0
    i = start
    if 'begin' not in header:
        # `if at(x,y) then talk('..');` 처럼 한 줄로 끝나거나,
        # `if at(x,y) then` 뒤 다음 줄에 `if ... else ...;` 가 오는 형태.
        body.append(header)
        while not body[-1].rstrip().endswith(';') and i + 1 < len(lines):
            i += 1
            body.append(lines[i])
    else:
        while i < len(lines):
            line = lines[i]
            body.append(line)
            depth += len(re.findall(r'\bbegin\b', line, re.I)) - len(
                re.findall(r'\bend\b', line, re.I)
            )
            if depth <= 0 and i > start:
                break
            i += 1
    return {
        'line': start + 1,
        'coords': coords,
        'flag': flag_req,
        'body': body,
    }, i + 1


def branch_to_steps(branch):
    """분기 본문 → 스텝 목록(자동 변환 가능한 경우) 또는 None."""
    body = '\n'.join(branch['body'])
    # `if random(2) = 0 then A else B` → 같은 줄에 있어 양쪽을 나눠 뽑는다.
    split = split_random(body)
    if split:
        variants = []
        for side in split:
            texts = []
            for lit in STRING.finditer(side):
                texts.append({'say': unescape(lit.group(1))})
            if 'player[1].name' in side:
                texts.append({'say': '{hero}'})
            variants.append(texts)
        if all(variants):
            return [{'randomSteps': variants}], []

    steps = []
    vars_ = {}
    complex_hit = []
    for raw in branch['body']:
        if any(c in raw for c in COMPLEX):
            complex_hit.append(raw.strip()[:60])
        if any(k in raw for k in ['map[', 'for i :=', 'for j :=', 'Scroll', 'scroll',
                                  'putimage', 'PressAnyKey', 'delay', 'displayenemies',
                                  'BattleMode']):
            continue
        m = SETVAR.match(raw)
        if m:
            lit = STRING.search(m.group(1))
            if lit:
                vars_['s'] = unescape(lit.group(1))
            continue
        text = line_text(raw, vars_)
        if text:
            steps.append({'say': text})
            continue
        fm = FLAG_SET.search(raw)
        if fm:
            steps.append({'flag': f'etc{fm.group(1)}_bit{fm.group(3)}'})
    if complex_hit:
        return None, complex_hit
    # 대사가 없고 플래그만 바뀌는 분기는 스킵
    if not any('say' in s for s in steps):
        return None, ['(텍스트 없음)']
    return steps, []


def main() -> int:
    report = '--report' in sys.argv
    emit_path = None
    if '--emit' in sys.argv:
        emit_path = sys.argv[sys.argv.index('--emit') + 1]

    text = decode(open(SRC, 'rb').read()).replace('\r\n', '\n')
    lines = text.split('\n')
    impl = next(i for i, l in enumerate(lines) if 'IMPLEMENTATION' in l.upper())

    scripts = []
    skipped = []
    cur_map = None
    case_indent = None
    i = impl
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        ind = len(line) - len(line.lstrip())
        if re.match(r'^case\s+party\.map\s+of', stripped):
            case_indent = ind
            i += 1
            continue
        if 'at(' in line and stripped.startswith('if'):
            branch, nxt = parse_branch(lines, i, ind)
            steps, complex_hit = branch_to_steps(branch)
            for (x, y) in branch['coords']:
                if steps:
                    entry = {
                        'id': f"talk-{cur_map}-{x}-{y}",
                        'trigger': 'talk',
                        'map': cur_map,
                        'x': x,
                        'y': y,
                        'once': False,
                        'steps': steps,
                    }
                    if branch['flag']:
                        entry['require'] = {branch['flag'][0]: branch['flag'][1]}
                    scripts.append(entry)
                else:
                    skipped.append(
                        (cur_map, x, y, branch['line'], complex_hit)
                    )
            i = nxt
            continue
        if case_indent is not None and ind == case_indent + 3:
            m = re.match(r'^(\d+)\s*:\s*(begin)?\s*$', stripped)
            if m:
                cur_map = int(m.group(1))
        i += 1

    if report:
        from collections import Counter
        per_map = Counter(s['map'] for s in scripts)
        skip_map = Counter(s[0] for s in skipped)
        print(f'자동 변환 가능 분기: {len(scripts)}개')
        for m in sorted(per_map):
            print(f'  맵 {m:>2}: 대사 {per_map[m]:>3}개 / 수동 필요 {skip_map.get(m, 0):>2}개')
        print(f'수동 이관 필요(선택지·조인·지형 변화): {len(skipped)}개')
        for m, x, y, line, why in skipped:
            print(f'  맵 {m:>2} ({x},{y}) L{line}: {", ".join(why)[:70]}')
        return 0

    if emit_path:
        out = {
            'version': 1,
            'source': 'LORETALK.PAS (tool/export_lore_talk.py 자동 생성)',
            'scripts': scripts,
        }
        json.dump(out, open(emit_path, 'w', encoding='utf-8'),
                  ensure_ascii=False, indent=2)
        open(emit_path, 'a').write('\n')
        print(f'{emit_path} 에 {len(scripts)}개 스크립트를 썼다 '
              f'(수동 필요 {len(skipped)}개)')
        return 0

    print(__doc__)
    return 1


if __name__ == '__main__':
    raise SystemExit(main())

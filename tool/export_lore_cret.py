#!/usr/bin/env python3
"""원작 `LORECRET.PAS`(캐릭터 만들기)를 `assets/data/creation.json` 으로 옮긴다.

원작 구성:
  `Display` → `Name` → `First`(12문항 성향 테스트) → `Second`(40포인트 분배)
  → `Third`(계급 선택) → `Fourth`(동료 4명 선택) → `Last`(초기 상태)

사용법:
    python3 tool/export_lore_cret.py            # 미리보기
    python3 tool/export_lore_cret.py --write    # creation.json 생성
"""
from __future__ import annotations

import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from export_lore_quest_talk import decode  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'repo_source', 'LORE_1993_src', 'LORECRET.PAS')
OUT = os.path.join(ROOT, 'assets', 'data', 'creation.json')

CALL = re.compile(r"(?:OutHPrintXY|bHPrint|cHPrint|eHPrint|HPrintXY)\s*\(([^;]*)\)", re.I)
STR = re.compile(r"'((?:[^']|'')*)'")
OPTION = re.compile(r'^\s*([123])\]\s*(.*)$')
WHICH_ANSWER = re.compile(r"if\s+c\s*=\s*'([123])'\s*then\s+inc\(transdata\[(\d+)\]\)")
CHOICE_SET = re.compile(r'transdata\[(\d+)\]\s*:=\s*([01])')


def load_lines() -> list[str]:
    with open(SRC, 'rb') as fh:
        return decode(fh.read()).splitlines()


def lit(text: str) -> str:
    return text.replace("''", "'")


def proc(lines: list[str], name: str) -> list[str]:
    start = next(i for i, l in enumerate(lines) if l.strip().startswith(f'Procedure {name}'))
    end = next(
        (
            i
            for i in range(start + 2, len(lines))
            if re.match(r'^(Procedure|Function)\s+\w+', lines[i])
            or lines[i].startswith('end.')
        ),
        len(lines),
    )
    return lines[start:end]


def const_block(lines: list[str], name: str) -> list[str]:
    start = next(i for i, l in enumerate(lines) if name in l and '=' in l)
    out: list[str] = []
    depth = 0
    for raw in lines[start:]:
        out.append(raw)
        depth += raw.count('(') - raw.count(')')
        if depth <= 0 and (');' in raw or ';' in raw and 'array' not in raw):
            break
    return out


def parse_characters(lines: list[str]) -> list[dict]:
    names_m = re.search(r"CharacterName\s*:\s*array\[1\.\.10\]\s*of\s*string\[\d+\]\s*=\s*\((.*?)\);",
                        '\n'.join(lines), re.S)
    names = [lit(n) for n in STR.findall(names_m.group(1))]
    table_m = re.search(r"Character\s*:\s*array\[1\.\.10,1\.\.10\]\s*of\s*byte\s*=\s*\((.*?)\);",
                        '\n'.join(lines), re.S)
    body = table_m.group(1)
    rows = re.findall(r'\(([^()]*)\)', body)
    out = []
    for idx, row in enumerate(rows[:10]):
        vals = [int(v) for v in re.findall(r'\d+', row)]
        out.append({
            'id': idx + 1,
            'name': names[idx],
            'sex': 'female' if vals[0] == 1 else 'male',
            'class': vals[1],
            'strength': vals[2],
            'mentality': vals[3],
            'concentration': vals[4],
            'endurance': vals[5],
            'resistance': vals[6],
            'agility': vals[7],
            'accuracy': vals[8],
            'luck': vals[9],
        })
    return out


def parse_quiz(lines: list[str]) -> tuple[list[str], list[dict]]:
    """`First` 의 12문항 성향 테스트 → (머리말, 문항들).

    원작은 질문/선택지를 20px 단위 좌표로 출력하며, 6번 문항의 2번 선택지만
    두 줄로 이어진다(둘째 줄은 앞에 공백 3칸).
    """
    raw_items: list[str] = []
    for raw in proc(lines, 'First'):
        m = CALL.search(raw)
        if not m:
            continue
        text = ''.join(lit(x) for x in STR.findall(m.group(1))).replace(chr(4), '')
        if text.strip():
            raw_items.append(text)
    stats: list[int] = []
    for raw in proc(lines, 'First'):
        a = WHICH_ANSWER.search(raw)
        if a:
            stats.append(int(a.group(2)))

    intro: list[str] = []
    groups: list[dict] = []
    current: dict | None = None
    for text in raw_items:
        stripped = text.strip()
        indent = len(text) - len(text.lstrip(' '))
        if OPTION.match(stripped):
            if current is None:
                intro.append(stripped)  # 머리말 뒤에 바로 선택지가 오는 경우
            else:
                current['options'].append(stripped)
            continue
        if current is not None and current['options'] and indent >= 2:
            current['options'][-1] += ' ' + stripped  # 선택지 이어짐
            continue
        if current is None or current['options']:
            current = {'lines': [stripped], 'options': []}
            groups.append(current)
        else:
            current['lines'].append(stripped)  # 두 줄 질문

    questions = [g for g in groups if len(g['options']) == 3]
    if questions and questions[0]['lines']:
        head = questions[0]['lines']
        intro.extend([l for l in head if '묻는 말에 대답' in l or '소신있게' in l])
        questions[0]['lines'] = [l for l in head if l not in intro]
    for qi, q in enumerate(questions):
        q['options'] = [
            {'text': OPTION.match(o).group(0), 'stat': stats[qi * 3 + oi] if qi * 3 + oi < len(stats) else 0}
            for oi, o in enumerate(q['options'])
        ]
    return intro, questions


def parse_classes(lines: list[str]) -> list[dict]:
    body = proc(lines, 'Third')
    out: list[dict] = []
    cond: list[str] = []
    labels = {
        1: '1] 기  사', 2: '2] 마법사', 3: '3] 에스퍼', 4: '4] 전  사',
        5: '5] 전투승', 6: '6] 닌  자', 7: '7] 사냥꾼', 8: '8] 떠돌이',
    }
    for raw in body:
        if 'if (' in raw or ('accuracy' in raw and 'if' in raw):
            cond.append(raw.strip())
        m = CALL.search(raw)
        if m:
            literals = [lit(x) for x in STR.findall(m.group(1))]
            text = ''.join(literals).strip()
            for cid, label in labels.items():
                if text == label:
                    out.append({'class': cid, 'text': label, 'condition': ' '.join(cond)})
                    cond = []
                    break
    return out


def parse_texts(lines: list[str]) -> dict[str, str]:
    out: dict[str, list[str]] = {}
    for name in ('Display', 'Name', 'Profile', 'Second', 'Third', 'Fourth'):
        out[name] = []
        for raw in proc(lines, name):
            m = CALL.search(raw)
            if m:
                literals = [lit(x) for x in STR.findall(m.group(1))]
                text = ''.join(literals).strip()
                if text:
                    out[name].append(text)
                continue
            # `s := '문구';` 형태(원작 Display 의 제목)도 문구로 본다.
            a = re.search(r"^\s*s\s*:=\s*'([^']*)'\s*;", raw)
            if a:
                text = lit(a.group(1)).strip()
                if text:
                    out[name].append(text)
    return {k: v for k, v in out.items()}


DART_FALLBACK = os.path.join(ROOT, 'lib', 'data', 'lore_creation_data.dart')


def dart_str(text: str) -> str:
    body = text.replace('\\', '\\\\').replace("'", "\\'").replace('\n', '\\n')
    return f"'{body}'"


def write_dart_fallback(data: dict) -> None:
    """JSON 을 못 읽을 때 쓰는 내장 표를 생성한다(원문 그대로)."""
    out: list[str] = []
    out.append('// GENERATED by tool/export_lore_cret.py --write')
    out.append('// 원작 LORECRET.PAS 의 캐릭터/문항/직업 조건 (폴백용)')
    out.append('')
    out.append('/// 원작 `CharacterName`/`Character` 표 (10명).')
    out.append('const List<Map<String, Object>> kCreationCharacters = [')
    for c in data['characters']:
        out.append('  {')
        out.append(f"    'id': {c['id']},")
        out.append(f"    'name': {dart_str(c['name'])},")
        out.append(f"    'sex': {dart_str(c['sex'])},")
        out.append(f"    'class': {c['class']},")
        out.append(f"    'strength': {c['strength']},")
        out.append(f"    'mentality': {c['mentality']},")
        out.append(f"    'concentration': {c['concentration']},")
        out.append(f"    'endurance': {c['endurance']},")
        out.append(f"    'resistance': {c['resistance']},")
        out.append(f"    'agility': {c['agility']},")
        out.append(f"    'accuracy': {c['accuracy']},")
        out.append(f"    'luck': {c['luck']},")
        out.append('  },')
    out.append('];')
    out.append('')
    out.append('/// 원작 `First` 의 성향 문답(질문 줄 + 선택지 3 + 스탯 번호).')
    out.append('const List<Map<String, Object>> kCreationQuestions = [')
    for q in data['questions']:
        out.append('  {')
        out.append("    'lines': [")
        for line in q['lines']:
            out.append(f'      {dart_str(line)},')
        out.append('    ],')
        out.append("    'options': [")
        for o in q['options']:
            out.append(
                f"      {{'text': {dart_str(o['text'])}, 'stat': {o['stat']}}},"
            )
        out.append('    ],')
        out.append('  },')
    out.append('];')
    out.append('')
    out.append('/// 원작 문항 안내문.')
    out.append(
        'const List<String> kCreationQuizIntro = ['
        + ', '.join(dart_str(i) for i in data['quizIntro'])
        + '];'
    )
    out.append('')
    out.append('/// 원작 `Third` 의 계급 조건(원문 문자열).')
    out.append('const List<Map<String, Object>> kCreationClasses = [')
    for c in data['classes']:
        out.append(
            f"  {{'class': {c['class']}, 'text': {dart_str(c['text'])}, "
            f"'condition': {dart_str(c['condition'])}}},"
        )
    out.append('];')
    out.append('')
    out.append('/// 원작 문구 모음 (Name/Profile/Second/Third/Fourth).')
    out.append('const Map<String, List<String>> kCreationTexts = {')
    for key, items in data['texts'].items():
        out.append(f"  {dart_str(key)}: [")
        for item in items:
            out.append(f'    {dart_str(item)},')
        out.append('  ],')
    out.append('};')
    out.append('')
    out.append('/// 원작 `First` 끝의 스탯 환산표.')
    out.append(
        'const Map<int, int> kCreationStatMap = {'
        + ', '.join(f'{k}: {v}' for k, v in data['statMap'].items())
        + f'}};'
    )
    out.append(f'const int kCreationStatMapDefault = {data["statMapDefault"]};')
    out.append('')
    out.append('/// 원작 `Last` 의 초기 상태.')
    out.append(
        f'const Map<String, int> kCreationInitial = '
        f"{{'map': {data['initial']['map']}, 'x': {data['initial']['x']}, "
        f"'y': {data['initial']['y']}, 'food': {data['initial']['food']}, "
        f"'gold': {data['initial']['gold']}}};"
    )
    out.append('')
    with open(DART_FALLBACK, 'w', encoding='utf-8') as fh:
        fh.write('\n'.join(out))


def main() -> int:
    lines = load_lines()
    data = {
        'version': 1,
        'description': 'LORE 1993 LORECRET.PAS 캐릭터 생성 데이터',
        'characters': parse_characters(lines),
        'quizIntro': parse_quiz(lines)[0],
        'questions': parse_quiz(lines)[1],
        'classes': parse_classes(lines),
        'texts': parse_texts(lines),
        'statMap': {'0': 5, '1': 7, '2': 11, '3': 14, '4': 17, '5': 19, '6': 20},
        'statMapDefault': 10,
        'initial': {'map': 6, 'x': 51, 'y': 31, 'food': 20, 'gold': 2000},
    }
    if '--write' not in sys.argv:
        print(json.dumps(data, ensure_ascii=False, indent=1)[:4000])
        return 0
    with open(OUT, 'w', encoding='utf-8') as fh:
        json.dump(data, fh, ensure_ascii=False, indent=2)
        fh.write('\n')
    write_dart_fallback(data)
    print(
        f"characters {len(data['characters'])}, questions {len(data['questions'])},"
        f" classes {len(data['classes'])}, texts {len(data['texts'])}"
    )
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

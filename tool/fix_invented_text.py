#!/usr/bin/env python3
"""원작에 없는 문구를 걷어내고 **원문 그대로**로 되돌리는 도구.

`tool/audit_invented.py` 가 찾아낸 항목들 중, 원작에 같은 자리의 문구가 있는 것은
그 문구(원작 `Print` 리터럴)로 바꾸고, 원작에 문구가 아예 없는 곳은 지운다.

문구를 바꿀 때 원작 `Print` 한 줄을 `say` 하나로 옮긴다(생성기와 같은 규칙).

사용법:
    python3 tool/fix_invented_text.py --dry
    python3 tool/fix_invented_text.py --write
"""
from __future__ import annotations

import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPTS = os.path.join(ROOT, 'assets/data/scripts.json')

# ── 1) 문구를 통째로 걷어내는 곳(원작에 그 자리 문구가 없음) ──
DROP_SAY = [
    'den7-dragons-y13',
    'den7-mudmen-y13',
    'den7-return-y13',
    'den7-passage-y71',
    'den7-passage-y88',
    'keep2-guards-y25',
    'keep25-corridor-15-34',
    'keep25-corridor-36-34',
    'map17-shortcut-72',
    'map17-passage-38',
    't_den2-trap-y10',
]

# `den7-quiz-y54` 의 "정답이다!/오답이다!" 는 원작에 없는 문구지만, 원작의
# 미로 퀴즈(길 선택)를 포트에서 대화 선택지로 바꿔 놓은 자리의 **조작 피드백**
# 이라 남긴다(원작에도 길이 열리고 닫히는 결과는 있었다).

# ── 1b) 항목에서 특정 문구만 삭제 ──
DROP_SAY_TEXT: dict[str, list[str]] = {
    # 원작은 레버 문구만 인쇄한다(뒤 문장은 포트가 만든 것).
    'evil-seal-lever-b': ['동굴 중심부의 봉쇄가 풀렸다. 일곱 개의 방 중 한 곳에 봉인이 숨겨져 있다.'],
}

# ── 1c) 전투 제목 교체(원작에 있는 이름으로) ──
# 원작은 `Displayenemies` 로 적 이름을 보여 준다. 포트는 그 자리에 제목 한 줄을
# 대신 출력하므로, 제목을 **원작 이름**으로 맞춘다(원작이 `name :=` 로 붙인 이름을
# 우선하고, 없으면 원작 적 데이터의 이름을 쓴다). `None` = 제목 없앰.
TITLE_FIX: dict[str, str | None] = {
    # 원작 이름표 "CRAB GOD의 왕이다" (map 19 봉인지기)
    'evil-seal-room-1': 'Crab God',
    'evil-seal-room-2': 'Crab God',
    'evil-seal-room-3': 'Crab God',
    'evil-seal-room-4': 'Crab God',
    'evil-seal-room-5': 'Crab God',
    'evil-seal-room-6': 'Crab God',
    'evil-seal-room-7': 'Crab God',
    'evil-seal-guardians': 'Crab God',
    # 원작 `name := 'Soldier'+chr(48+i)` (map 6 수감소)
    'prison-battle-first': 'Soldier',
    'prison-battle-return': 'Soldier',
    # 원작 `name := 'Major Mummy'` (map 11 미이라의 방)
    'mummy-room': 'Major Mummy',
    # 원작 `enemy[3].name := 'ArchiGagoyle'` (map 15 QUAKE)
    'quake-boss-room': 'ArchiGagoyle',
    # 원작 "죽음의 기사 Death Knight" (map 22 요새 매복)
    'keep2-ambush-zone-a': 'Death Knight',
    'keep2-ambush-zone-b': 'Death Knight',
    # map 22 수문장 전투는 원작에 붙은 이름이 없음 → 제목 없음
    'keep2-guards-y25': None,
    # 원작 적 데이터 이름
    'den7-dragons-y13': 'Dragon',
    'den7-mudmen-y13': 'Mud-Man',
    'den7-master-y13': 'Astral Mud',
}

# ── 1d) 선택지 문구 교체 — 원작 `m[n]` 줄에서 **그대로** 읽어 온다 ──
# (키: (스크립트 id, 선택지 번호), 값: (원작 파일, 줄 번호))
CHOICE_SOURCE: dict[tuple[str, int], tuple[str, int]] = {
    # Red Antares 합류 제안 — 원작 `m[1]` / `m[2]`
    ('redantares-join', 0): ('LORESPEC.PAS', 1034),
    ('redantares-join', 1): ('LORESPEC.PAS', 1035),
}

# ── 2) 원작 문구로 교체(원작 `Print` 줄 단위) ──
EXPLICIT: dict[str, list[str]] = {
    # LORESPEC.PAS:531~ (map 11 미이라의 방)
    'mummy-room': [
        '당신은 미이라의 방을 발견했다.',
        '당신들은 Major Mummy 물리쳤다.',
        '그리고 당신은 이 임무에 성공했다.',
    ],
    # LORESPEC.PAS:879~ (map 15 QUAKE 최심부)
    'quake-boss-room': [
        '당신은 ArchiGagoyle과 두마리의 Zombie를 발견했다.',
        '당신은 ArchiGagoyle을 물리쳤다.',
    ],
    # LORESPEC.PAS:1880~ (map 23 함정 옆 푯말)
    'keep3-trap-25-27': [
        ' 푯말에 쓰여 있는 대로 이 곳의 레버를 당겼 ',
        '더니 굉음과 함께 감추어져 있었던 성이 지하 ',
        '로부터 떠 올랐다.',
    ],
    # LORESPEC.PAS:1760~ (map 21 라바 게이트 앞)
    'keep1-seal-gate-a': [
        ' 당신은 아직 라바 게이트를 열수가 없다',
        ' 아직 당신은 이 대륙의 동굴속에  존재하',
        ' 는 2개의 봉인을 풀지 못했기 때문이다.',
    ],
    'keep1-seal-gate-b': [
        ' 당신은 아직 라바 게이트를 열수가 없다',
        ' 아직 당신은 이 대륙의 동굴속에  존재하',
        ' 는 2개의 봉인을 풀지 못했기 때문이다.',
    ],
    # LORESPEC.PAS:2065~ (map 25 레버)
    'keep3-key-a-first': [
        ' 당신이 레버를 당기자  철컥하는 소리가 동굴',
        '에 울려 퍼졌다.',
    ],
    'keep3-key-b-first': [
        ' 당신이 레버를 당기자  철컥하는 소리가 동굴',
        '에 울려 퍼졌다.',
    ],
    'keep3-key-a-second': [
        ' 당신이 레버를 당기자  철컥하는 소리가 동굴',
        '에 울려 퍼졌다.',
        ' 곧 이어 기계 작동하는 큰 소리가 들렸다.',
    ],
    'keep3-key-b-second': [
        ' 당신이 레버를 당기자  철컥하는 소리가 동굴',
        '에 울려 퍼졌다.',
        ' 곧 이어 기계 작동하는 큰 소리가 들렸다.',
    ],
    # LORESPEC.PAS:1600~ (map 20 미로, 소를 닮은 괴물)
    'den7-minotaur-y48': ['미로속에서 소를 닮은 괴물이 나타났다'],
    # LORESPEC.PAS:1720~ (map 20 Astral Mud)
    'den7-master-y13': [
        ' 나는 Necromacer 와 함께 다른 차원에서 내려',
        '온 Astral Mud 이다. 여기는 그가 세운 최고의',
        '동굴이자 너가 마지막으로 거칠 동굴이다.  나',
        '를 만만하게 보지마라.  다른 차원의 능력들을',
        '너가 맛볼 기회를 가진다는 것에 대해  고맙게',
        '생각하기 바란다. 하하하 ...',
    ],
    # LORESPEC.PAS:1454~ (map 19 CRAB GOD의 왕)
    'evil-seal-guardians': [
        '나는 EVIL GOD의 봉인을 지키고 있는 CRAB GOD',
        '의 왕이다. CRAB GOD 족의 명예를 걸고 절대로',
        '너희 같은 자들에게 봉인을 넘겨주지 않겠다!!',
    ],
    # LORESPEC.PAS:828~ (map 14 MENACE 중심) — 원작은 백틱(`)을 인용부호로
    # 썼는데 포트가 작은따옴표로 바꿔 놓았다. 아래 PRINT_SOURCE 로 원문을 읽는다.
    # LORETALK.PAS:192~ (Mad Joe)
    'madjoe-join': [
        ' 히히히... 위대한 용사님. 낄낄낄.. 내가 당',
        '신들의 일행에 끼이면 안될까요 ? 우히히히..',
    ],
    # LORESPEC.PAS:605~ (Rigel)
    'rigel-join': [
        ' 일행들은 심한 부상 때문에 거의 몸을 가누지',
        '못하는 한 남자와 마주쳤다.',
        ' 나는 VALIANT PEOPLES 의 용사였던  Rigel 이',
        '오. 내가 동굴속에서 적들을 막아내는 동안 지',
        '각변동으로 인해  이런 절벽이 군데 군데 생겼',
        '소.  나는 이제 너무 지치고 많은 상처를 입어',
        '서 혼자 힘으로는 이곳을 빠져 나갈수가 없소.',
        ' 나를 도와 주시오.',
    ],
    # LORESPEC.PAS:1075~ (Red Antares) → SAY_SOURCE 로 생성본을 그대로 쓴다.
}

# ── 3) 선택지 응답 문구 교체 ──
OPTION_FIX: dict[tuple[str, int], list[str]] = {
    # Rigel - "식량과 치료는 해결해 주겠소"
    ('rigel-join', 1): [
        ' 일행은 그에게 치료 마법을 사용하여  상처를',
        '모두 치료한후  그가 이곳을 빠져 나갈수 있을',
        '정도의 식량을 나누어 주었다. 그러자 Rigel이',
        '란 그 용사는 우리의 무기에 신의 축복을 내려',
        '주고는 자신의 길을 떠났다.',
    ],
    # Rigel - "당신을 도와줄 시간이 없소" (원작은 문구 없음)
    ('rigel-join', 2): [],
    # Mad Joe - 거절 (원작 `asyouwish`)
    ('madjoe-join', 1): ['당신이 바란다면 ...'],
    # Red Antares - 거절
    ('redantares-join', 1): ['나는 다시 영혼의 세계로 돌아가야 겠소.'],
    # Spica - 거절(원작은 문구 없이 그냥 빠져나간다)
    ('spica-join', 1): [],
}

# ── 4) 대사 전체 교체(초상 제거 + 원문) ──
SAY_SOURCE = {
    'redantares-teach': 'spec-17-L1010xxxx',
    'redantares-join': 'spec-17-L1010xx',
    'spica-cannot-read': 'spec-18-L1174-5',
    'spica-join': 'spec-18-L1174-6',
    'draconian-lecture': 'spec-4-L37-1',
    'draconian-join': 'spec-4-L37-2',
}

# ── 5) 원작 `Print` 줄에서 문구를 직접 읽어 채운다 ──
# (키: 스크립트 id, 값: (원작 파일, 시작 줄, 끝 줄))
PRINT_SOURCE: dict[str, tuple[str, int, int]] = {
    # map 14 MENACE 중심 — 원작 `Print` 3줄
    'menace-center-25-8': ('LORESPEC.PAS', 828, 830),
    'menace-center-26-8': ('LORESPEC.PAS', 828, 830),
}


def original_line(fname: str, lineno: int) -> str:
    """원작 `.PAS` 의 한 줄에서 `m[n] := '...'` 리터럴을 **그대로** 읽는다."""
    path = os.path.join(ROOT, 'repo_source', 'LORE_1993_src', fname)
    raw = open(path, 'rb').read()
    for enc in ('cp1361', 'cp949'):
        try:
            text = raw.decode(enc)
            break
        except Exception:
            continue
    else:
        text = raw.decode('cp949', 'replace')
    line = text.replace('\r\n', '\n').split('\n')[lineno - 1]
    m = re.search(r"m\[\d+\]\s*:=\s*'((?:[^']|'')*)'", line)
    if not m:
        raise SystemExit(f'원작 {fname}:{lineno} 에서 선택지 문구를 못 찾음: {line!r}')
    return m.group(1).replace("''", "'")


def original_prints(fname: str, first: int, last: int) -> list[str]:
    """원작 `.PAS` 의 줄 범위에서 `Print(...)` 한 줄당 문구 하나를 뽑는다."""
    path = os.path.join(ROOT, 'repo_source', 'LORE_1993_src', fname)
    raw = open(path, 'rb').read()
    for enc in ('cp1361', 'cp949'):
        try:
            text = raw.decode(enc)
            break
        except Exception:
            continue
    else:
        text = raw.decode('cp949', 'replace')
    lines = text.replace('\r\n', '\n').split('\n')
    out: list[str] = []
    for i in range(first - 1, last):
        line = lines[i]
        lits = [m.group(1).replace("''", "'")
                for m in re.finditer(r"'([^']*)'", line)]
        lits = [t for t in lits if t.strip()]
        if lits:
            out.append(''.join(lits))
    return out


def replace_says(entry: dict, texts: list[str]) -> None:
    """항목의 `say` 스텝을 원문 문구로 바꾼다(나머지 스텝 순서는 유지)."""
    steps = entry['steps']
    first = next((i for i, s in enumerate(steps) if 'say' in s), len(steps))
    kept = [s for s in steps if 'say' not in s]
    new = [{'say': t} for t in texts]
    entry['steps'] = kept[:first] + new + kept[first:]


def drop_says(entry: dict) -> None:
    entry['steps'] = [s for s in entry['steps'] if 'say' not in s]


def main() -> int:
    write = '--write' in sys.argv
    data = json.load(open(SCRIPTS))
    entries = {e['id']: e for e in data['scripts']}
    changed: list[str] = []

    for eid in DROP_SAY:
        if eid in entries:
            before = len(entries[eid]['steps'])
            drop_says(entries[eid])
            if len(entries[eid]['steps']) != before:
                changed.append(f'{eid}: 문구 {before - len(entries[eid]["steps"])}개 삭제(원작에 없음)')

    for eid, texts in DROP_SAY_TEXT.items():
        entry = entries.get(eid)
        if entry is None:
            print(f'!! 없는 항목: {eid}')
            continue
        drop = set(texts)
        before = len(entry['steps'])
        entry['steps'] = [s for s in entry['steps'] if s.get('say') not in drop]
        changed.append(f'{eid}: 문구 {before - len(entry["steps"])}개 삭제')

    for eid, texts in EXPLICIT.items():
        if eid not in entries:
            print(f'!! 없는 항목: {eid}')
            continue
        replace_says(entries[eid], texts)
        changed.append(f'{eid}: 원문 {len(texts)}줄로 교체')

    for (eid, idx), texts in OPTION_FIX.items():
        entry = entries.get(eid)
        if entry is None:
            print(f'!! 없는 항목: {eid}')
            continue
        opts = None
        for st in entry['steps']:
            if isinstance(st.get('choice'), dict):
                opts = st['choice']['options']
        if not opts or idx >= len(opts):
            print(f'!! 선택지 없음: {eid}[{idx}]')
            continue
        opt = opts[idx]
        keep = [s for s in opt.get('steps', []) if 'say' not in s]
        opt['steps'] = [{'say': t} for t in texts] + keep
        changed.append(f'{eid}: 선택지 {idx} → {texts if texts else "문구 없음"}')

    for eid, src in SAY_SOURCE.items():
        if eid not in entries or src not in entries:
            print(f'!! 없는 항목: {eid} / {src}')
            continue
        texts = [s['say'] for s in entries[src]['steps'] if 'say' in s]
        replace_says(entries[eid], texts)
        changed.append(f'{eid}: {src} 원문 {len(texts)}줄로 교체')

    def battle_steps(entry: dict):
        return [st for st in entry['steps'] if isinstance(st.get('battle'), dict)]

    for eid, new_title in TITLE_FIX.items():
        entry = entries.get(eid)
        if entry is None:
            print(f'!! 없는 항목: {eid}')
            continue
        for st in battle_steps(entry):
            old = st['battle'].get('title')
            if old == new_title:
                continue
            if new_title is None:
                st['battle'].pop('title', None)
            else:
                st['battle']['title'] = new_title
            changed.append(f'{eid}: 전투 제목 {old!r} → {new_title!r}')

    for (eid, idx), (fname, lineno) in CHOICE_SOURCE.items():
        entry = entries.get(eid)
        opts = None
        for st in entry['steps'] if entry else []:
            if isinstance(st.get('choice'), dict):
                opts = st['choice']['options']
        if not opts or idx >= len(opts):
            print(f'!! 선택지 없음: {eid}[{idx}]')
            continue
        text = original_line(fname, lineno)
        if opts[idx]['text'] != text:
            changed.append(f'{eid}: 선택지 {idx} {opts[idx]["text"]!r} → {text!r}')
            opts[idx]['text'] = text

    for eid, (fname, first, last) in PRINT_SOURCE.items():
        if eid not in entries:
            print(f'!! 없는 항목: {eid}')
            continue
        texts = original_prints(fname, first, last)
        replace_says(entries[eid], texts)
        changed.append(f'{eid}: {fname}:{first}-{last} 원문 {len(texts)}줄로 교체')

    for line in changed:
        print(' -', line)
    print(f'총 {len(changed)}개 항목')
    if write:
        json.dump(data, open(SCRIPTS, 'w'), ensure_ascii=False, indent=1)
        open(SCRIPTS, 'a').write('\n')
        print('assets/data/scripts.json 갱신 완료')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

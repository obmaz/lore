#!/usr/bin/env python3
"""생성된 스크립트 JSON을 `assets/data/scripts.json` 에 병합한다.

- 이미 같은 `(trigger, map, x, y)` 가 있으면 **기존 항목을 그대로 둔다**
  (손으로 다듬은 문구/플래그를 덮어쓰지 않기 위해).
- 새 좌표만 파일 **끝에 덧붙인다**(원작은 첫 일치 분기를 실행하므로 순서 유지).
- 병합 후 중복 좌표가 남으면 경고한다.

사용법:
    python3 tool/merge_scripts.py <생성파일.json> [--write]
"""
from __future__ import annotations

import json
import sys

TARGET = 'assets/data/scripts.json'


def key(entry):
    return (
        entry.get('trigger'),
        entry.get('map'),
        entry.get('x'),
        entry.get('y'),
        entry.get('xMin'),
        entry.get('xMax'),
        entry.get('yMin'),
        entry.get('yMax'),
    )


def kinds(entry) -> set:
    """스텝 종류 집합(효과 비교용)."""
    out = set()
    for st in entry.get('steps', []):
        out.update(st.keys())
    return out


def merge_spec(existing, gen, replace_ok: bool = False):
    """원작에서 기계적으로 옮긴 스크립트를 반영한다.

    같은 좌표에 손으로 쓴 스크립트가 이미 있으면,
    - 옮긴 쪽이 그 스크립트의 효과 종류를 **모두** 포함하면 대체한다
      (원작 문구 그대로 + 같은 효과).
    - 못 옮긴 효과가 하나라도 있으면 대체하지 않고 뒤에 덧붙인다
      (기존 동작을 잃지 않기 위해).

    인덱스를 직접 지우면 순서가 밀리므로, 먼저 계획을 세운 뒤 목록을
    **한 번만** 훑어서 새 목록을 만든다.
    """
    by_key = {}
    for idx, e in enumerate(existing):
        by_key.setdefault(key(e), []).append(idx)

    gen_by_key = {}
    for e in gen:
        gen_by_key.setdefault(key(e), []).append(e)

    plan = {}          # key -> 'replace' | 'append'
    decisions = []
    for k, items in gen_by_key.items():
        have = by_key.get(k, [])
        if not have:
            plan[k] = 'new'
            continue
        existing_kinds = set()
        for idx in have:
            existing_kinds |= kinds(existing[idx])
        gen_kinds = set()
        for e in items:
            gen_kinds |= kinds(e)
        missing = sorted(existing_kinds - gen_kinds)
        # 손으로 쓴 스크립트의 동작을 그대로 두고, 옮긴 쪽은 **원작 문구 보관용**
        # 으로만 넣는다. (효과가 완전히 겹치는 항목은 `--replace-ok` 로 표시해
        # 두어 나중에 대체 여부를 판단할 수 있게 한다.)
        if not missing and replace_ok:
            # 옮긴 쪽이 손으로 쓴 스크립트의 효과를 모두 포함한다 → 대체한다.
            plan[k] = 'replace'
            decisions.append((k, [existing[i]['id'] for i in have], [],
                              'replace'))
        else:
            plan[k] = 'append'
            decisions.append((k, [existing[i]['id'] for i in have], missing,
                              'append' if missing else 'append(대체가능)'))

    out = []
    for idx, e in enumerate(existing):
        k = key(e)
        mode = plan.get(k)
        if mode == 'replace':
            # 옮긴 쪽이 완전히 대신한다(첫 항목 자리에만 넣는다).
            if idx == by_key[k][0]:
                out.extend(gen_by_key[k])
            continue
        out.append(e)
        if mode == 'append' and idx == by_key[k][-1]:
            # 손으로 쓴 스크립트가 못 옮긴 효과(전투/장비/동료 등)를 갖고 있다.
            # 그 동작을 잃지 않도록 기존 것을 그대로 실행하고, 옮긴 쪽은
            # 원작 문구 보관용으로만 넣어 둔다(실행하지 않는다).
            for item in gen_by_key[k]:
                item = dict(item)
                item['disabled'] = True
                out.append(item)

    # 새 좌표(기존에 없던 것)는 끝에 덧붙인다.
    for k, items in gen_by_key.items():
        if plan.get(k) == 'new':
            out.extend(items)
    return out, decisions


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    src = sys.argv[1]
    write = '--write' in sys.argv

    with open(TARGET, encoding='utf-8') as fh:
        data = json.load(fh)
    existing = data['scripts']
    have = {key(e) for e in existing}

    with open(src, encoding='utf-8') as fh:
        gen = json.load(fh)

    if '--spec' in sys.argv:
        replace_ok = '--replace-ok' in sys.argv
        merged, decisions = merge_spec(existing, gen['scripts'], replace_ok)
        print('원작 이관 스크립트 병합:')
        for k, ids, missing, how in decisions:
            mark = '대체' if how == 'replace' else '덧붙임'
            extra = f' (못 옮긴 효과: {", ".join(missing)})' if missing else ''
            print(f'  {mark}: {k[:4]} {ids}{extra}')
        data['scripts'] = merged
        print(f'기존 {len(existing)}개 → {len(merged)}개')
        if write:
            with open(TARGET, 'w', encoding='utf-8') as fh:
                json.dump(data, fh, ensure_ascii=False, indent=2)
            fh = open(TARGET, 'a')
            fh.write('\n')
            fh.close()
            print(f'{TARGET} 갱신 완료')
        return 0

    add = [e for e in gen['scripts'] if key(e) not in have]

    merged = existing + add  # 원작 순서 유지: 기존 → 신규
    data['scripts'] = merged

    print(f'기존 {len(existing)}개 + 신규 {len(add)}개 = {len(merged)}개')
    dups = {}
    for e in merged:
        dups.setdefault(key(e), []).append(e.get('id'))
    bad = {k: v for k, v in dups.items() if len(v) > 1}
    if bad:
        print(f'⚠ 중복 좌표 {len(bad)}건:')
        for k, v in list(bad.items())[:10]:
            print('   ', k, v)
    else:
        print('중복 좌표 없음')

    if write:
        with open(TARGET, 'w', encoding='utf-8') as fh:
            json.dump(data, fh, ensure_ascii=False, indent=2)
        fh = open(TARGET, 'a')
        fh.write('\n')
        fh.close()
        print(f'{TARGET} 갱신 완료')
    else:
        print('(--write 없이는 저장하지 않는다)')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

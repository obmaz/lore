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


def _collect_kinds(steps, out: set):
    for st in steps:
        out.update(st.keys())
        # 선택지/난수 분기 안의 스텝도 같은 이벤트의 효과다.
        ch = st.get('choice')
        if isinstance(ch, dict):
            for opt in ch.get('options', []):
                _collect_kinds(opt.get('steps', []), out)
        rs = st.get('randomSteps')
        if isinstance(rs, list):
            for branch in rs:
                _collect_kinds(branch, out)


def kinds(entry) -> set:
    """스텝 종류 집합(효과 비교용). 선택지 안쪽까지 센다."""
    out: set = set()
    _collect_kinds(entry.get('steps', []), out)
    return out


def _walk_steps(steps, fn):
    for st in steps:
        fn(st)
        ch = st.get('choice')
        if isinstance(ch, dict):
            for opt in ch.get('options', []):
                _walk_steps(opt.get('steps', []), fn)
        rs = st.get('randomSteps')
        if isinstance(rs, list):
            for branch in rs:
                _walk_steps(branch, fn)


def effect_detail(entry):
    """(플래그 이름 집합, 전투 몬스터 튜플, 전투 제목 유무) 를 모은다.

    종류만 비교하면 "플래그 이름이 다르다" 같은 차이를 놓치므로 이름까지 본다.
    """
    flags: set = set()
    monsters: list = []
    has_title = False

    def fn(st):
        nonlocal has_title
        f = st.get('flag')
        if isinstance(f, str):
            flags.add(f)
        b = st.get('battle')
        if isinstance(b, dict):
            monsters.extend(b.get('monsters', []))
            # `random` 으로 뽑히는 후보도 전투 구성의 일부로 본다.
            rnd = b.get('random')
            if isinstance(rnd, dict):
                monsters.extend(rnd.get('pool', []))
            if b.get('title'):
                has_title = True

    _walk_steps(entry.get('steps', []), fn)
    return flags, tuple(sorted(monsters)), has_title


def require_flags(entry) -> set:
    """`require` 에 쓰인 플래그 이름들(대체 안전성 판단용)."""
    req = entry.get('require') or {}
    out = set()
    for key in ('flag', 'flagNot'):
        v = req.get(key)
        if isinstance(v, str):
            out.add(v)
    for key in ('allFlags', 'notAllFlags'):
        for v in req.get(key, []) or []:
            out.add(v)
    return out


# 진행 상태를 남기는 스텝 종류. 손으로 쓴 `flag` 와 옮긴 쪽 `questStep` 은 원작에서
# 같은 일(예: `inc(party.etc[13])` ↔ "완료 표시 플래그")이므로 종류 비교에서 빼고
# 이름 비교로 정밀하게 판단한다.
MARKER_KINDS = {'flag', 'questStep', 'randomFlag'}


def flag_sites(existing) -> dict:
    """플래그 이름 → 그 플래그를 쓰는(설정/조건) 좌표 키 집합.

    손으로 쓴 "완료 표시" 플래그가 **그 좌표에서만** 쓰이면, 옮긴 쪽이 그 자리를
    원작 조건으로 이미 표현하고 있으므로 대체해도 안전하다고 본다.
    """
    sites: dict[str, set] = {}
    for e in existing:
        if e.get('disabled'):
            continue
        k = key(e)
        names = set(effect_detail(e)[0]) | require_flags(e)
        for n in names:
            sites.setdefault(n, set()).add(k)
    return sites


def hard_missing(existing_entries, gen_items) -> list:
    """확실한 차단 사유(종류·전투 구성·disabled).

    표시자(플래그/퀘스트 단계)는 이름 비교로 따로 판단하므로 종류에서는 뺀다.
    """
    out: list = []
    ex_kinds = set()
    gn_kinds = set()
    ex_monsters: list = []
    gn_monsters: list = []
    for e in existing_entries:
        ex_kinds |= kinds(e)
        ex_monsters.extend(effect_detail(e)[1])
    for e in gen_items:
        gn_kinds |= kinds(e)
        gn_monsters.extend(effect_detail(e)[1])
    out.extend(sorted((ex_kinds - gn_kinds) - MARKER_KINDS))
    if ex_monsters and not set(ex_monsters) <= set(gn_monsters):
        out.append('전투 구성: ' + str(tuple(sorted(ex_monsters))))
    if any(e.get('disabled') for e in gen_items):
        out.append('옮긴 쪽에 disabled 항목 있음')
    return out


def merge_spec(existing, gen, replace_ok: bool = False,
               append_active: bool = False):
    """원작에서 기계적으로 옮긴 스크립트를 반영한다.

    같은 좌표에 손으로 쓴 스크립트가 이미 있으면,
    - 옮긴 쪽이 그 스크립트의 효과 종류를 **모두** 포함하면 대체한다
      (원작 문구 그대로 + 같은 효과).
    - 못 옮긴 효과가 하나라도 있으면 대체하지 않고 뒤에 덧붙인다
      (기존 동작을 잃지 않기 위해).

    인덱스를 직접 지우면 순서가 밀리므로, 먼저 계획을 세운 뒤 목록을
    **한 번만** 훑어서 새 목록을 만든다.
    """
    # 이전에 생성해 넣은 `spec-*` 항목은 먼저 걷어낸다(재실행해도 결과가
    # 같아지도록). 손으로 쓴 스크립트만 기준으로 다시 판단한다.
    existing = [e for e in existing if not str(e.get('id', '')).startswith('spec-')]
    by_key = {}
    for idx, e in enumerate(existing):
        by_key.setdefault(key(e), []).append(idx)

    gen_by_key = {}
    for e in gen:
        gen_by_key.setdefault(key(e), []).append(e)

    # 1차: 플래그 이름 차이를 빼고 판단해 "대체될 좌표"를 먼저 구한다.
    # (두 봉인문처럼 서로 플래그를 주고받는 좌표를 함께 대체할 수 있게)
    sites = flag_sites(existing)
    keys0 = set()
    for k, items in gen_by_key.items():
        have = by_key.get(k, [])
        if have and not hard_missing([existing[i] for i in have], items):
            keys0.add(k)

    plan = {}          # key -> 'replace' | 'append'
    decisions = []
    relaxed_log = []
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
        existing_kinds = set()
        gen_kinds = set()
        ex_flags, ex_monsters, ex_title = set(), (), False
        gn_flags, gn_monsters, _gn_title = set(), (), False
        for idx in have:
            k2, f2, m2, t2 = kinds(existing[idx]), *effect_detail(existing[idx])
            existing_kinds |= k2
            ex_flags |= f2
            ex_monsters = ex_monsters + m2
            ex_title = ex_title or t2
        for e in items:
            gen_kinds |= kinds(e)
            f3, m3, _t3 = effect_detail(e)
            gn_flags |= f3
            gn_monsters = gn_monsters + m3
        ex_monsters = tuple(sorted(ex_monsters))
        gn_monsters = tuple(sorted(gn_monsters))
        # 표시자(플래그/퀘스트 단계/무작위 플래그)는 따로 판단하므로 종류 비교에서는
        # 뺀다(손으로 쓴 `flag` ↔ 옮긴 쪽 `questStep` 은 원작에서 같은 일이다).
        existing_kinds -= MARKER_KINDS
        gen_kinds -= MARKER_KINDS
        missing = sorted(existing_kinds - gen_kinds)
        # 플래그 이름/전투 구성/전투 제목까지 같아야 안전하게 대체할 수 있다.
        # 단, 손으로 쓴 "완료 표시" 플래그가 **대체되는 좌표에서만** 쓰이면
        # 옮긴 쪽이 원작 조건으로 같은 일을 하므로 무시한다.
        relaxed = set()
        for n in sorted(ex_flags - gn_flags):
            if sites.get(n, set()) <= keys0:
                relaxed.add(n)
        if ex_flags - gn_flags - relaxed:
            missing.append('flag 이름: ' +
                           ', '.join(sorted(ex_flags - gn_flags - relaxed)))
        if relaxed:
            relaxed_log.append(f'{k[:4]} 자체 표시 플래그 무시: '
                               + ', '.join(sorted(relaxed)))
        # 전투 제목은 표시용 이름일 뿐이라 대체를 막지 않는다(원작 안내 문구는
        # 옮긴 쪽의 `say` 스텝으로 그대로 남는다). `ex_title` 은 기록용으로만 둔다.
        _ = ex_title
        if ex_monsters and not set(ex_monsters) <= set(gn_monsters):
            missing.append('전투 구성: ' + str(ex_monsters))
        # 진행 조건(`require`)에 쓰인 플래그가 옮긴 쪽에 없으면 대체하지 않는다.
        ex_req: set = set()
        gn_req: set = set()
        for idx in have:
            ex_req |= require_flags(existing[idx])
        for e in items:
            gn_req |= require_flags(e)
        req_relax = {n for n in (ex_req - gn_req) if sites.get(n, set()) <= keys0}
        if ex_req - gn_req - req_relax:
            missing.append('require 플래그: ' +
                           ', '.join(sorted(ex_req - gn_req - req_relax)))
        # 옮긴 쪽에 실행하지 못하는(`disabled`) 항목이 섞여 있으면 대체하지
        # 않는다.  손으로 쓴 스크립트가 하던 일을 못 하게 될 수 있다.
        if any(e.get('disabled') for e in items):
            missing.append('옮긴 쪽에 disabled 항목 있음')
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
            # 손으로 쓴 항목은 **지우지 않고** 꺼 둔 채로 남겨, 다시 병합해도
            # 결과가 같도록 한다(멱등).
            if idx == by_key[k][0]:
                out.extend(gen_by_key[k])
            item = dict(e)
            item['disabled'] = True
            out.append(item)
            continue
        out.append(e)
        if mode == 'append' and idx == by_key[k][-1]:
            # 손으로 쓴 스크립트가 못 옮긴 효과(전투/장비/동료 등)를 갖고 있다.
            # 그 동작을 잃지 않도록 기존 것을 그대로 실행하고, 옮긴 쪽은
            # 원작 문구 보관용으로만 넣어 둔다(실행하지 않는다).
            for item in gen_by_key[k]:
                item = dict(item)
                if not append_active:
                    # 기존 동작을 그대로 두고 문구만 보관한다.
                    item['disabled'] = True
                out.append(item)

    # 새 좌표(기존에 없던 것)는 끝에 덧붙인다.
    for k, items in gen_by_key.items():
        if plan.get(k) == 'new':
            out.extend(items)
    return out, decisions, relaxed_log


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
        append_active = '--append-active' in sys.argv
    merged, decisions, relaxed_log = merge_spec(existing, gen['scripts'],
                                                replace_ok, append_active)
    print('원작 이관 스크립트 병합:')
    for line in relaxed_log:
        print(f'  참고: {line}')
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

#!/usr/bin/env python3
"""원작 `LORESPEC.PAS`(좌표 이벤트)를 포트 스크립트 JSON으로 옮기는 도구.

`on(x,y)`(플레이어가 밟은 칸) 조건의 분기를 스크립트로 만들고, 분기 안의
중첩 `if`(진행 플래그/퀘스트 단계)는 `tool/lore_spec_translate.py`가
**조건별 스크립트 항목**으로 쪼갠다(엔진은 첫 일치 항목만 실행하므로).

사용법:
    python3 tool/export_lore_spec.py --report
    python3 tool/export_lore_spec.py --emit tool/lore_spec_generated.json
"""
from __future__ import annotations

import importlib.util
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'repo_source', 'LORE_1993_src', 'LORESPEC.PAS')


def _load(name: str, path: str):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    argv = sys.argv
    sys.argv = [name]
    spec.loader.exec_module(mod)
    sys.argv = argv
    return mod


T = _load('lore_spec_translate',
          os.path.join(ROOT, 'tool', 'lore_spec_translate.py'))


def read_source() -> list[str]:
    raw = open(SRC, 'rb').read()
    return T.decode(raw).replace('\r\n', '\n').split('\n')


def read_arm(lines: list[str], start: int) -> tuple[list[str], int]:
    """팔 헤더부터 팔이 끝나는 지점까지 모은다(`else` 사슬도 포함)."""
    body: list[str] = []
    pos = start
    depth = 0
    started = False
    while pos < len(lines):
        body.append(lines[pos])
        depth += T.block_delta(lines[pos])
        pos += 1
        if depth > 0:
            started = True
        if started and depth <= 0:
            j = pos
            while j < len(lines) and not lines[j].strip():
                j += 1
            if j < len(lines) and re.match(r'^\s*else\b', lines[j], re.I):
                pos = j
                continue
            break
    return body, pos


def expand_chunks(body: list[str]) -> list[list[str]]:
    """`begin ... end` 로 감싼 덩어리를 풀어 최상위 문장 목록으로 만든다."""
    out: list[list[str]] = []
    for chunk in T.split_statements(body):
        first = chunk[0].strip()
        if re.match(r'^begin\s*$', first, re.I):
            inner = chunk[1:]
            if inner and re.match(r'^end\s*;?\s*$', inner[-1], re.I):
                inner = inner[:-1]
            out.extend(expand_chunks(inner))
        else:
            out.append(chunk)
    return out


def iter_arms(lines: list[str]):
    """(map 번호, 팔 헤더 줄 인덱스, 최상위 문장 목록) 을 차례로 낸다."""
    case_starts = [
        i for i, l in enumerate(lines)
        if re.match(r'^\s*case\s+party\.map\s+of', l, re.I)
    ]
    for ci in case_starts:
        case_indent = len(lines[ci]) - len(lines[ci].lstrip())
        i = ci + 1
        depth = 0
        while i < len(lines):
            raw = lines[i]
            stripped = raw.strip()
            ind = len(raw) - len(raw.lstrip())
            if not stripped:
                i += 1
                continue
            if (depth == 0
                    and re.match(r'^end\s*;?\s*$', stripped, re.I)
                    and ind <= case_indent + 3):
                break
            arm = re.match(r'^(\d+)\s*:\s*(.*)$', stripped) if depth == 0 else None
            if arm:
                map_id = int(arm.group(1))
                body, pos = read_arm(lines, i)
                # 팔 헤더의 `N :` 접두를 떼고 본문만 문장 단위로 쪼갠다.
                body = [re.sub(r'^(\s*)\d+\s*:\s*', r'\1', body[0])] + body[1:]
                yield map_id, i, expand_chunks(body)
                i = pos
                continue
            depth += T.block_delta(raw)
            i += 1


def has_coord_if(chunk: list[str]) -> bool:
    """좌표 조건을 가진 `if` 문인지(팔에 좌표 이벤트가 있는지 판단용)."""
    header = chunk[0].strip()
    if not re.match(r'^(?:else\s+)?if\b', header, re.I):
        return False
    coords, _rest = T.split_coords(T.header_condition(header))
    return bool(coords)


def build_scripts(lines: list[str]):
    scripts = []
    skipped = []
    used_ids: set[str] = set()
    for map_id, start, stmts in iter_arms(lines):
        # 좌표 조건이 붙은 분기가 하나도 없는 팔은 "그 칸에 들어서면 벌어지는
        # 연출" 전체가 한 덩어리다(예: 맵 26 Necromancer 최후). 원작
        # `specialevent` 는 `map[x,y] = 0` 인 칸에서만 불리므로 같은 조건을 건다.
        if not any(has_coord_if(st) for st in stmts):
            ctx = T.Ctx(map_id, None, None)
            ctx.variants = [(T.Req(), [])]
            T.walk_statements(ctx, stmts)
            ctx.finish()
            seq_variants = [
                (r, st) for r, st in ctx.variants
                if any(set(x.keys()) - {'flag'} for x in st)
            ]
            for vi, (req, steps) in enumerate(seq_variants):
                sid = (f'spec-{map_id}-L{start + 1}-seq'
                       if vi == 0 else f'spec-{map_id}-L{start + 1}-seq{vi + 1}')
                entry = {
                    'id': sid,
                    'trigger': 'step',
                    'map': map_id,
                    'once': False,
                    'require': {'tileAtPlayerZero': True},
                    'steps': steps,
                }
                if ctx.notes:
                    entry['note'] = '; '.join(ctx.notes)[:300]
                scripts.append(entry)
            continue

        for i, chunk in enumerate(stmts):
            header = chunk[0].strip()
            if not re.match(r'^(?:else\s+)?if\b', header, re.I):
                continue
            cond, then_body, else_body, j = T.resolve_if(stmts, i)
            # `else if on(x,y) then ...` 는 좌표가 다른 **별개 이벤트**다.
            # 앞 이벤트의 else 로 묶으면 서로 다른 칸의 연출이 섞인다.
            if else_body is not None and i + 1 < len(stmts):
                nxt_header = stmts[i + 1][0].strip()
                if re.match(r'^else\s+if\b', nxt_header, re.I):
                    ncoords, _nrest = T.split_coords(
                        T.header_condition(nxt_header))
                    if ncoords:
                        else_body = None
                        j = i + 1
            coords, rest = T.split_coords(cond)
            if not rest.strip() and not coords:
                continue
            base_req, ok = T.condition_to_req(rest)
            if not ok:
                skipped.append(
                    (map_id, start + 1, f'조건 미지원: {rest.strip()[:60]}'))

            # then 쪽
            ctx = T.Ctx(map_id, None, None)
            ctx.variants = [(base_req.copy(), [])]
            T.walk(ctx, then_body)
            ctx.finish()
            variants = list(ctx.variants)
            notes = list(ctx.notes)
            disabled = ctx.unsupported

            # else 쪽 (조건의 부정)
            if else_body is not None:
                neg = base_req.copy()
                for f in base_req.pos:
                    neg.add_flag(f, False)
                for f in base_req.neg:
                    neg.add_flag(f, True)
                neg.invert_quests()
                ctx2 = T.Ctx(map_id, None, None)
                ctx2.variants = [(neg, [])]
                T.walk(ctx2, else_body)
                ctx2.finish()
                variants.extend(ctx2.variants)
                disabled = disabled or ctx2.unsupported
                notes.extend(n for n in ctx2.notes if n not in notes)

            variants = [
                (r, st) for r, st in variants
                if any(set(x.keys()) - {'flag'} for x in st)
            ]
            if not variants:
                skipped.append(
                    (map_id, start + 1,
                     f'텍스트/효과 없음 (notes={notes[:2]})'))
                continue

            coord_list = coords or [{}]
            for ci, coord in enumerate(coord_list):
                for vi, (req, steps) in enumerate(variants):
                    if len(variants) == 1 and len(coord_list) == 1:
                        sid = f'spec-{map_id}-L{start + 1}'
                    elif len(coord_list) == 1:
                        sid = f'spec-{map_id}-L{start + 1}-{vi + 1}'
                    else:
                        sid = f'spec-{map_id}-L{start + 1}-{ci + 1}-{vi + 1}'
                    # 같은 줄에서 여러 분기가 나오면 id 가 겹치므로 꼬리표를 붙인다.
                    while sid in used_ids:
                        sid += 'x'
                    used_ids.add(sid)
                    entry = {
                        'id': sid,
                        'trigger': 'step',
                        'map': map_id,
                        'once': False,
                        'steps': steps,
                    }
                    if not ok or disabled:
                        # 조건을 충실히 옮기지 못한 분기(`not (...) and ...` 등)는
                        # 실행하면 오작동하므로 원작 문구만 보관하고 끈다.
                        entry['disabled'] = True
                    entry.update(coord)
                    rj = req.to_json() or {}
                    if not coord:
                        # 좌표 조건이 없는 분기는 원작에서 `map[x,y] = 0` 인 칸
                        # 에서만 불린다(모든 칸에서 발동하지 않도록).
                        rj = dict(rj)
                        rj['tileAtPlayerZero'] = True
                    if rj:
                        entry['require'] = rj
                    if notes:
                        entry['note'] = '; '.join(notes)[:300]
                    scripts.append(entry)
    return scripts, skipped


def main() -> int:
    report = '--report' in sys.argv
    emit_path = None
    if '--emit' in sys.argv:
        emit_path = sys.argv[sys.argv.index('--emit') + 1]

    lines = read_source()
    scripts, skipped = build_scripts(lines)

    if report:
        from collections import Counter
        per_map = Counter(s['map'] for s in scripts)
        notes = Counter(
            n for s in scripts for n in s.get('note', '').split('; ') if n
        )
        print(f'생성 스크립트: {len(scripts)}개 (맵 {len(per_map)}개)')
        for m in sorted(per_map):
            print(f'  맵 {m:>2}: {per_map[m]:>3}개')
        print(f'건너뜀: {len(skipped)}개')
        for m, line, why in skipped:
            print(f'  맵 {m:>2} L{line}: {why}')
        print('변환 메모(상위 25):')
        for n, c in notes.most_common(25):
            print(f'  {c:>3}x {n}')
        return 0

    if emit_path:
        out = {
            'version': 1,
            'source': 'LORESPEC.PAS (tool/export_lore_spec.py 자동 생성)',
            'scripts': scripts,
        }
        with open(emit_path, 'w', encoding='utf-8') as fh:
            json.dump(out, fh, ensure_ascii=False, indent=2)
            fh.write('\n')
        print(f'{emit_path} 에 {len(scripts)}개 스크립트를 썼다')
        return 0

    print(__doc__)
    return 1


if __name__ == '__main__':
    raise SystemExit(main())

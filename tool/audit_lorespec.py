#!/usr/bin/env python3
"""원작 LORESPEC.PAS의 좌표 이벤트를 맵별로 뽑아내는 감사(audit) 도구.

`case party.map of` 블록과 `if on(x,y)` (또는 `at(x,y)`) 조건을 추적해
어떤 맵의 어떤 좌표에서 무슨 일이 일어나는지 요약한다.

사용법:
    python3 tool/audit_lorespec.py repo_source/LORE_1993_src/LORESPEC.PAS
    python3 tool/audit_lorespec.py repo_source/LORE_1993_src/LORETALK.PAS
"""
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
]

MAP_CASE = re.compile(r'^\s{0,9}(\d+)\s*:\s*(begin)?\s*$')
ON = re.compile(r'\bon\((\d+)\s*,\s*(\d+)\)|\bat\((\d+)\s*,\s*(\d+)\)')


def decode(raw: bytes) -> str:
    try:
        return raw.decode('johab')
    except Exception:  # noqa: BLE001
        return raw.decode('latin-1')


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    path = sys.argv[1]
    lines = open(path, 'rb').read().split(b'\n')

    current_map = None
    map_start = None
    for idx, raw in enumerate(lines):
        line = decode(raw).rstrip()
        # `case party.map of` 이후의 최상위 "N : begin" 이 맵 블록 시작
        m = MAP_CASE.match(line)
        if m and 'party.map' in decode(b'\n'.join(lines[max(0, idx - 12):idx])):
            current_map = int(m.group(1))
            map_start = idx + 1
            print(f'\n### MAP {current_map} (line {map_start})')
            continue
        if current_map is None:
            continue
        on = ON.search(line)
        if on:
            x = on.group(1) or on.group(3)
            y = on.group(2) or on.group(4)
            # 이 조건 블록의 다음 40줄 안에서 효과를 찾는다
            window = '\n'.join(decode(l) for l in lines[idx:idx + 40])
            found = [e for e in EFFECTS if e in window]
            print(f'  line {idx + 1:5d}  on({x},{y})  -> {", ".join(found) or "-"}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

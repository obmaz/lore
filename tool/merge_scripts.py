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
    return (entry.get('trigger'), entry.get('map'), entry.get('x'), entry.get('y'))


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

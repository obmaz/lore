#!/usr/bin/env python3
"""원작 LORE 1993 소스(LORESUB/LOREMENU/LOREHELP.PAS)의 Johab 한글 문자열 디코더.

DOS 시절 Borland Pascal 소스는 Johab(CP1361) 인코딩으로 한글을 저장했다.
특정 Procedure ~ Procedure 사이 구간의 문자열 리터럴만 뽑아 디코딩한다.

사용법:
    python3 tool/decode_johab.py repo_source/LORE_1993_src/LORESUB.PAS Train_Center Hospital
"""
import re
import sys


def decode(blk: bytes):
    out = []
    for m in re.finditer(rb"'([^'\n]*)'", blk):
        raw = m.group(1)
        try:
            dec = raw.decode('johab')
        except Exception as e:  # noqa: BLE001
            dec = f'<decode error: {e}>'
        out.append(dec)
    return out


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 1
    path = sys.argv[1]
    start_marker = sys.argv[2]
    end_marker = sys.argv[3] if len(sys.argv) > 3 else None
    src = open(path, 'rb').read()

    # INTERFACE 구역의 전방 선언을 건너뛰고 IMPLEMENTATION 본문에서 찾는다.
    body = src.find(b'IMPLEMENTATION')
    search_from = body if body >= 0 else 0

    idx = -1
    for kind in ('Procedure', 'Function'):
        for suffix in (';', '(', ' :'):
            marker = f'{kind} {start_marker}{suffix}'
            idx = src.find(marker.encode(), search_from)
            if idx >= 0:
                break
        if idx >= 0:
            break
    if idx < 0:
        print(f'not found: {start_marker}')
        return 1

    if end_marker:
        end = -1
        for kind in ('Procedure', 'Function'):
            for suffix in (';', '(', ' :'):
                marker = f'{kind} {end_marker}{suffix}'
                end = src.find(marker.encode(), idx + 1)
                if end >= 0:
                    break
            if end >= 0:
                break
    else:
        end = len(src)
    if end < 0:
        end = len(src)

    for line in decode(src[idx:end]):
        print(repr(line))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

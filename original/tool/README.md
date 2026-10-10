# 저장소 도구

이 폴더에는 원본 분석·자료 추출·검증 실행 도구를 둔다. Python 회귀 테스트는
`tests/`에 모으며, Flutter 자료 추출 테스트는 `test/tools/`에 있다.
생성한 감사 문서와 JSON 장부는 `docs/audits/`, 원본 재생 fixture는
`test/fixtures/`에 저장한다. 검증 로그는 `build/logs/`에 둔다.

저장소 루트에서 Python 도구 테스트 전체를 실행한다. `tool`을 발견 시작점으로
사용하면 실행 도구를 가져오는 기존 import와 하위 테스트 발견이 함께 동작한다.

```sh
python -X utf8 -m unittest discover -s tool
```

원본 한글을 확인할 때는 이름을 명확히 한 디코더를 사용한다.

```sh
python -X utf8 tool/decode_johab.py repo_source/LORE_1993_src/LORESUB.PAS Train_Center Hospital
```

자료를 실제로 다시 쓰는 `export_*`, `merge_scripts.py`,
`fix_invented_text.py`는 실행 전에 각 도구의 출력 위치와 옵션을 확인한다.
감사 문서의 확인 명령은 [문서 안내](../docs/README.md)를 따른다.

`export_load_facing.py --check`는 원본 `Load`의 지도 분류·중간 높이
경계를 추출한 방향 fixture를 검사한다. 실제 EXE 실행 근거와 구분한다.

`verify_web_browser.py`는 Playwright/Chromium으로 웹 릴리스의 원본 인물
레코드 불러오기, 이동·실제 저장, 새로고침·재개 후 다음 이동을 검사한다.
모바일 세로·가로·데스크톱에서 일행·현재 지도 스냅샷, 페이지 오류와 가로
넘침을 검사하고 `build/verification/browser/`에 보고서·스크린샷을 남긴다.
새 게임→엔딩 연속 재생이나 원본 BGI 픽셀 동등성 검사는 아니다.

```sh
python3 -m playwright install chromium
mkdir -p build/browser_server
ln -s ../web build/browser_server/lore
python3 -m http.server 8765 --bind 127.0.0.1 --directory build/browser_server
# 다른 터미널에서 실행한다.
python3 tool/verify_web_browser.py
```

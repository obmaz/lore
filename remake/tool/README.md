# 저장소 도구

이 폴더에는 원본 분석·자료 추출·검증 실행 도구를 둔다. Python 회귀 테스트는
`tests/`에 모으며, Flutter 자료 추출 테스트는 `test/tools/`에 있다.
생성한 감사 문서와 JSON 장부는 `docs/audits/`, 원본 재생 fixture는
`test/fixtures/`에 저장한다. 검증 로그는 `build/logs/`에 둔다.

저장소 루트에서 Python 도구 테스트 전체를 실행한다. `tool`을 발견 시작점으로
사용하면 실행 도구를 가져오는 기존 import와 하위 테스트 발견이 함께 동작한다.

```sh
python3 -m pip install unicorn==2.1.4
python -X utf8 -m unittest discover -s tool
```

`unicorn`은 원본 EXE의 x86-16 명령을 실행하는 재현 검사에 필요하다.
게임의 웹 릴리스에 포함되는 런타임 의존성은 아니다.

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
모바일 세로 390×844, 768×1024, 360×780, 320×480과 가로 844×390,
정사각형 600×600, 긴 세로 360×900, 넓은 1280×900에서 진입·일행·현재 지도
스냅샷, 페이지 오류와 가로 넘침을 검사하고 `build/verification/browser/`에
보고서·스크린샷을 남긴다. 가로 회전 후에도 바로 조작할 수 있고, 게임 화면이
세로:가로 4:3~19.5:9 범위로 현재 기기에 맞춰 표시되는지 확인한다.
새 게임→엔딩 연속 재생이나 원본 BGI 픽셀 동등성 검사는 아니다.

```sh
python3 -m playwright install chromium
mkdir -p build/browser_server
ln -s ../web build/browser_server/lore
python3 -m http.server 8765 --bind 127.0.0.1 --directory build/browser_server
# 다른 터미널에서 실행한다.
python3 tool/verify_web_browser.py
```

`extract_mobile_ui.py`는 승인된 생성형 시안에서 글자·샘플 수치를 제외한
삽화·아이콘·초상화 PNG 30개를 `assets/images/ui/`로 재현한다(Pillow 필요).
원본 시안은 덮어쓰지 않는다. `capture_mobile_ui.py`는 별도의 Chromium
컨텍스트와 원작 재현 fixture로 실제 웹 UI의 여덟 화면, 양 끝 비율과 기기별 맞춤 화면을
촬영한다. 게임에 디버그 경로를 추가하거나 사용자의 실제 저장을 변경하지 않는다.
스핑크스 전투 촬영은 기존 원작 분기를 여는 격리된 미리보기 지도 셀을 사용하며,
원작 전체 캠페인 재생 근거로 사용하지 않는다.

```sh
python3 tool/extract_mobile_ui.py
python3 tool/capture_mobile_ui.py --url http://127.0.0.1:8785/lore/
```

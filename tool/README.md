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

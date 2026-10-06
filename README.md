# 또 다른 지식의 성전 (LORE 1993)

1993년 DOS 게임 **또 다른 지식의 성전**을 Flutter로 이식한 프로젝트입니다. 원본 Pascal 소스와 실행 데이터는 `repo_source/LORE_1993_src/`, `repo_source/LORE_1993_runtime/`에 있습니다. 게임 동작의 대조 내용과 알려진 편차는 [게임 명세서](docs/game_specs.md)에 기록했습니다.

현재 방향은 **원본 게임 로직을 보존하고 맵 표현·UI·음악을 현대화**하는 것입니다.
원본 분기·비트·배열 계산은 Dart로 직접 옮기며, JSON 게임 팩 전환은 목표에서 제외했습니다.
작업 순서·표현과 로직의 경계·최종 완료 판정은 유일한 계획 문서인 [직접 이식 전략](docs/porting/direct_port_strategy.md)을 따릅니다.
원본의 실행 순서·절차 간 호출·상태 수명주기는 [실행 모델](docs/source/execution_model.md), [절차 추적](docs/source/procedure_traces.md), [상태 수명주기](docs/source/state_lifecycle.md)에 기록했습니다. 이 자료는 소스 분석 근거이며 별도 실행 계획이 아닙니다.
원본 범위와 남은 검증 항목은 [원본 계약 기준선](docs/audits/contract_ledger.md)에서 확인할 수 있습니다.
이전 방식의 기준 버전은 태그 `pre-direct-port-2026-10-02` (`7ff0e89`)로 보존했습니다.

## 폴더 안내

| 위치 | 내용 |
| --- | --- |
| `lib/` | Flutter 게임 구현 |
| `assets/` | 실행에 사용하는 게임 자료 |
| [docs/](docs/README.md) | 이식 전략·원본 분석·감사·검증 문서 |
| `repo_source/` | 원본 게임 소스와 실행 자료 |
| `test/` | Flutter 테스트와 원본 재생 fixture |
| [tool/](tool/README.md) | 분석·추출 도구와 `tool/tests/`의 Python 테스트 |
| `build/` | 생성물과 `build/logs/`의 검증 로그 |
| 플랫폼 폴더 | Android·iOS·웹·데스크톱 실행 설정 |

## 실행

Flutter SDK가 설치된 환경에서:

```sh
flutter pub get
flutter run -d chrome
```

데스크톱·모바일 등 다른 Flutter 기기도 `flutter devices`로 확인한 뒤 `flutter run -d <기기>`로 실행할 수 있습니다.

## 검증

```sh
flutter analyze
flutter test
flutter build web --release
python3 tool/audit_lorespec.py repo_source/LORE_1993_src/LORESPEC.PAS --coverage
python3 tool/audit_messages.py
python3 tool/audit_source_memory.py --check
python3 tool/source_map25_guardian.py --check
python3 tool/source_map26_final.py --check
python3 tool/source_map23_keep3.py --check
python3 tool/build_port_contract_ledger.py --check
```

Windows에서 Python 도구의 이전 UTF-8 자료를 읽을 때는 `python -X utf8`을
사용합니다. 도구 회귀 검사는 `python -X utf8 -m unittest discover -s tool`로 실행합니다.

숫자 호환성은 `dart run tool/verify_source_memory.dart`로 확인합니다. 웹의
JavaScript 연산도 확인하려면 아래처럼 같은 검증기를 컴파일해 실행합니다.

```sh
dart compile js -O2 tool/verify_source_memory.dart -o build/source-memory-verification.js
node build/source-memory-verification.js
```

원본에서 추출한 지도·폰트·대사·전투 데이터를 `assets/`에 포함했습니다. 추출 및 병합 도구는 `tool/`에 있으며, 게임 실행과 테스트에는 별도의 DOS 런타임이 필요하지 않습니다.

## 정적 웹 페이지 배포

GitHub Actions 빌드는 사용하지 않습니다. 로컬에서 다음 명령으로 WASM과
JavaScript 대체 버전을 함께 빌드합니다.

```sh
flutter build web --release --wasm --base-href /lore/ --no-web-resources-cdn
```

`build/web/`의 배포 파일을 `main` 브랜치의 `docs/`에 복사합니다. 기존 문서
디렉터리는 보존하고, 배포 파일은 같은 이름의 파일만 갱신합니다. `docs/.nojekyll`
파일도 둡니다. GitHub Pages의 배포 소스는 `main` 브랜치의 `/docs`입니다. Flutter 진입 파일 `main.dart.wasm`과 렌더러의 `.wasm`
파일을 브라우저가 정상 로드하려면 정적 서버가 `.wasm`을
`application/wasm`으로 제공해야 합니다. WASM GC 미지원 브라우저에는
같은 빌드의 `main.dart.js`가 사용됩니다.

GitHub Pages는 저장소가 비공개여도 게시된 사이트 자체는 공개됩니다.

이 프로젝트는 [smgal/LoreTrilogy_1993](https://github.com/smgal/LoreTrilogy_1993)의 원본 소스를 참고하여 AI를 활용해 포팅하고 있습니다.

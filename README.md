# 또 다른 지식의 성전 (LORE 1993)

1993년 DOS 게임 **또 다른 지식의 성전**을 Flutter로 이식하는 프로젝트입니다. 원본 Pascal 소스와 실행 자료를 바탕으로 게임 로직을 Dart로 직접 옮기고 있습니다.

## 이식 방향과 문서

**원본과 동일한 게임 동작을 먼저 구현한 뒤 현대화**하는 것을 목표로 합니다. 원본의 분기·비트·배열 계산과 실행 순서를 보존하며, 맵 표현·UI·입력·음악은 현재 환경에 맞게 구현합니다.

- [직접 이식 전략](docs/porting/direct_port_strategy.md): 작업 순서와 최종 완료 기준
- [게임 명세서](docs/game_specs.md): 원본과의 대조 내용 및 알려진 편차
- [원본 계약 기준선](docs/audits/contract_ledger.md): 이식 범위와 남은 검증 항목
- 원본 분석: [실행 모델](docs/source/execution_model.md) · [절차 추적](docs/source/procedure_traces.md) · [상태 수명주기](docs/source/state_lifecycle.md)
- [개발 이력](COMMIT_HISTORY.txt): 저장소 재생성 전의 작업 날짜와 커밋 메시지

## 폴더 안내

| 위치 | 내용 |
| --- | --- |
| [lib/](lib/) | Flutter 게임 구현 |
| [assets/](assets/) | 실행에 사용하는 게임 자료 |
| [docs/](docs/README.md) | 이식 전략·원본 분석·감사·검증 문서 |
| [repo_source/](repo_source/) | 원본 Pascal 소스와 DOS 실행 자료 |
| [test/](test/) | Flutter 테스트와 원본 동작 재현 자료 |
| [tool/](tool/README.md) | 분석·추출 도구와 Python 테스트 |
| build/ | 로컬 빌드 생성물과 검증 로그 |
| 플랫폼 폴더 | Android·iOS·웹·데스크톱 실행 설정 |

원본에서 추출한 지도·폰트·대사·전투 데이터는 assets 폴더에 포함되어 있습니다. 게임 실행과 Flutter 테스트에는 별도의 DOS 런타임이 필요하지 않습니다.

## 실행

Flutter SDK가 설치된 환경에서 다음 명령으로 웹 버전을 실행합니다.

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

## 정적 웹 페이지 배포

로컬에서 WASM과 JavaScript 대체 버전을 함께 빌드한 뒤 GitHub Pages에 게시합니다.

```sh
flutter build web --release --wasm --base-href /lore/ --no-web-resources-cdn
```

1. `build/web/`의 배포 파일을 `docs/`에 복사합니다. 기존 문서 디렉터리는 보존하고, 같은 이름의 배포 파일만 갱신합니다.
2. `docs/.nojekyll` 파일을 포함해 `main`에 커밋하고 푸시합니다.
3. GitHub의 **Settings → Pages**에서 **Deploy from a branch**, 브랜치 **main**, 폴더 **/docs**를 선택하고 저장합니다.

정적 서버는 `.wasm` 파일을 `application/wasm` 형식으로 제공해야 합니다. WASM GC를 지원하지 않는 브라우저에는 같은 빌드의 `main.dart.js`가 사용됩니다.

## 원본 출처

이 프로젝트는 [smgal/LoreTrilogy_1993](https://github.com/smgal/LoreTrilogy_1993)의 원본 소스를 참고하여 AI를 활용해 포팅하고 있습니다.

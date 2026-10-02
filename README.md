# 또 다른 지식의 성전 (LORE 1993)

1993년 DOS 게임 **또 다른 지식의 성전**을 Flutter로 이식한 프로젝트입니다. 원본 Pascal 소스와 실행 데이터는 `repo_source/LORE_1993_src/`, `repo_source/LORE_1993_runtime/`에 있습니다. 게임 동작의 대조 내용과 알려진 편차는 [게임 명세서](DOCS_GAME_SPECS.md)에 기록했습니다.

현재 방향은 **원본 게임 로직을 보존하고 맵 표현·UI·음악을 현대화**하는 것입니다.
원본 분기·비트·배열 계산은 Dart로 직접 옮기며, JSON 게임 팩 전환은 목표에서 제외했습니다.
작업 순서·표현과 로직의 경계·최종 완료 판정은 유일한 계획 문서인 [직접 이식 전략](PORT_DIRECT_PORT_STRATEGY.md)을 따릅니다.
원본 범위와 남은 검증 항목은 [원본 계약 기준선](PORT_CONTRACT_LEDGER.md)에서 확인할 수 있습니다.
이전 방식의 기준 버전은 태그 `pre-direct-port-2026-10-02` (`7ff0e89`)로 보존했습니다.

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

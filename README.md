# 또 다른 지식의 성전 (LORE 1993)

1993년 DOS 게임 **또 다른 지식의 성전**을 Flutter로 이식한 프로젝트입니다. 원본 Pascal 소스와 실행 데이터는 `repo_source/LORE_1993_src/`, `repo_source/LORE_1993_runtime/`에 있습니다. 게임 동작의 대조 내용과 알려진 편차는 [게임 명세서](DOCS_GAME_SPECS.md)에 기록했습니다.

원본의 입력·전역 상태·지도 전환·전투·저장 실행 순서는 [원본 실행 모델](ORIGINAL_LORE_EXECUTION_MODEL.md)에 소스 근거와 함께 정리했습니다.
대화가 타일을 만들고 전투가 후속 사건을 여는 경로는 [원본 절차 추적](ORIGINAL_LORE_PROCEDURE_TRACES.md)에 기록했습니다.
완전 이식의 검증 기준과 게임 엔진으로 확장하기 위한 경계는 [엔진 구조](ENGINE_ARCHITECTURE.md)에 정리했습니다.
단계별 작업과 최종 완료 판정은 [완전 이식 마스터 플랜](PORT_MASTER_PLAN.md)을 따릅니다.
원본 범위와 남은 검증 항목은 [원본 계약 기준선](PORT_CONTRACT_LEDGER.md)에서 확인할 수 있습니다.

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
```

원본에서 추출한 지도·폰트·대사·전투 데이터를 `assets/`에 포함했습니다. 추출 및 병합 도구는 `tool/`에 있으며, 게임 실행과 테스트에는 별도의 DOS 런타임이 필요하지 않습니다.

## 정적 웹 페이지 배포

GitHub Actions 빌드는 사용하지 않습니다. 로컬에서 다음 명령으로 WASM과
JavaScript 대체 버전을 함께 빌드합니다.

```sh
flutter build web --release --wasm --base-href /lore/ --no-web-resources-cdn
```

`build/web/` 전체를 `gh-pages` 브랜치의 루트에 게시합니다. 이 브랜치에는
`.nojekyll` 파일도 둡니다. GitHub Pages의 배포 소스는 `gh-pages` 브랜치의
`/(root)`입니다. Flutter 진입 파일 `main.dart.wasm`과 렌더러의 `.wasm`
파일을 브라우저가 정상 로드하려면 정적 서버가 `.wasm`을
`application/wasm`으로 제공해야 합니다. WASM GC 미지원 브라우저에는
같은 빌드의 `main.dart.js`가 사용됩니다.

GitHub Pages는 저장소가 비공개여도 게시된 사이트 자체는 공개됩니다.

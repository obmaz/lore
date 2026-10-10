# LORE Original · 원본 이식판

1993년 DOS 게임 **또 다른 지식의 성전**의 동작을 Flutter / Dart로 재현하는
독립 프로젝트입니다. 원본 Pascal 소스와 DOS 실행 자료를 자체 폴더에 포함합니다.
작업 위치는 `original/`이며 `main` 브랜치에서 관리합니다. 이 문서의 명령과
상대 경로는 모두 이 프로젝트 폴더를 기준으로 합니다.

웹 실행: https://obmaz.github.io/lore/original/

다른 루트 프로젝트의 코드·자산·자료를 참조하지 않습니다. 폴더 하나만 복사한
환경에서도 Flutter SDK와 패키지를 설치해 실행·검증할 수 있습니다.

## 모바일 화면과 기존 디자인 자료

제품의 지원 대상은 터치 조작을 사용하는 모바일 세로 화면입니다. 데스크톱과
가로 화면은 지원 대상에 포함하지 않습니다. 저장소의 웹·데스크톱 실행 설정은
개발·검증용으로 남아 있으며, 제품의 지원 플랫폼을 뜻하지 않습니다.

이 폴더에는 원본 이식판의 기존 화면과 터치·키보드 입력 어댑터가 있습니다.
아래 생성형 UI 시안은 과거 디자인 검토 자료입니다. 시안에 사용한
세로:가로 4:3부터 19.5:9까지의 배치나 새로운 전투·팝업 디자인이
이 프로젝트에 모두 구현되어 있다는 뜻은 아닙니다. 실제 구현 범위는
게임 코드와 검증 문서를 기준으로 확인합니다.

| 화면 | 생성형 UI 시안 |
| --- | --- |
| 시작 | [시작 화면](docs/design/mobile-ui/01-start.png) |
| 동료 선택 | [동료 선택 화면](docs/design/mobile-ui/02-creation.png) |
| 탐험 | [탐험 화면](docs/design/mobile-ui/03-exploration.png) |
| 대화 | [대화 화면](docs/design/mobile-ui/04-dialogue.png) |
| 전투 | [전투 화면](docs/design/mobile-ui/05-battle.png) |
| 일행·장비 | [일행 화면](docs/design/mobile-ui/06-party.png) |
| 저장·불러오기 | [저장 화면](docs/design/mobile-ui/07-save.png) |
| 앱 설정 | [설정 화면](docs/design/mobile-ui/08-settings.png) |
| 지원 비율 양끝의 배치 | [4:3 / 19.5:9 비교 시안](docs/design/mobile-ui/09-aspect-ratios.png) |

## 이식 방향과 문서

**원본과 동일한 게임 동작을 먼저 구현한 뒤 현대화**하는 것을 목표로 합니다. 원본의 분기·비트·배열 계산과 실행 순서를 보존하며, 맵 표현·UI·입력·음악은 현재 환경에 맞게 구현합니다.

### 이식할 때의 기준

- **원본 소스와 실제 실행을 기준으로 삼습니다.** Pascal의 절차를 Dart로 직접 옮기며, 조건 분기·조기 종료·절차 간 호출을 보존합니다. 설명이나 기존 이식 코드만으로 동작을 추정하지 않고 원본 DOS 실행 결과와 대조합니다.
- **계산의 경계까지 재현합니다.** 바이트 값, 16비트·32비트 정수, 부호, 중간 계산과 대입 시의 값 범위를 구분합니다. 일반적인 수치에서 결과가 같아도 경계에서 달라지면 수정 대상으로 봅니다. 이는 원본의 계산을 재현하는 것으로, 앱 저장 파일을 DOS 바이너리 형식으로 바꾼다는 뜻은 아닙니다.
- **결과뿐 아니라 진행 순서도 보존합니다.** 난수 호출, 지도 변경, 상태 갱신, 대사·선택지와 키 입력 대기, 전투 이후의 재개 순서를 맞춥니다. 지도 좌표와 배열의 빈 슬롯, 원본 상태 바이트도 유지합니다.
- **게임 규칙과 화면 구현을 구분합니다.** 원본 대사·선택지·색상과 게임 의미를 기준으로 하면서 지도 렌더링, 모바일 배치, 터치·키보드 입력, 오디오 재생과 파일 접근은 현대 플랫폼에 맞게 구현합니다. 밸런스 조정이나 수치 범위 확대는 원본 동등성 검증 이후의 별도 작업으로 둡니다.
- **이식한 로직의 실행 경로를 하나로 유지합니다.** 실행용 JSON 이벤트 규칙과 이전 로직의 대체 실행을 제거하고, 직접 이식한 절차가 해당 이벤트를 담당하게 합니다. JSON은 자원과 앱 저장 데이터의 표현에 사용할 수 있습니다.
- **확인한 범위와 남은 차이를 기록합니다.** 원본에서 추출한 자료, 동작 재현 테스트, DOS 실행 대조와 웹 검증을 함께 사용합니다. 테스트 통과만으로 전체 이식 완료를 선언하지 않으며, 확인되지 않은 컴파일러 동작과 의도적인 플랫폼 차이는 문서에 남깁니다.

### 관련 문서

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

## 현재 구현의 모바일 화면 높이

터치 기반 모바일 브라우저에서는 진입 시점의 `window.innerHeight`를 앱 최상위 컨테이너 높이로 고정합니다(App Height Lock). 주소창이 숨거나 나타나거나 화면 키보드가 열려 높이만 바뀌어도 게임 레이아웃을 다시 배치하지 않습니다. 화면 회전이나 창 너비 변경 시 높이를 갱신합니다.

웹에서는 메뉴·상태·초감각이 있는 명령 줄의 맨 오른쪽 **전체화면 전환** 아이콘으로 브라우저 전체화면에 진입하거나 종료할 수 있습니다. 전환할 때 앱의 고정 높이도 새 화면 크기에 맞춥니다. 브라우저의 사용자 입력 정책 때문에 버튼을 직접 눌러야 하며, 미지원 브라우저에서는 홈 화면에 추가해 실행하는 방법을 안내합니다. 이 버튼은 화면 표시만 바꾸고 게임 턴이나 원작 메뉴 선택을 진행시키지 않습니다.

## 그래픽 스킨

게임 화면의 전체화면 버튼 옆 **앱 설정**(슬라이더 아이콘)에서 **그래픽 스킨**을
선택할 수 있습니다. 기본은 원작 그래픽이며, **크리스털 판타지**는 새로 생성한
판타지 PNG 타일과 투명 캐릭터 시트로 지도·주인공·주민을 바꿉니다.
밝고 차분한 바닥, 짙은 벽, 큼직한 실루엣의 아기자기한 인물로 작은 화면에서도
길과 장애물을 구분합니다. 물은 청록색, 늪은 올리브색 갈대, 용암은 주황색 흐름으로
표시하고, 계단·문·표지판은 원작 타일의 역할에 맞는 모양을 사용합니다.
선택은 바로 적용되고 다음 실행에도 유지됩니다. 앱 설정을 닫으면 게임 키보드
입력이 돌아옵니다. 설정 창이 열린 동안의 이동·게임 단축키는 진행되지 않습니다.

스킨은 표시 전용입니다. 원작 지도 바이트·타일 판정·좌표·퀘스트·난수·게임 저장
형식을 바꾸지 않으며, 던전의 어둠과 투시도 원작 조건을 따릅니다. 현재 전투 화면과
대사·상태 패널은 기존 표현을 유지하고, 엔딩의 합성용 조각은 원작 PNG를 재사용합니다.

개발자가 새 스킨을 추가할 때는 `GraphicsSkin`에 등록하고 해당 PNG와 매니페스트를
`pubspec.yaml`의 에셋 목록에 포함합니다. 원작 PNG는 `assets/images/manifest.json`,
새 스킨은 `assets/images/skins/crystal/manifest.json`에 정의됩니다.
매니페스트 v2의 `fonts`는 원작의 `CHARA/TOWN/GROUND/DEN/KEEP`와 각 56개 슬롯을
유지하며, `tiles` 배열로 원작 슬롯을 PNG 아틀라스 셀에 대응시킵니다. `columns`와
`tileSize`가 PNG 배치를 지정합니다. `tileSize`는 소수도 지원하며 생성 이미지의
원본 크기를 그대로 사용할 수 있습니다. `-1`은 해당 슬롯의 원작 PNG를 유지합니다.
`overlayAtlas`와 `overlays`는 주민처럼 바닥 위에 투명 캐릭터를 겹치는 표시용 자료입니다.
스킨 파일이 잘못되면 변경을 적용하지 않고 현재 스킨을 유지합니다.

미리보기는 실제 렌더러로 생성합니다.

```sh
flutter test test/tools/export_skin_previews_test.dart --dart-define=EXPORT_SKIN_PREVIEWS=true
```

결과는 `build/skin-previews/`에 저장됩니다. 앱 설정에 쓰는 미리보기는 그 결과의
`original-town.png`와 `crystal-town.png`를 각각
`assets/images/skins/original-preview.png`와 `assets/images/skins/crystal/preview.png`에
복사합니다. 표시 설정은 `lore_graphics_skin` 환경설정 키를 쓰며 게임 세이브와 분리됩니다.

## 실행

Flutter SDK가 설치된 환경에서 다음 명령으로 웹 버전을 실행합니다.

```sh
flutter pub get
flutter run -d chrome
```

모바일 기기는 `flutter devices`로 확인한 뒤 `flutter run -d <기기>`로 실행합니다.
위 Chrome 명령은 개발용이며, 제품 UI는 모바일 세로 뷰포트에서 확인합니다.

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
python3 tool/build_web_release.py
```

빌드 도구는 로더에 기록된 모든 WASM 해시를 실제 파일과 대조한 뒤 기존 문서를 보존하며 `docs/`를 갱신합니다. 이전 빌드의 해시가 남아 있으면 한 번 재빌드하여 검사합니다. SDK 경로를 지정하려면 `--flutter /경로/flutter/bin/flutter`을 사용합니다.

소스와 이 프로젝트의 `docs/` 결과물을 `main`에 커밋·푸시하면 GitHub Actions가
`/lore/original/`에 게시합니다. 저장소의 Pages Source는 `GitHub Actions`입니다.
배포 단계에서 base path를 `/lore/original/`로 조정하며, 각 프로젝트의
커밋된 빌드 결과물을 게시합니다. Actions 자체에서는 Flutter 빌드를 실행하지 않습니다.

정적 서버는 `.wasm` 파일을 `application/wasm` 형식으로 제공해야 합니다. WASM GC를 지원하지 않는 브라우저에는 같은 빌드의 `main.dart.js`가 사용됩니다.

## 원본 출처

이 프로젝트는 [smgal/LoreTrilogy_1993](https://github.com/smgal/LoreTrilogy_1993)의 원본 소스를 참고하여 AI를 활용해 포팅하고 있습니다.

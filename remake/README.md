# LORE Remake · 모바일 리메이크

**또 다른 지식의 성전**을 바탕으로 모바일 화면·조작·전투·대화를 현대화하는 Flutter 게임입니다.
자체 Pascal 소스·DOS 자료·자산·검증 도구를 포함한 독립 프로젝트입니다.
다른 프로젝트의 파일을 읽거나 함께 갱신하지 않습니다.

웹 실행: [모바일 리메이크](https://obmaz.github.io/lore/remake/)

## 화면과 조작

게임 영역의 세로:가로 비율을 **4:3~19.5:9**로 유지하며 기기 안에 들어가는 최대 크기로 표시합니다.
가로나 짧은 화면에서는 좌우, 매우 긴 화면에서는 위아래 여백을 둡니다. 기기 비율로 진입을 차단하지 않습니다.

- 생성: 이름·성향·능력치·직업·동료의 5단계 터치 화면.
- 탐험: 정사각형 지도, 하단 오른쪽 키패드, 왼쪽 메뉴·일행, PNG 인물·장비 삽화.
- 대화: 같은 하단 창에서 계속 읽기, 선택 카드, 실제 임무 경계에서 종료.
- 전투: 좌우 JRPG 무대, 명령 준비·자동공격·도주, 1×/2×/4× 연출과 보상 화면.
- 표시 설정: 원작/크리스털 판타지 지도 스킨, 전체화면, 모바일 웹 화면 높이 유지.

화면·스킨·시안/실제 구현 이미지와 자산 규약은 [모바일 UI](docs/mobile_ui.md),
대화 노드와 후속 효과는 [대화 흐름](docs/porting/dialogue_flow.md)에 있습니다.
표시·입력 현대화와 원작 재생 어댑터는 각각 검증하며 수식·저장·난수는 원작 기준을 유지합니다.

## 실행

이 문서의 모든 상대 경로와 명령은 `remake/` 폴더 기준입니다. Flutter SDK를 설치한 뒤 실행합니다.

```sh
flutter pub get
flutter run -d chrome
```

기기는 `flutter devices`로 확인한 뒤 `flutter run -d <기기>`로 실행합니다.
Chrome 개발 화면에서도 모바일 터치 배치를 확인합니다. 게임 실행에 Python이나 DOS 런타임은 필요하지 않습니다.

## 구조와 개발

| 위치 | 내용 |
| --- | --- |
| `lib/`, `assets/` | 게임 코드·실행 자료 |
| [docs/](docs/README.md) | 개발 기준·원작 규칙·실행 분석·검증 근거 |
| [repo_source/](repo_source/README.md) | 자체 보존 원본 소스·DOS 실행 자료 |
| [story_material/](story_material/README.md) | 선택적으로 생성하는 원문 추출 자료 |
| `test/`, [tool/](tool/README.md) | Flutter 재생 검사·분석/추출 도구 |
| 플랫폼 폴더 | Android·iOS·웹·데스크톱 개발 설정 |

작업 제약은 [AGENTS.md](AGENTS.md), 목표·완료 기준은
[개발 기준](docs/porting/direct_port_strategy.md), 검증 명령은 [문서 안내](docs/README.md)를 따릅니다.

음악의 확인 근거와 미확정 출처는 [음악 출처 기록](docs/source/music_sources.md)에 있습니다.

## 웹 빌드와 게시

```sh
python -X utf8 tool/build_web_release.py
```

도구가 WASM과 JavaScript 대체 버전을 빌드하고 로더의 WASM 해시를 검사해
문서를 보존하며 이 프로젝트의 `docs/`를 갱신합니다. SDK 경로는
`--flutter /경로/flutter/bin/flutter`로 지정합니다.
저장소의 `main`에 소스를 커밋·푸시하면 GitHub Actions의 Validate가
Flutter 3.47.5로 분석·테스트·웹 빌드·WASM 해시 검증을 실행합니다.
성공 후 Deploy Pages를 `main`에서 수동 실행하면 같은 커밋의 검증된
`build/web/` 아티팩트를 `/lore/remake/`에 게시합니다.
푸시만으로 배포하지 않으며 빌드 결과를 커밋할 필요가 없습니다.
아티팩트는 14일간 보관하므로 만료되면 Validate를 다시 실행합니다.
위 로컬 빌드 명령은 미리보기·독립 호스팅용으로 계속 사용할 수 있습니다.
독립 호스팅 시 base path를 맞추고 `.wasm`을 `application/wasm`으로 제공합니다.

## 출처

보존 자료의 출처는 [smgal/LoreTrilogy_1993](https://github.com/smgal/LoreTrilogy_1993)입니다.
원본과의 차이·미검증 범위는 이 프로젝트의 검증 근거에서 관리합니다.

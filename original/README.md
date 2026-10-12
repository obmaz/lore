# LORE Original · 원본 이식판

1993년 DOS RPG **또 다른 지식의 성전**의 게임 동작을 Flutter / Dart로 재현합니다.
자체 Pascal 소스·DOS 자료·자산·검증 도구를 포함한 독립 프로젝트입니다.
다른 프로젝트의 파일을 읽거나 함께 갱신하지 않습니다.

웹 실행: [원본 이식판](https://obmaz.github.io/lore/original/)

## 화면과 조작

터치 조작을 사용하는 모바일 세로 화면을 기준으로 합니다. 원작 그래픽을 고정 사용하며
앱 설정·그래픽 스킨 전환은 제공하지 않습니다. 지도 PNG를 읽지 못하면 FNT 렌더링으로 돌아갑니다.
전체화면·게임 메뉴·오디오와 기존 터치/키보드 입력을 사용합니다.

모바일 웹은 진입 시 높이를 고정하고 회전·너비 변경·전체화면 전환 때 갱신합니다.
전체화면 버튼은 명령 줄 오른쪽에 있으며 게임 턴을 소비하지 않습니다.
웹·데스크톱 실행 설정은 개발·검증용이고 제품의 데스크톱·가로 화면 지원을 뜻하지 않습니다.

## 실행

이 문서의 모든 상대 경로와 명령은 `original/` 폴더 기준입니다. Flutter SDK를 설치한 뒤 실행합니다.

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

## 웹 빌드와 게시

```sh
python -X utf8 tool/build_web_release.py
```

도구가 WASM과 JavaScript 대체 버전을 빌드하고 로더의 WASM 해시를 검사해
문서를 보존하며 이 프로젝트의 `docs/`를 갱신합니다. SDK 경로는
`--flutter /경로/flutter/bin/flutter`로 지정합니다.
소스와 결과물을 `main`에 커밋·푸시하면 저장소 Pages가 `/lore/original/`에 게시합니다.
게시 단계는 커밋된 결과물을 복사하며 Flutter 빌드를 실행하지 않습니다.
독립 호스팅 시 base path를 맞추고 `.wasm`을 `application/wasm`으로 제공합니다.

## 출처

보존 자료의 출처는 [smgal/LoreTrilogy_1993](https://github.com/smgal/LoreTrilogy_1993)입니다.
원본과의 차이·미검증 범위는 이 프로젝트의 검증 근거에서 관리합니다.

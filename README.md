# LORE

1993년 DOS RPG **또 다른 지식의 성전**을 바탕으로 한 세 개의 독립 프로젝트입니다.
모든 작업은 `main` 브랜치에서 폴더별로 관리합니다.

별도 언급이 없는 게임 개선은 `remake/`에만 적용합니다. `original/`은
원작 그래픽을 고정 사용하며 앱 설정·그래픽 스킨 전환을 제공하지 않습니다.

## 프로젝트 구조

| 프로젝트 | 용도 | 실행 환경 | 안내 |
| --- | --- | --- | --- |
| `original/` | 원작 동작을 재현하는 이식판 | Flutter / Dart | [원본 README](original/README.md) |
| `remake/` | 모바일 UI·그래픽·전투·대화의 현대화판 | Flutter / Dart | [리메이크 README](remake/README.md) |
| `novel/` | 원문 스냅샷에 기반한 집필·참조 자료 | Python | [소설 README](novel/README.md) |

세 폴더는 서로의 코드·자산·자료를 읽거나 실행하지 않습니다. 필요한 자료와
검증 도구는 각 프로젝트 내부에 있으며, 폴더 하나만 복사해서 사용할 수 있습니다.
프로젝트 사이의 자동 동기화나 공용 런타임은 없습니다. 외부 SDK와 패키지는
각 프로젝트의 의존성 파일에 따라 설치합니다.

## 실행과 작업 위치

게임은 선택한 프로젝트 폴더에서 실행합니다. 아래 명령의 `remake`를
`original`로 바꾸면 원본 이식판을 실행할 수 있습니다.

```bash
cd remake
flutter pub get
flutter run -d chrome
```

리메이크는 모바일 터치 조작을 기준으로 하며, 게임 영역의 세로:가로 비율을
4:3부터 19.5:9까지 유지하면서 기기 화면에 맞춥니다.
소설 자료는 `novel/` 안에서 Python으로 검증하며 Flutter가 필요하지 않습니다.
각 프로젝트의 상세 실행·검증 명령은 해당 README를 참고하세요.

## 웹 주소와 배포

- 원본: https://obmaz.github.io/lore/original/
- 리메이크: https://obmaz.github.io/lore/remake/

게임을 수정한 뒤 해당 프로젝트 안에서 웹 빌드를 갱신합니다.

```bash
cd remake
python3 tool/build_web_release.py
```

빌드 도구는 WASM과 JavaScript 대체 버전을 만들고 무결성을 검사한 뒤
프로젝트 내부 `docs/`에 복사합니다. 원본은 `original/`에서 같은 명령을 사용합니다.
SDK 경로가 필요한 경우 `--flutter /경로/flutter/bin/flutter`을 지정합니다.

변경된 소스와 `docs/` 결과물을 `main`에 커밋·푸시하면
[Pages 워크플로](.github/workflows/deploy-pages.yml)가 각각을 `/original/`,
`/remake/`에 배치합니다. 워크플로는 커밋된 결과물을 게시하며 Flutter 빌드를
실행하지 않습니다. `novel/`은 이 게임 배포에 포함하지 않습니다.
GitHub Settings → Pages의 Source는 `GitHub Actions`입니다.

## 원본 출처

[smgal/LoreTrilogy_1993](https://github.com/smgal/LoreTrilogy_1993)의
Pascal 소스와 DOS 실행 자료를 기준으로 작업합니다. 각 프로젝트의 검증 범위와
알려진 차이는 내부 문서에 기록합니다.

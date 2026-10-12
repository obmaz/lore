# LORE

서로 독립된 세 프로젝트를 `main` 브랜치에서 관리합니다.

| 프로젝트 | 목적 | 시작 문서 |
| --- | --- | --- |
| `original/` | 원작 동작과 그래픽을 재현하는 Flutter 이식판 | [README](original/README.md) |
| `remake/` | 모바일 화면·조작·전투·대화를 현대화하는 Flutter 게임 | [README](remake/README.md) |
| `novel/` | 자체 원문 스냅샷을 사용하는 소설 집필 패키지 | [README](novel/README.md) |

## 독립성 원칙

각 프로젝트는 자신의 코드·자산·자료·도구·의존성만 사용합니다. 다른 프로젝트의
파일을 읽거나 가져오는 실행 경로, 공용 모듈, 자동 수입·동기화를 만들지 않습니다.
각 폴더만 복사한 환경에서도 해당 README에 따라 필요한 SDK·패키지를 설치해 사용합니다.
비슷한 자료가 있어도 각 프로젝트의 보유 자료이며 함께 갱신할 대상으로 취급하지 않습니다.

작업 전 해당 프로젝트의 `AGENTS.md`를 읽습니다. 별도 지정이 없는 게임 변경은
`remake/`에만 적용합니다. 실행·검증·자료 재생성은 각 프로젝트 내부에서 수행합니다.

## 웹 게시 경로

| 프로젝트 | 주소 |
| --- | --- |
| 원본 이식판 | [original](https://obmaz.github.io/lore/original/) |
| 모바일 리메이크 | [remake](https://obmaz.github.io/lore/remake/) |
| 선택형 소설 | [novel](https://obmaz.github.io/lore/novel/) |
| 소설 제작실 · 공개 작가용 | [studio](https://obmaz.github.io/lore/novel/studio/) |

[Pages 워크플로](.github/workflows/deploy-pages.yml)는 커밋된 결과물을 각각의 URL에
게시하는 저장소 운영 설정입니다. 프로젝트의 빌드·자료 재생성을 수행하지 않습니다.
게임은 각자의 `docs/` 빌드를, 소설은 자체 해시 검사를 통과한 독자 읽기본과
별도 제작실 HTML을 게시합니다. 제작실은 사용자가 공개를 허용한 **전편 스포일러 포함
작가용 화면**이며 로그인·접근 제어가 없습니다. 기존 독자 `/novel/` 화면에는 제작실 자료를
추가하지 않습니다. 갱신 방법은 각 README에 있습니다.

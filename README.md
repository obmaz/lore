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

`main` 푸시 시 [Validate](.github/workflows/validate.yml)가 Flutter 3.47.5로 두 게임을
각 폴더에서 독립적으로 분석·테스트·빌드하고 WASM 해시를 검사합니다.
통과한 `build/web/` 결과는 Actions 아티팩트로 14일간 보관합니다.
게임 소스만 커밋·푸시하면 되며, 웹 빌드 결과를 별도로 커밋할 필요가 없습니다.

검증 성공 후 Actions에서 [Deploy Pages](.github/workflows/deploy-pages.yml)를
`main` 브랜치로 수동 실행합니다. 배포는 현재 커밋과 동일한 SHA의 성공한 Validate
결과만 사용하며, 미검증 커밋·실패한 빌드·만료된 아티팩트는 배포하지 않습니다.
아티팩트가 만료되면 Validate를 다시 실행합니다. 푸시만으로 사이트가 바뀌지는 않습니다.
소설은 자료를 재생성하지 않고 자체 해시 검사를 통과한 독자 읽기본과
별도 제작실 HTML을 게시합니다. 제작실은 사용자가 공개를 허용한 **전편 스포일러 포함
작가용 화면**이며 로그인·접근 제어가 없습니다. 기존 독자 `/novel/` 화면에는 제작실 자료를
추가하지 않습니다. 갱신 방법은 각 README에 있습니다.

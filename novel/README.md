# LORE 소설 집필 패키지

원문 스냅샷·인물/설정 사전·집필 원고·분기/연속성 검증 도구를 포함합니다.
이 폴더만 복사해 Python과 `requirements.txt`의 패키지로 사용할 수 있습니다.
다른 프로젝트의 코드·자산·자료를 읽거나 가져오는 경로와 자동 동기화를 만들지 않습니다.
작업은 `main`에서 관리하며 모든 명령과 상대 경로는 `novel/` 기준입니다.

## 문서와 자료의 역할

`AGENTS.md`는 작업자가 지킬 규칙, `README.md`는 사용법·파일·명령 안내입니다.
`writing/AGENTS.md`는 집필 제약, `characters/AGENTS.md`는 공개·복선 제약만 추가합니다.
상위 규칙을 하위 README에 복사하거나 다른 규칙으로 재정의하지 않습니다.

일상 편집은 이름(`reference/names.json`), 인물 해석(`reference/analysis.json`),
관계(`characters/relationships.analysis.json`), 구성(`writing/storyboard/`),
본문·계약(`writing/quests/`), 분기(`writing/branches/`, 첫 장은 `writing/interactive/`)에서 합니다.
`materials/`는 원문 보관소, `authoring/examples/`는 검증 예시, 생성 HTML·PDF·그래프는
읽기용 출력입니다. 셋 모두 현재 집필 원고가 아닙니다.
[전체 파일 역할·소비자 지도](docs/project-map.json)는 `tools/project_audit.py export`로 갱신합니다.

## 읽기

작가용 [소설 제작실 · 웹에서 열기](https://obmaz.github.io/lore/novel/studio/): 현재 원고·목차·장별
그래프·분기·출판 순서·인물/무기/마법 설정을 한곳에서 조회합니다.
[오프라인 HTML](writing/studio/generated/index.html) 하나로도 사용할 수 있습니다.
사용자 요청으로 공개 게시된 읽기 전용·전편 스포일러 화면이며 로그인은 없습니다.
[사용·갱신 안내](writing/studio/README.md)를 참고합니다.

[15장 곁가지 선택 시범](https://obmaz.github.io/lore/novel/studio/#/graph?graphPanel=preview)은
각 장 두 개의 곁가지와 5개 중첩 선택·후속 반응을 확인하는 창작 초고입니다. 본줄기는 기존 기본 경로의 주요 내용으로
유지하며, 원문 전체·완성 장편 판본과 구분합니다. [원본 JSON·연결·검사 범위](writing/side-stories/README.md).

독자용 실제 본문 · A 1~3장 / B 1~3장 초고: [웹에서 판본을 선택하며 읽기](https://obmaz.github.io/lore/novel/)

공용 문체는 [writing/styles.json](writing/styles.json)에서 A/B로 관리합니다.
A는 기존 산문, B는 빠른 호흡의 웹소설형입니다. 목차·구성·분기·원작 대사는 같고
B 미집필 장을 A로 자동 대체하지 않습니다. [판본 집필 방법](writing/variants/README.md).
또는 [A/B 오프라인 HTML](writing/previews/novel-reader.html)을 내려받아 브라우저로 엽니다.
경로는 다운로드 파일로 저장/불러오며 계정·서버 저장 기능은 없습니다.

작가용 큰 구성·원작 연결 초고·소단락·분기·기본 경로와 소편 읽기본은
[집필 안내](writing/README.md#바로-읽기)에 모았습니다. 전편 구성과 인물 마스터는
스포일러를 포함합니다. 독자용 정보에는 경로별 공개 필터를 사용합니다.

[출판용 소제목 트리·흐름도](writing/previews/publication-flow.html)는 JSON과 Markdown으로도
제공합니다. [구조·경로·갱신 안내](writing/publication/README.md)를 참고합니다. 작가용 전편
자료이며 최종 본문·출판 경로·페이지는 아직 미정입니다.

## 자료 위치

| 위치 | 역할 | 안내 |
| --- | --- | --- |
| `materials/` | 대사·조건·선택·진행·적 레코드의 고정 원문 JSON | [원문 보관소](materials/README.md) |
| `characters/` | 작가 전용 인물 카드·관계와 공개 정책 | [인물 안내](characters/README.md) |
| `reference/` | 이름·장비·마법·적·용어와 분석 입력 | [참조 사전](reference/README.md) |
| `authoring/` | 공용 원고 스키마·`examples/` 검증 예시 | [원고 형식](authoring/README.md) |
| `writing/` | 큰 구성·소단락·분기·장면·본문·생성 읽기본 | [집필 안내](writing/README.md) |
| `continuity/` | 공통 사실·인물별 지식·장면 계약·승인 | [연속성 안내](continuity/README.md) |
| `exports/` | 작가용/필터된 참고 HTML·PDF 스냅샷 | [내보내기](exports/README.md) |
| `tools/`, `tests/` | 독립 조회·생성·검증 도구와 테스트 | [작업 지침](AGENTS.md) |

`LORETALK.PAS` 같은 이름·줄 번호는 내부 JSON의 원문 출처 표식입니다.
해당 외부 파일을 열거나 코드를 실행하지 않습니다. 고정 스냅샷의 반복·빈 문자열·
기술 문자열도 보존하며, 모두 대사이거나 한 경로에서 경험한 사건이라는 뜻은 아닙니다.

## 설치와 검증

```sh
python -m pip install -r requirements.txt
python -X utf8 tools/materials.py
python -X utf8 tools/characters.py
python -X utf8 tools/reference.py
python -X utf8 tools/validate_story_authoring.py
python -X utf8 tools/writing.py validate
python -X utf8 tools/branch_system.py validate
python -X utf8 tools/source_story.py validate
python -X utf8 tools/source_story.py export --check
python -X utf8 tools/writing.py export --check
python -X utf8 tools/export_reference.py --check
python -X utf8 tools/project_audit.py export --check
```

전체 테스트는 모듈 경로를 설정해 실행합니다.

```powershell
# Windows PowerShell
$env:PYTHONPATH = 'tools'
$env:PYTHONUTF8 = '1'
python -X utf8 -m unittest discover -s tests
```

```sh
# POSIX shell
PYTHONUTF8=1 PYTHONPATH=tools python3 -m unittest discover -s tests
```

검증은 구조·근거·원문 보존·경로 계약을 검사하며 산문의 의미·문체를 자동 승인하지 않습니다.
`PYTHONUTF8=1`은 테스트가 실행하는 하위 Python 프로세스에도 UTF-8을 적용합니다.
상위 명령의 `-X utf8`만 사용하면 하위 프로세스는 Windows 기본 인코딩을 사용할 수 있습니다.

원문·생성물의 해시는 파일 바이트 기준입니다. Windows에서 Git의 `core.autocrlf=true`로
체크아웃하면 CRLF 변환 때문에 `material snapshot changed`가 발생할 수 있습니다.
이 경우 원본 Git 바이트와 작업 파일의 줄바꿈을 먼저 비교합니다. 검사만 통과시키려고
스냅샷 해시를 바꾸거나 생성물을 덮어쓰지 않습니다. 바이트가 유지되는 LF 환경에서 검증합니다.

## 수정과 게시

수정 대상은 [집필 안내](writing/README.md#수정-위치)에서 확인합니다.
보존 원문은 매 집필마다 재생성하지 않습니다. 원문 스냅샷을 바꾸려면 내부 근거·
매니페스트·승인 영향을 함께 검토합니다. 생성 파일의 수동 수정을 강제로 덮어쓰지 않습니다.

원고를 바꾼 뒤 다음 명령으로 독자용 읽기본을 갱신합니다.

```sh
python -X utf8 tools/writing.py validate
python -X utf8 tools/writing.py export
python -X utf8 tools/writing.py export --check
```

원고·읽기본을 함께 `main`에 푸시하면 저장소 Pages가 읽기본의 입력·출력 해시를 검사해
독자용 A/B 통합 화면 `writing/previews/novel-reader.html`을 `/novel/index.html`에,
공개 허용된 `writing/studio/generated/index.html`을 별도 `/novel/studio/index.html`에 게시합니다.
게시 과정은 원고를 재생성하지 않습니다. 인물 마스터·전편 설정은 독자 읽기본에 넣지 않으며
제작실의 HTML에는 포함됩니다. 원문 JSON·PDF 파일을 별도로 게시하지는 않습니다.
제작실의 공개 설정은 `writing/studio/publication.json`입니다. 두 화면 모두 보안 저장소가 아닙니다.

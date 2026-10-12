# LORE 소설 집필 패키지

원문 스냅샷·인물/설정 사전·집필 원고·분기/연속성 검증 도구를 포함합니다.
이 폴더만 복사해 Python과 `requirements.txt`의 패키지로 사용할 수 있습니다.
다른 프로젝트의 코드·자산·자료를 읽거나 가져오는 경로와 자동 동기화를 만들지 않습니다.
작업은 `main`에서 관리하며 모든 명령과 상대 경로는 `novel/` 기준입니다.

## 읽기

독자용 첫 챕터: [웹에서 선택하며 읽기](https://obmaz.github.io/lore/novel/)
또는 [오프라인 HTML](writing/previews/chapter01-interactive.html)을 내려받아 브라우저로 엽니다.
경로는 다운로드 파일로 저장/불러오며 계정·서버 저장 기능은 없습니다.

작가용 큰 구성·원작 연결 초고·소단락·분기·기본 경로와 소편 읽기본은
[집필 안내](writing/README.md#바로-읽기)에 모았습니다. 전편 구성과 인물 마스터는
스포일러를 포함합니다. 독자용 정보에는 경로별 공개 필터를 사용합니다.

## 자료 위치

| 위치 | 역할 | 안내 |
| --- | --- | --- |
| `materials/` | 대사·조건·선택·진행·적 레코드의 고정 원문 JSON | [manifest](materials/manifest.json) |
| `characters/` | 작가 전용 인물 카드·관계와 공개 정책 | [인물 안내](characters/README.md) |
| `reference/` | 이름·장비·마법·적·용어와 분석 입력 | [참조 사전](reference/README.md) |
| `authoring/` | 공용 원고 스키마·보존한 구조 예시 | [원고 형식](authoring/README.md) |
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
`writing/previews/chapter01-interactive.html`만 `/novel/index.html`에 게시합니다.
게시 과정은 원고를 재생성하지 않습니다. 인물 마스터·전편 설정·원문 JSON·작가용 HTML/PDF는
독자 사이트에 포함하지 않습니다. 미선택 첫 챕터 분기는 HTML 소스에 있으므로 보안 저장소로 취급하지 않습니다.

# LORE 인터랙티브 소설 집필 자료

이 폴더만 복사해서 사용할 수 있는 집필 패키지다. 대사·선택지·분기·진행 자료와
검증 도구를 모두 포함한다. Python과 `requirements.txt`의 패키지만 필요하다.
원래 게임 저장소, Pascal 파일, Flutter 소스, 게임 자산을 읽지 않는다.

작업 위치는 저장소 루트의 `novel/`이며 `main` 브랜치에서 관리한다.
이 문서의 명령과 상대 경로는 모두 이 폴더를 기준으로 한다. 다른 루트
프로젝트와 자동 수입·동기화 관계가 없으며, 게임 Pages 배포에 포함되지 않는다.

```text
novel/
├── materials/        원문·선택지·조건·진행 자료의 고정 JSON 스냅샷
├── characters/       인물별 이름·원작 정보·성향·말투·관계
├── reference/        무기·방어구·마법·적 사전과 수동 분석 입력
├── authoring/        공용 집필 스키마와 보존한 구조 예시
├── writing/          새 스토리보드·공용 템플릿·퀘스트 본문·읽기본
├── continuity/      공유 설정과 연속성 스키마
├── exports/         조회용 오프라인 HTML·작가용 PDF 스냅샷
├── tools/           원문·인물·집필·경로 검증 도구
└── tests/           독립 실행과 분기·연속성 검사
```

## 먼저 읽을 자료

- [1-1 · 돌아오겠다는 말](writing/previews/menace-01.html): 이번에 약 4천 자로 다시 쓴 첫 소편.
  한 번에 한 소편씩 집필하고 문체를 검토한다. [여섯 소편의 작업 목록](writing/episodes/lore_menace.json).
- [writing/README.md](writing/README.md): 전편 보드·도입부 시범 원고·공용 템플릿과 이름 참조.
- [exports/README.md](exports/README.md): JSON 대신 참고용 HTML/PDF로 읽는 방법. 작가용 전체 설정과 공개 범위 미리보기를 분리한다.
- [materials/quests.json](materials/quests.json): 18개 집필 단위와 공통 부록의 목록·연결.
- [materials/quests/lore_menace.json](materials/quests/lore_menace.json): 첫 의뢰의 실제 원문·조건.
- [characters/registry.json](characters/registry.json): 인물 카드 49개와 관계 48개 링크의 작가 전용 마스터.
- [characters/README.md](characters/README.md): 인물 이름·성향·관계를 작성하는 방법.
- [characters/relationships.analysis.json](characters/relationships.analysis.json): 관계 원문 근거·공개 시점·허용 복선의 편집 입력.
- [reference/README.md](reference/README.md): 장비 20종·마법 45종·적 템플릿 75종과 창작 표시 규칙.
- [AGENTS.md](AGENTS.md): 원작에 없는 설정의 추가 메타데이터를 강제하는 작업 지침.
- [authoring/README.md](authoring/README.md): 선택·본문·조건·원문 대응 규칙.
- [continuity/README.md](continuity/README.md): 이전 장면과의 일관성·설정 변경 추적.

원문 묶음은 14개 파일의 문자열 발생 2,483개를 보존한다. 같은 대사의 반복과
빈 문자열·UI·코드용 문자열도 포함하며 모두 등장인물의 대사라는 뜻은 아니다.
`materials/scripts.json`에는 원문 텍스트, 출력 문구, 변수 자리, 분기 구조와 안정된
발생 ID가 있다. 퀘스트 자료에는 실제 대사와 사건 근거가 함께 들어 있다.

`LORETALK.PAS` 같은 이름과 줄 번호는 JSON 안에 보관된 원문을 가리키는 출처 표식이다.
그 이름의 외부 파일을 열지 않는다. 원문 코드도 JSON 안의 보존 자료이고 실행하지 않는다.
기존 `authoring/drafts/`의 프롤로그는 구조 예시다. 새 `writing/`에는 전편 보드와
첫 의뢰 직전까지의 시범 본문이 있고, 보류 대사·접근 조건과 새 창작을 표시한다.
이어서 첫 탐사·귀환 보고까지의 1장 초고를 작성했다. 도입부 선택과 첫 출구의 동행
수락/거절을 조합한 네 가지 읽기본은 `writing/README.md`에서 볼 수 있다.

## 독립 실행

복사한 `novel/` 폴더에서 다음을 실행한다. 게임 빌드는 필요 없다.

```bash
python3 -m pip install -r requirements.txt
python3 tools/materials.py
python3 tools/characters.py
python3 tools/reference.py
python3 tools/validate_story_authoring.py
python3 tools/writing.py validate
python3 tools/writing.py export --check
python3 tools/story_continuity.py --route enter_courtyard visit_prison accept_joe visit_lord
python3 tools/export_reference.py --check
PYTHONPATH=tools python3 -m unittest discover -s tests
```

경로 자료에는 그 장면에 실제 등장하는 **공개 필터된** 인물 카드와 관련 장비·마법·적 참조도 포함한다. Joe를 영입하지 않은
성주 접견에서는 Joe 카드가 등장 인물로 전달되지 않는다. 인물의 `writing` 제안은
승인 상태를 유지하여 원작의 확정 설정과 섞이지 않도록 한다.
원본 인물 JSON을 집필 프롬프트에 통째로 넣지 않는다. 관계/정체의 공개 전에는
진상을 숨기고 허용된 복선만 전달한다. 공개 사건과 지식 습득, 현재 영입 상태도 구분한다.

## 원문 자료와 원고의 수정

`materials/manifest.json`은 모든 원문 자료 파일의 SHA-256과 발생 개수를 기록한다.
검증은 먼저 스냅샷 무결성을 확인한다. 집필 원고는 편집하되 인물·장비·마법 사전은
`reference/analysis.json`을 수정하고 `python3 tools/build_reference.py`로 재생성한다.
출력의 수동 편집이 발견되면 생성 도구가 덮어쓰기를 거부한다.
원문 스냅샷은 매 집필마다 다시 생성하지 않는다. 인물 수정 시 그 인물과 인물 목록의
`revision`을 올리면 의존 장면이 재검토 대상으로 표시된다.

원문은 이 패키지 내부의 고정 스냅샷으로 관리하며 게임 프로젝트의 자료를
자동으로 읽거나 갱신하지 않는다. 스냅샷을 변경할 때는 내부 근거와 매니페스트를
함께 검토하고, 내용과 해시가 달라지면 기존 원고의 승인 상태를 다시 검토한다.

원작 적 데이터 `FOEDATA.DAT`도 `materials/enemy_templates.json`으로 보존했다.
바이너리 근거는 줄 번호가 아니라 `record_index`로 표시하며, 75개 원본 레코드와
해시를 JSON만으로 재구성할 수 있다. 보스의 이름·능력 변경은 보존된 스크립트 근거를
함께 본다. 기본 템플릿 수치를 모든 장면의 고정 능력으로 쓰지 않는다.

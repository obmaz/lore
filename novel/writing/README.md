# 스토리보드와 새 원고

설정은 상위 사전, **이야기 구성과 본문은 이 폴더**에서 관리한다.
전편 큰 흐름 → 한 퀘스트 시범 집필 → 검토 → 다음 퀘스트 순으로 발전시킨다.
이번 구성은 4개 본편 막과 별도 보조 이야기, 18개 퀘스트의 편집 초안이다.
막 구분·감정선·장면 연결은 창작 제안이지 원작 진행의 강제 순서가 아니다.

## 바로 읽기

- [전편 스토리보드](previews/storyboard.html): 작가 전용, 전편 스포일러 포함.
- [도입부 · 성주 직행](previews/prologue.html): 첫 의뢰 제시 직전까지의 시범 본문.
- [도입부 · 주점 방문](previews/prologue-tavern.html): 선택 방문을 한 경로의 시범 본문.

HTML을 다운로드해 브라우저로 열면 된다. 서버·게임·외부 네트워크가 필요 없고,
인쇄 버튼으로 PDF 저장도 가능하다. GitHub 파일 화면 자체는 HTML을 실행하지 않는다.
HTML은 편집 대상이 아니라 JSON에서 생성한 스냅샷이다.

```text
writing/
├── project.json                    시점·문체 제안
├── templates/
│   ├── storyboard.template.json    공용 전체/퀘스트 보드 양식
│   ├── quest.template.json         본문·선택·상태·원문 대응 양식
│   └── continuity.template.json    등장 인물·지식·사건·검토 양식
├── storyboard.schema.json          보드 형식
├── storyboard/series.json          전편 큰 흐름 · 작가 전용
├── quests/prologue.json            도입부 시범 본문 · 6장면, 6선택
├── quests/prologue.continuity.json  시범 원고의 경로 기억과 계약
└── previews/                       읽기 전용 HTML와 무결성 매니페스트
```

기존 `authoring/drafts/prologue.json`은 보존한 구조 예시다. 새 집필 원고가 아니다.
새 시범은 제한적 3인칭을 **미승인 문체 제안**으로 사용한다. 성별·나이·직업·초기 장비와
동료 네 명은 임의로 확정하지 않았다. 감옥 방문은 접근 시점 미확정이라 넣지 않았다.

## 이름은 한 곳에서 변경

현재 주인공 ID는 `protagonist`, 임시 집필 이름은
[../reference/names.json](../reference/names.json)의 `characters.protagonist.value`에 있다.
원작에 없는 추가 이름이므로 `authored` / `new_setting` / `proposed`로 표시했다.
이 이름은 원작 이름이나 한국어 음역을 덮어쓰지 않는다.

본문에는 표시명 대신 다음처럼 쓴다.

```json
[
  {"ref": {"catalog": "characters", "id": "protagonist", "particle": "은/는"}},
  {"text": " 걸음을 멈췄다."}
]
```

`catalog`는 `characters`, `equipment`, `abilities`, `bestiary`, `terms`를 지원한다.
`equipment/weapon_1` 같은 참조도 같은 방식이다. 사전에 있다는 이유로 그 장비를
지급하거나 마법을 습득한 것으로 쓰지 않는다. 조사 `은/는`, `이/가`, `을/를`, `과/와`,
`으로/로`는 현재 표시명의 받침에 맞춰 선택한다.

장비·마법·적의 새 집필 이름도 `reference/names.json`의 해당 분류 아래에 항목 ID와
완전한 claim을 추가한다. `characters.protagonist`와 동일한 메타데이터 형식을 쓰되
원작에 없는 이름임을 이유와 함께 표시한다. 지명/열쇠 음역은 `reference/terms.json`에 있다.
새 이름은 인물의 숨은 정체에 설정된 공개 정책을 우회하지 못한다.

이름 수정 후 `novel/`에서 실행한다.

```bash
python3 tools/build_reference.py
python3 tools/writing.py validate
python3 tools/writing.py export
python3 tools/export_reference.py --pdf
```

JSON 원고는 바꿀 필요 없이 새 이름으로 렌더링된다. 이미 만든 HTML/PDF 스냅샷은
위 명령으로 갱신해야 한다. 생성 도구는 수동 편집을 보호하고 관련 revision을 올린다.
집필 이름 입력과 생성 카드가 다르면 읽기본 도구는 멈추고 재생성을 안내한다.
이름 변경도 기존 승인을 무효화하고 의존 장면을 재검토하게 하며 자동 재승인하지 않는다.

## 원문 대사와 이름 치환

원문은 `materials/scripts.json`에 그대로 있다. 새 원고는 `source.literal_ids`로
여러 출력 조각을 원래 순서대로 이어 읽으며, 이름 구간에는 `bindings`를 둔다.
`start`/`end`는 이어 붙인 원문 문자열의 문자 오프셋이고 `end`는 미포함이다.
원문 안의 이름을 인물 ID로 연결하면 표시명만 변경된다. 원문 기록·원문 순서·출처 ID는
변하지 않는다. 검증은 이름 구간 일치, 겹친 구간, 빠진 이름 바인딩을 검사한다.

도입부에는 첫 안내·주점 인물·성주의 첫 인사와 배경 설명의 선택한 출력 조각을
전부 연결했다. 출발 UI·진행 후 반복 대사는 보류했고 첫 탐사 의뢰 자체는 다음 원고의
범위다. `coverage: partial`이며 전체 게임 대사를 완성한 소설은 아니다.
전편 보드도 공통 예언·가르침의 삽입 시점과 미확정 접근 조건을 보류한다.

## 이어 쓰는 순서

1. 보드에서 해당 퀘스트의 목표·갈등·전환·끝을 검토한다.
2. 원문 퀘스트 JSON의 대사·강제/선택/병렬 조건을 확인한다.
3. 공용 양식으로 원고와 연속성 파일을 만든다. 기존 파일은 덮어쓰지 않는다.
4. 장면·선택·조건부 문단과 원문 발생의 처리 내역을 작성한다.
5. 등장 인물·들은 증언·습득한 것·미해결 질문과 다음 퀘스트 인계를 연결한다.
6. 경로별 프리뷰를 검토하고 승인한다. 다음 원고에서도 기존 상태를 지우지 않는다.

```bash
python3 tools/writing.py new-quest --quest-id lore_menace
python3 tools/writing.py validate
python3 tools/writing.py preview --route enter_courtyard visit_lord hear_lord_intro hear_lord_briefing
python3 tools/writing.py preview --route enter_courtyard visit_tavern remember_veteran visit_lord hear_lord_intro hear_lord_briefing
python3 tools/writing.py export --check
```

`new-quest`는 빈 원고와 검토용 계약을 만들 뿐 내용을 자동 완성/승인하지 않는다.
추가 원고는 `validate_story_authoring.py`로 검사하고 `writing.py preview --story …`
에 해당 파일과 경로를 지정한다. 경로 프리뷰는 현재까지 공개된 정보만 사용한다.
모든 가능한 경로, 산문의 의미·인물 동기의 일관성은 별도 편집 검토가 필요하다.

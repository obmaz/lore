# 스토리보드와 새 원고

설정은 상위 사전, **이야기 구성과 본문은 이 폴더**에서 관리한다.
전편 큰 흐름 → 퀘스트 구성 → 작은 소편 하나 집필 → 문체 검토 → 다음 소편 순으로 발전시킨다.
이번 구성은 4개 본편 막과 별도 보조 이야기, 18개 퀘스트의 편집 초안이다.
막 구분·감정선·장면 연결은 창작 제안이지 원작 진행의 강제 순서가 아니다.

## 바로 읽기

- **이번에 다시 쓴 소편:** [1-1 · 돌아오겠다는 말](previews/menace-01.html) /
  [주점 방문 기억이 있는 경로](previews/menace-01-tavern.html). 약 4,100~4,350자이며 첫 의뢰 수락에서 멈춘다.
- [1-2 · 성문 앞의 목소리](previews/menace-02.html) /
  [동행 거절](previews/menace-02-declined.html). 소편별로 집필·푸시하며 아래 진행표를 갱신한다.
- [1-3 · 빛이 남아 있는 곳](previews/menace-03.html) /
  [동행 거절 경로](previews/menace-03-declined.html).
- [1-4 · 어둠의 중심](previews/menace-04.html) /
  [동행 거절 경로](previews/menace-04-declined.html).
- [도입부터 1장까지 · 동행 수락](previews/first-journey.html): 첫 탐사·귀환 보고와 다음 부탁까지.
- [도입부터 1장까지 · 동행 거절](previews/first-journey-declined.html): 같은 의뢰, 다른 현재 동료.
- [주점 방문 후 1장 · 수락](previews/first-journey-tavern.html) /
  [거절](previews/first-journey-tavern-declined.html): 앞서 들은 증언이 이동·귀환 문단에 이어진다.
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
│   ├── continuity.template.json    등장 인물·지식·사건·검토 양식
│   └── episode.template.json       공용 소편 묶음·분량·종료 지점 양식
├── storyboard.schema.json          보드 형식
├── storyboard/series.json          전편 큰 흐름 · 작가 전용
├── quests/prologue.json            도입부 시범 본문 · 6장면, 6선택
├── quests/prologue.continuity.json  시범 원고의 경로 기억과 계약
├── quests/lore_menace.json          1장 「돌아오는 일」 · 첫 퀘스트 기본 경로 초고
├── quests/lore_menace.continuity.json  영입·증언·탐사·보상·다음 부탁의 기록
├── episodes/lore_menace.json        한 퀘스트를 나눈 여섯 소편의 작업 목록
├── reading.json                    전체 연결 네 경로 + 1-1만 읽는 두 경로
└── previews/                       읽기 전용 HTML와 무결성 매니페스트
```

기존 `authoring/drafts/prologue.json`은 보존한 구조 예시다. 새 집필 원고가 아니다.
새 시범은 제한적 3인칭을 **미승인 문체 제안**으로 사용한다. 성별·나이·직업·초기 장비와
동료 네 명은 임의로 확정하지 않았다. 감옥 방문은 접근 시점 미확정이라 넣지 않았다.

## 현재 집필 범위

1장은 14장면·15선택을 여섯 소편으로 묶었다. **소편별 집필 진행은 아래 표와
`episodes/lore_menace.json`에 기록한다.** 아직 구조 초고인 소편은 긴 본문으로 완성한 것이 아니다.
성주의 의뢰 → 첫 출구의 동행 요청 →
남서쪽 이동 → 동굴 중심부 확인 → 귀환·보상 → 다음 지역 안내까지의 기본 경로다.
스켈레톤의 첫 합류 요청은 원작의 성 출구 사건이며 수락·거절을 따로 보존한다.
수락을 정사로 고정하거나 미작성 동료의 슬롯을 자동 교체하지 않는다.
무기고·수감소·선택 금/방패 발견·무작위 전투는 보류한 별도 경로다.
원문 중심부에 없는 고정 보스를 추가하지 않았다. 원작 UI 경험 보상은 성주의 대사가
아닌 화자 없는 원문 블록으로 보존하며 새 능력/나이/자동 레벨 상승으로 바꾸지 않는다.

새 연결 서사·반응·대화·길의 감각은 블록마다 `authored`와 추가 설명을 붙였다.
해당 퀘스트의 모든 부수 경로를 완성한 원고는 아니며 `coverage: partial`을 유지한다.
이후 지역의 진상을 먼저 공개하지 않고 다음 원고의 인계 지점에서 멈춘다.

## 한 번에 한 소편

퀘스트 하나를 한 번에 완성하지 않는다. 공용 `episode.template.json`의 형태로
소편을 나누며, `episodes/lore_menace.json`은 다음 여섯 묶음을 정의한다.

| 소편 | 범위 | 현재 상태 |
| --- | --- | --- |
| 1-1 돌아오겠다는 말 | 첫 의뢰를 듣고 대답하기 | 긴 장면으로 재집필한 미승인 초고 |
| 1-2 성문 앞의 목소리 | 출발 준비·첫 동행 요청과 수락/거절 | 긴 장면으로 집필한 미승인 초고 |
| 1-3 빛이 남아 있는 곳 | 남서쪽 이동·동굴 문턱 | 긴 장면으로 집필한 미승인 초고 |
| 1-4 어둠의 중심 | 동굴 안 이동·중심부 확인 | 긴 장면으로 집필한 미승인 초고 |
| 1-5 돌아온 사람들 | 귀환·보고와 보상 | 짧은 구조 초고 |
| 1-6 다음 부탁 | 다음 지역의 부탁·작별 | 짧은 구조 초고 |

한 소편은 약 3,500~6,500자를 출발 목표로 삼는다. 분량을 채우기 위한 반복 대신,
대화 전후의 움직임·감각·작은 오해·머뭇거림이 변하는 시간을 쓴다. 설정의 미정 여부와
원문 조건의 검증 설명은 본문이 아니라 메타데이터에 둔다. 먼저 한 소편의 문체를
읽고 피드백을 받은 뒤 다음 소편을 작성한다. 사용자가 여러 소편을 이어 쓰라고 요청하면
한 소편을 집필·확인·푸시한 뒤 다음 소편으로 진행한다. 한 번의 변경으로 모두 늘리지 않는다.

소편 JSON은 **본문을 복제하지 않는 작업 목록**이다. 실제 문장은 `quests/`의 원고에서
해당 `node_ids`만 수정하고 대응 `continuity`를 갱신한다. 원문 대사도 기존 발생 ID를
유지한다. 처음의 긴 채팅 원고는 저장소에서 확인되지 않았으므로 이번 문체가 정확한
복원이라고 주장하지 않는다.

소편 읽기본은 이전 경로를 재생해 기억을 이어받되, 해당 소편의 끝에서 경로를 멈춘다.
`focus_nodes`는 화면의 장면 선택이며 상태를 초기화하지 않는다. 전체 미래 경로를
먼저 재생하고 문단만 숨기는 것은 허용하지 않는다.

```bash
python3 tools/writing.py reading --reading-key menace-01
python3 tools/writing.py reading --reading-key menace-01-tavern
python3 tools/writing.py episode --episode-id menace-02
python3 tools/writing.py episode --episode-id menace-02 --reading-key first-journey-tavern-declined
```

`episode`는 집필 완료 초고(`revised_draft`)만 읽으며, 전체 경로의 본문을 재사용하더라도
반환하는 지식·상태는 해당 소편의 끝에서 다시 계산한다. 이미 잘라낸 읽기본의 장면 번호를
원래 경로의 선택 번호로 오인하지 않는다. HTML은 기본 수락/거절 두 경로를 제공하고,
주점 방문 기억까지 조합한 경로는 위 명령 또는 전체 연결 읽기본으로 확인한다.

`reading.py`는 실제 원고와 계약을 검증한 뒤 파일 경계를 연결하는 읽기용 파생본을
만든다. 앞선 주점 방문·증언·동료 상태를 초기화하지 않는다. 임의의 저장 상태나
지식 JSON을 입력해 과거를 만들어 내지 않고, 원고의 실제 선택 경로를 다시 계산한다.
원본 원고를 합쳐 덮어쓰거나 미검토 장면을 승인하지 않는다.

```bash
python3 tools/writing.py reading --reading-key first-journey
python3 tools/writing.py reading --reading-key first-journey-declined
python3 tools/writing.py reading --reading-key first-journey-tavern
python3 tools/writing.py reading --reading-key first-journey-tavern-declined
```

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
python3 tools/writing.py new-quest --quest-id lastditch_pyramid
python3 tools/writing.py validate
python3 tools/writing.py preview --route enter_courtyard visit_lord hear_lord_intro hear_lord_briefing
python3 tools/writing.py preview --route enter_courtyard visit_tavern remember_veteran visit_lord hear_lord_intro hear_lord_briefing
python3 tools/writing.py export --check
```

`new-quest`는 빈 원고와 검토용 계약을 만들 뿐 내용을 자동 완성/승인하지 않는다.
추가 원고는 `validate_story_authoring.py`로 검사하고 `writing.py preview --story …`
에 해당 파일과 경로를 지정한다. 경로 프리뷰는 현재까지 공개된 정보만 사용한다.
1장처럼 이전 지식이 필요한 원고는 단독 초기값으로 읽지 않고 `reading` 경로로 연결한다.
모든 가능한 경로, 산문의 의미·인물 동기의 일관성은 별도 편집 검토가 필요하다.

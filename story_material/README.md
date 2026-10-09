# LORE 스토리 집필을 위한 원문·진행 자료

게임을 바꾸거나 실행하기 위한 데이터가 아니다. 보존된 1993년 Pascal 원문에서
대사·선택지·진행 조건을 추출하고, 퀘스트 단위의 이야기를 쓰기 위한 자료로 묶었다.
최상위 추출 자료에는 새로운 연결 서사를 넣지 않았다. 별도 집필 초안은 아래를 참고한다.

선택형 집필을 위한 별도 형식과 구조 초안은 [novel/authoring/README.md](../novel/authoring/README.md)에
있다. 원문 추출 JSON과 사람이 작성하는 집필 JSON을 분리하며, 아래 재생성은
`authoring/`의 원고를 덮어쓰지 않는다.

## 처음 볼 파일

1. [quests.json](quests.json): 퀘스트 목록, 각 파일 위치, 퀘스트 사이의 연결 근거.
2. [quests/lore_menace.json](quests/lore_menace.json): 첫 의뢰부터 보고까지의 집필 자료 예시.
3. [progression.json](progression.json): 네 퀘스트 카운터의 전이, 다른 상태 변화,
   지도 전환, 조기 종료·전투·엔딩 호출, 원본 예지 안내문 선택기.
4. [scripts.json](scripts.json): 원본 파일 전체, 파일 해시, 모든 문자열 발생 위치,
   프로시저의 전체 분기 구조와 지도별 사건 목록.
5. [coverage.json](coverage.json): 원문 문자열·제어 분기 개수와 추출 범위·한계.

## 퀘스트별 집필 자료

| 파일 | 집필 단위 |
| --- | --- |
| [prologue.json](quests/prologue.json) | 모험의 시작과 일행 구성 |
| [lore_menace.json](quests/lore_menace.json) | Lord Ahn의 의뢰와 MENACE 탐사 |
| [lastditch_pyramid.json](quests/lastditch_pyramid.json) | LASTDITCH와 Major Mummy |
| [gaia_evil_seal.json](quests/gaia_evil_seal.json) | GAIA TERRA와 황금의 봉인 |
| [gaia_quake.json](quests/gaia_quake.json) | QUAKE와 Water Key |
| [wivern_passage.json](quests/wivern_passage.json) | WIVERN과 다음 대륙으로의 통로 |
| [water_notice.json](quests/water_notice.json) | 물의 대륙과 Hidra |
| [water_lockup.json](quests/water_lockup.json) | Huge Dragon과 Swamp Key |
| [swamp_arrival.json](quests/swamp_arrival.json) | 늪의 대륙 진입과 조언 |
| [evil_god_seal.json](quests/evil_god_seal.json) | EVIL GOD의 봉인 |
| [muddy_seal.json](quests/muddy_seal.json) | MUDDY의 봉인 |
| [swamp_keep_lava_gate.json](quests/swamp_keep_lava_gate.json) | 두 봉인 이후 라바 게이트 |
| [imperium_minor.json](quests/imperium_minor.json) | IMPERIUM MINOR 돌파 |
| [last_shelter.json](quests/last_shelter.json) | 피난처·주민·보급·선택 대화 |
| [evil_concentration.json](quests/evil_concentration.json) | 환상과 가짜 Necromancer |
| [dungeon_of_evil.json](quests/dungeon_of_evil.json) | 기계 적·숨은 레버·마지막 수문장 |
| [necromancer_finale.json](quests/necromancer_finale.json) | 결전·이별·엔딩 |
| [another_lore.json](quests/another_lore.json) | 지식·수수께끼·선택의 보조 이야기 |
| [shared_system_and_text.json](quests/shared_system_and_text.json) | 공통 대사·시설·전투·메뉴·선언·플랫폼 자료 부록 |

위 제목과 묶음은 집필용 분류다. 원작에 이 이름의 퀘스트 ID가 있다는 뜻은 아니다.
같은 성주 대화나 이동 지역은 여러 의뢰에서 사용되므로 원문을 여러 파일에 보존한다.
`stage_focus`로 해당 파일에서 집중할 상태 단계를 확인한다. 중복 원문은 원본 ID로
식별되며, 이야기에 같은 대사를 여러 번 넣으라는 뜻은 아니다.

## 한 퀘스트 파일을 읽는 방법

- `milestones`: 주요 사건의 집필 순서, 원문 근거, 그 범위의 원래 출력 대사
  (`original_display_events`)와 선택지 등을 포함한 모든 문자열
  (`original_literal_occurrences`).
- `scripts`: 지도별 사건·대화 전체. `original_source`에 원문 코드,
  `structure`에 순서·if 양쪽·case 각 갈래·반복·레이블·조기 종료가 들어 있다.
- `display_events`: 원문 출력 호출의 읽기 쉬운 문구와 조건. `cPrint`의 색상별
  문자열 조각은 한 줄로 이어 보여준다. 변수는 `{{player[1].name}}`, `{{s}}`
  같은 원래 식으로 표시하며 변수 값을 추측하지 않는다.
- `text_occurrences`: 빈 문자열, 같은 문구의 재등장, 원래 공백·오탈자까지
  보존한 발생 위치별 목록. 원본 Pascal 리터럴도 별도로 들어 있다.
- `branch_context`: 그 대사·상태 변화가 어느 조건과 선택 갈래에 속하는지.
- `state_changes`: 조건·상태 바이트의 대입·증가·감소 원문. `:=2`는 `inc`와
  다른 동작이고, 의뢰를 듣기 전에 목표를 달성하는 경로를 만들 수도 있다.
- `called_routine_candidates`: 직접 발화가 아닌 공통 프로시저 호출 후보.
  공통 대사와 원본 프로시저는 `scripts.json` 또는 부록에서 찾아본다.
- `bridge_slots`: 앞뒤 사건의 근거 사실과 연결 서사를 쓸 빈 `draft`.
- `writing_workspace`: 퀘스트의 도입·연결·마무리를 쓸 빈칸.

원문과 창작을 구분한다. 주인공의 감정, 동행자와의 대화, 이동 묘사, 시간 경과는
새 연결 서사가 될 수 있지만 원문에 이미 있었다고 표시하면 안 된다. 원문의
대사·선택지·조건을 유지하면서 창작한 문장은 별도 초안에 작성한다.

## 진행 순서를 해석할 때

`source_order`나 JSON 배열 순서는 파일에 쓰인 순서이지 단일 플레이 경로가 아니다.
같은 사건의 수락·거절, 독심술 여부, 첫 방문·재방문, 보스 격퇴·도주·패배를
모두 순서대로 발생한 일로 이어 붙이면 안 된다. `branch_context`와 `structure`를
읽고, 쓸 경로를 선택하며 나머지 분기는 대체 이야기 자료로 남긴다.

`route_edges.kind`의 구분은 다음과 같다.

| 종류 | 의미 |
| --- | --- |
| `quest_state_sequence` | 원문 카운터의 단계별 대화 연결 |
| `required_state_gate`, `required_all_state_gate` | 해당 위치에서 검사하는 필수 상태 |
| `map_connection`, `map_connection_after_guard` | 원문 지도 전환과 그 앞의 판정 |
| `dialogue_guidance`, `recommended_story_route` | 등장인물의 안내·예지에 따른 집필 권장 흐름 |
| `parallel_objective` | 앞뒤 순서를 고정하지 않은 목표 |
| `optional_hub_connection` | 피난처 방문 등 선택·보급 경로 |
| `map_connection_not_story_order` | 이동 사실만 있으며 시점을 정하지 않은 연결 |

EVIL GOD와 MUDDY의 봉인 두 개는 순서를 바꿀 수 있지만, 라바 게이트는 두 상태를
모두 요구한다. 황금의 봉인·Hidra·Huge Dragon은 상태를 직접 대입하는 경로가 있어
의뢰를 먼저 듣는 권장 이야기 순서와 게임의 모든 가능한 순서가 같지는 않다.

이번 자료는 정적 소스 분석이다. 게임 실행·전 경로 플레이·지도 보행 경로의 완전한
검증을 했다는 의미는 아니다. 특히 ANOTHER LORE를 본편 어느 시점에 배치할지는
추가로 결정해야 한다. 모든 원문 문자열을 보존했다는 검사와 실제 플레이 순서의
검증은 구분한다.

## 재생성·검증

```bash
python3 tool/export_story_material.py
python3 tool/export_story_material.py --check
PYTHONPATH=tool python3 -m unittest discover -s tool/tests -p test_export_story_material.py
```

퀘스트 분류와 근거는 `tool/story_quest_plan.json`에 있다. 생성 JSON 파일은 다시
생성하면 덮어쓰므로 집필 초안을 그 안에 직접 저장하지 않는다. 예를 들어
`story_material/drafts/`의 별도 파일에 JSON을 복사하거나 별도 초안을 만든다.
추출 도구는 게임의 `lib/`, `assets/`, 원작 소스와 기존 게임 fixture를 변경하지 않는다.

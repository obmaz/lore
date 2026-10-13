# 집필 구성과 원고

이 문서는 **현재 원고·구성의 위치, 판본, 수정 파일과 생성 명령**을 안내합니다.
에이전트 준수 규칙은 [AGENTS.md](AGENTS.md)에만 두고, 설정의 형식은 상위 사전 문서에 둡니다.

큰 구성 → 큰 이야기 검토 → 소단락 주요 내용 → 의미 있는 분기 → 장면·소편 → 한 소편 본문 순으로 진행합니다.
설정은 상위 사전을 참조하고, 이야기 구성과 새 본문은 이 폴더에서 관리합니다.
구체 작업 제약은 [AGENTS.md](AGENTS.md), 원고 형식은 [공용 스키마 안내](../authoring/README.md)를 따릅니다.

## 바로 읽기

- [소설 제작실 · 웹에서 열기](https://obmaz.github.io/lore/novel/studio/): 원고 읽기, 목차·장별 구성/그래프,
  분기 구조, 출판 순서, 인물·세계 설정 검색과 원본 JSON을 같은 화면에서 조회합니다.
  [HTML 하나](studio/generated/index.html)로 오프라인에서도 사용할 수 있습니다.
  사용자 요청으로 별도 주소에 공개된 작가용 전편 스포일러·읽기 전용 화면입니다.
  기존 독자 읽기본에는 포함하지 않습니다. [사용·갱신 안내](studio/README.md).

- [전편 15장 곁가지 · 선택하며 읽기](https://obmaz.github.io/lore/novel/studio/#/reading?document=side-adventures.html):
  각 장 두 개, 총 30개 창작 모험과 후속 반응. 5개 모험에는 참여 후 해결 방법을 고르는 중첩 선택이 있습니다.
  본줄기는 기존 기본 경로의 주요 내용입니다. [집필 원본과 검사 범위](side-stories/README.md).
  결합 그래프는 41개 결정·89개 실행 옵션이며 그중 자동 우회 5개는 독자 선택지에서 제외합니다.

- [소제목 트리·장별 흐름도](previews/publication-flow.html): 장·소단락·선택·합류·후속 반응을
  연결한 오프라인 SVG 도식. [Markdown 트리·Mermaid](publication/generated/flow.md),
  [구조 JSON](publication/generated/flow.graph.json), [종이책 경로 예시](publication/generated/linear-editions.json).
  전편 스포일러를 포함한 출판 준비 자료이며, 상세 본문·최종 경로·페이지 승인은 아닙니다.
  [설정과 갱신 방법](publication/README.md).

- [소단락 분기 시스템](previews/branch-system.html): 실행 가능한 JSON의 조건·선택 뒤 내용·
  상태 변화·후속 반응·필수 합류. [정의 JSON](branches/series.json),
  [실행 검사 결과](previews/branch-system-report.json), [공용 결정 양식](templates/branch-decision.template.json).
  현재 6개 결정·14개 선택지·96개 완주 경로를 구현했다. 주요 내용은 초안이며
  원문 대사 전체의 새 런타임 반영이나 독자 웹 적용이 끝난 것은 아니다.

- [15장 소단락 주요 내용](previews/chapter-subsections.html): **88개 이야기 단위**의
  시작 상황·주요 사건·필수 결과와 다음 연결. 분기 여지는 29곳만 후보로 표시했다.
  [집필 JSON](storyboard/chapter-subsections.json), [공용 양식](templates/chapter-subsections.template.json).
  이 파일은 원본 구성이며 실제 분기 정의는 별도 시스템에 있다. 상세 본문은 미완성이며
  기존 첫 챕터 읽기 화면은 유지한다.

- [원작 전체 스크립트 · 15장 연결 초고](previews/source-connected.html): 원작을 우선해
  장면 앞뒤의 산문과 모든 원문을 연결한 작가용 판본. 장별 목차로 이동할 수 있다.
  [원문 포함 JSON](source-connected/manuscript.json), [반영표](source-connected/coverage.json),
  [편집 입력](storyboard/source-connected.plan.json). 조건부 원문과 기술용 부록도 보존한다.

- [15장 큰 이야기 초고](previews/chapter-stories.html): 각 장의 시작·갈등·전환·마무리,
  서진의 변화와 다음 장으로 향하는 이유를 이어 쓴 **작가 전용 줄거리**.
  [원본 JSON](storyboard/chapter-stories.json), [공용 양식](templates/chapter-stories.template.json).
  전편 스포일러를 포함하며 상세 본문이나 새 분기를 완성했다는 뜻은 아니다.

- [전편 15장 큰 구성](previews/chapters.html): 작가 전용 챕터 제목과 필수 사건 목록.
  [원본 JSON](storyboard/chapters.json), [공용 양식](templates/chapters.template.json).

- [첫 챕터 · 선택하며 읽기](previews/chapter01-interactive.html): 최신 선택형 판본.
  [분기 구조와 집필 규칙](interactive/README.md), [작가용 분기 안내](previews/chapter01-branches.html).
  아래 기존 기본 경로 읽기본은 보존 판본이며 새 선택·동료 설정은 별도 오버레이에 있다.
- **첫 소편:** [1-1 · 돌아오겠다는 말](previews/menace-01.html) /
  [주점 방문 기억이 있는 경로](previews/menace-01-tavern.html). 약 4,100~4,350자이며 첫 의뢰 수락에서 멈춘다.
- [1-2 · 성문 앞의 목소리](previews/menace-02.html) /
  [동행 거절](previews/menace-02-declined.html). 소편별로 집필·푸시하며 아래 진행표를 갱신한다.
- [1-3 · 빛이 남아 있는 곳](previews/menace-03.html) /
  [동행 거절 경로](previews/menace-03-declined.html).
- [1-4 · 어둠의 중심](previews/menace-04.html) /
  [동행 거절 경로](previews/menace-04-declined.html).
- [1-5 · 돌아온 사람들](previews/menace-05.html) /
  [동행 거절 경로](previews/menace-05-declined.html).
- [1-6 · 다음 부탁](previews/menace-06.html) /
  [동행 거절 경로](previews/menace-06-declined.html).
- [도입부터 1장까지 · 동행 수락](previews/first-journey.html): 첫 탐사·귀환 보고와 다음 부탁까지.
- [도입부터 1장까지 · 동행 거절](previews/first-journey-declined.html): 같은 의뢰, 다른 현재 동료.
- [주점 방문 후 1장 · 수락](previews/first-journey-tavern.html) /
  [거절](previews/first-journey-tavern-declined.html): 앞서 들은 증언이 이동·귀환 문단에 이어진다.
- [전편 스토리보드](previews/storyboard.html): 작가 전용, 전편 스포일러 포함.
- [도입부 · 성주 직행](previews/prologue.html): 첫 의뢰 제시 직전까지의 시범 본문.
- [도입부 · 주점 방문](previews/prologue-tavern.html): 선택 방문을 한 경로의 시범 본문.

HTML을 다운로드해 브라우저로 열면 된다. 서버·게임·외부 네트워크가 필요 없고,
인쇄/PDF 저장 버튼은 제거했다. GitHub 파일 화면 자체는 HTML을 실행하지 않는다.
HTML은 편집 대상이 아니라 JSON에서 생성한 스냅샷이다.

## 수정 위치

| 대상 | 편집 입력 | 기준/생성물 |
| --- | --- | --- |
| 장 제목·필수 사건 | `storyboard/chapters.json` | `chapters.schema.json` |
| 큰 이야기·감정선·다음 장의 이유 | `storyboard/chapter-stories.json` | `chapter-stories.schema.json` |
| 소단락 주요 내용·필수 결과·분기 후보 | `storyboard/chapter-subsections.json` | `chapter-subsections.schema.json` |
| 소단락의 실제 선택·효과·합류 | `branches/series.json` | [분기 시스템](branches/README.md) |
| 장별 곁가지 모험·선택·후속 문단 | `side-stories/series.json` | [곁가지 안내](side-stories/README.md), 결합 생성물은 읽기 전용 |
| 출판용 소제목 트리·그래프·경로 예시 | `publication/flow.plan.json` | [출판 구성](publication/README.md), `publication/generated/` |
| 원작 연결 배열·전후 산문 | `storyboard/source-connected.plan.json` | `source-connected/`, `previews/source-connected.html` |
| 기본 원고와 장면 계약 | `quests/*.json`, `quests/*.continuity.json` | [연속성](../continuity/README.md) |
| 소편의 장면 목록·종료 지점 | `episodes/*.json` | 실제 본문은 복제하지 않고 `node_ids`로 참조 |
| 첫 챕터 선택형 보충 원고 | `interactive/chapter01.json` | [독자 분기 안내](interactive/README.md) |
| 표시명·설정·관계 | 상위 `reference/`·`characters/`의 편집 입력 | [참조 사전](../reference/README.md) |
| 읽기 배열 | `reading.json` | `previews/`는 생성물이며 직접 집필하지 않음 |
| 통합 제작 화면의 메뉴·안내 | `studio/studio.plan.json` | [제작실](studio/README.md), `studio/generated/` |

새 파일은 `templates/`의 해당 공용 양식을 사용합니다. `authoring/examples/`는 검증용 구조 예시이며
현재 초고는 `writing/quests/`에만 있습니다.
원문·설정·제목·본문을 다른 JSON에 복사하지 않고 안정된 ID로 참조합니다.

## 구성 단계의 경계

전편의 상세 집필 전 점검은 [전편 인과 검토 JSON](storyboard/causal-review.json)에 있습니다.
15장별 의뢰·수행·보고·이동 조건, 선택 방문의 기억, 병렬 목표와 공개 시점을 원문 연결 구간에
대조했습니다. 이 검토는 상세 집필의 출발점이며 기존 초고의 자동 승인이나 모든 경로의 정사를 뜻하지 않습니다.
제작실의 원본 JSON 메뉴에서도 `writing/storyboard/causal-review.json`을 조회할 수 있습니다.

메인 구성은 4막·15장입니다. `required_beats`는 전부 필수이며 선택 이야기는 다음 본줄기 전에 합류합니다.
두 봉인은 순서가 자유여도 둘 다 필수입니다. `after`는 논리적 선행, `reading_next`는 편집상 읽기 배열입니다.
원작의 선택 방문을 본줄기에 채택한 것은 창작 편집 추가로 표시합니다.

큰 이야기는 네 줄거리 문단과 질문·변화·다음 행동의 이유를 씁니다. 장 제목은 `chapter_id`,
필수 사건은 `beat_refs`, 원문 구간은 `source_section_refs`로 연결합니다. 주의를 `continuity_limits`에 두고
줄거리에 검증 설명을 반복하지 않습니다. 성공 시나리오 초고가 실패·도주·배타 원문의 삭제를 허용하지 않습니다.

소단락은 목적·수행·결과가 있는 이야기 단위입니다. `entry/main_content/outcome`으로 쓰고
`completes_beats`로 필수 사건을 한 번씩 배치합니다. `macro_revision`이 바뀌면 재검토합니다.
`variation_scope/rejoin_before`는 분기 여지와 합류, `carry_keys`는 설계 제안입니다.
후보를 실행 상태로 간주하지 않으며 실제 선택·원문 반영표·지식 공개·동행/장비 계약을 연결해야 합니다.

원작 연결 판본은 모든 보존 문구 발생·출력 사건·장면을 반영표와 대조합니다.
반복·빈 문구·배타 응답·무작위 시험·재방문·메타 서사·기술 부록을 남깁니다.
`original`은 원문, `display_parts`는 이름을 치환한 각색이며 미정 변수를 지어내지 않습니다.
선형 편집 배열이나 모든 원문 보존을 단일 플레이·모든 분기 실행의 증명으로 취급하지 않습니다.

## 현재 집필 범위

첫 퀘스트 기본 경로의 여섯 소편은 긴 본문 초고입니다. 소편별 작업 목록은
[episodes/lore_menace.json](episodes/lore_menace.json)에 있습니다. 첫 챕터 선택형 보충 판본은 별도로 관리합니다.
후속 장의 큰 줄거리·소단락·일부 작가용 실행 분기는 상세 장편 본문의 완성을 뜻하지 않습니다.
공용 문체는 [project.json](project.json)의 `viewpoint`, `tone`, `style`에서 편집합니다.
제작실의 작업 현황 → `공용 문체 기준`에서도 읽고 원본을 열 수 있습니다.
시점·어조·문장 호흡·묘사·대화·감정·유머·피할 표현과 작업 단계별 기준을 정의합니다.
문체 수정은 이후 집필에 적용하며 기존 원고의 자동 재집필을 뜻하지 않습니다.

원고 승인·문체 검토와 공유 상점/훈련/회복·무작위 전투 및 후속 퀘스트 집필은 별도 범위입니다.

기본 작업량은 한 소편이며 약 3,500~6,500자를 출발 목표로 삼습니다. 반복으로 분량을 채우지 않고
움직임·감각·대화·작은 변화를 펼칩니다. 독자의 선택은 장면을 읽은 뒤 실제 행동·경험·동행·장비·
후속 반응이 달라지는 순간에 둡니다. 자동 연결과 진행 버튼은 서사적 선택으로 꾸미지 않습니다.

## 이름과 원문 참조

표시명은 `../reference/names.json`에서 변경하고 `build_reference.py`로 재생성합니다.
제목·본문·대사·선택지에는 `characters/equipment/abilities/bestiary/terms`의 구조화된 `ref`를 씁니다.

```json
[
  {"ref": {"catalog": "characters", "id": "protagonist", "particle": "은/는"}},
  {"text": " 걸음을 멈췄다."}
]
```

원문은 `source.literal_ids`의 순서로 연결합니다. 이름 `bindings`의 `start/end`는 연결한 원문 기준이며
`end`는 미포함입니다. 보존 원문은 `source_exact`, 치환 읽기본은 `source_adaptation`입니다.
고정 이름 복사·문자열 치환·`reference_text` 해제로 검사를 우회하지 않습니다.

## 집필과 갱신

소단락의 골격은 `storyboard/chapter-subsections.json`에서 관리합니다. `entry`는 시작 조건,
`main_content`는 수행 사건, `outcome`은 필수 결과입니다. `logic.goal`은 이번 묶음의 목적,
`logic.obstacle`은 해결할 장애 또는 사실·상태를 혼동하지 않기 위한 주의,
`logic.next_reason`은 이 결과가 다음 행동을 요구하는 이유입니다. 9장처럼 병렬인 목표의
인계 이유는 특정 동굴을 먼저 갔다고 가정하지 않습니다. 원문·필수 사건·분기 조건은 기존 참조로 보존합니다.

1. 원문 조건과 큰 구성·현재 선택 경로를 확인합니다.
2. 한 소편의 본문과 연속성 계약을 함께 편집합니다. 새 서사·해석·설정의 출처를 표시합니다.
3. 원문 반영표·실제 동행·들은 증언·소지품·후속 인계를 검사합니다.
4. 검증과 경로별 읽기 검토 후 생성 읽기본을 갱신합니다. 구조 검사만으로 자동 승인하지 않습니다.

### 동료 합류 전용 장면

`companion-events/series.json`은 동료가 실제로 합류한 경로에서만 열리는 전용 장면과 후속 반응의 원본입니다.
시작 동료 4명과 선택 동료 `skeleton`, `spica`를 각각 하나의 이벤트로 관리하며, `companion_ref`·`equipment_ref`는
안정된 참조 ID를 사용합니다. 이벤트는 본줄기 상태를 변경하지 않고 `party.members` 또는 `party.optional`의 실제 합류를 조건으로 합니다.
원작 자료에 합류 장비가 확정되지 않은 경우 장비를 창작하지 않고 `equipment_ref: null`로 남깁니다.

명령은 `novel/`에서 실행합니다. 전체 검사와 테스트는 [상위 README](../README.md#설치와-검증)를 따릅니다.

```sh
python -X utf8 tools/writing.py episode --episode-id menace-02
python -X utf8 tools/writing.py reading --reading-key first-journey-declined
python -X utf8 tools/writing.py new-quest --quest-id lastditch_pyramid
python -X utf8 tools/writing.py validate
python -X utf8 tools/writing.py export
python -X utf8 tools/writing.py export --check
```

`new-quest`는 빈 원고·계약만 만듭니다. `reading/episode`는 실제 앞선 경로를 재생하고
해당 종료 지점의 상태·지식을 계산합니다. 미래 경로를 먼저 재생하고 문단만 숨기지 않습니다.
새 원작 연결 산문을 수정했으면 `tools/source_story.py export`, `validate`, `export --check`도 실행합니다.

# 스토리보드와 새 원고

설정은 상위 사전, **이야기 구성과 본문은 이 폴더**에서 관리한다.
챕터별 큰 이야기 → 구성 검토·다듬기 → 소단락 주요 내용 → 의미 있는 분기점 → 장면·소편 구성 → 한 소편 집필 순으로 발전시킨다.
독자용 큰 구성은 **4막·15장**이고 장 제목과 필수 메인 사건을 먼저 정했다.
기존 18개 퀘스트 자료 분류는 보존하며 선택 성전 이야기는 별도로 관리한다.
막 구분·감정선·장면 연결은 창작 제안이지 원작 진행의 강제 순서가 아니다.

## 바로 읽기

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
├── storyboard/chapters.json        15장 제목·필수 메인 사건·선택 이야기 분리
├── storyboard/chapter-stories.json  15장 큰 이야기·감정선·다음 장의 원인
├── chapter-stories.schema.json     큰 이야기의 참조·창작 표시·보류 단계
├── templates/chapter-stories.template.json  공용 큰 이야기 양식
├── storyboard/chapter-subsections.json  88개 소단락·주요 이야기·분기 여지
├── chapter-subsections.schema.json  소단락의 필수 결과·인계·분기 보류 형식
├── templates/chapter-subsections.template.json  공용 소단락 양식
├── branches/series.json            실제 조건·선택·상태 변화·후속 반응·병렬 순서
├── branches.schema.json            공용 분기 실행 형식
├── templates/branch-decision.template.json  공용 결정 예시
├── storyboard/source-connected.plan.json  원작 우선 장면 배열·전후 연결 산문
├── source-connected.schema.json    원작 연결 입력의 형식
├── source-connected/               원문 포함 연결 JSON·반영표·생성 무결성 기록
├── chapters.schema.json           챕터 큰 구성과 장면 참조 검증
├── quests/prologue.json            도입부 시범 본문 · 6장면, 6선택
├── quests/prologue.continuity.json  시범 원고의 경로 기억과 계약
├── quests/lore_menace.json          1장 「돌아오는 일」 · 첫 퀘스트 기본 경로 초고
├── quests/lore_menace.continuity.json  영입·증언·탐사·보상·다음 부탁의 기록
├── episodes/lore_menace.json        한 퀘스트를 나눈 여섯 소편의 작업 목록
├── reading.json                    전체 연결 네 경로 + 1-1만 읽는 두 경로
└── previews/                       읽기 전용 HTML와 무결성 매니페스트
```

기존 `authoring/drafts/prologue.json`은 보존한 구조 예시다. 새 집필 원고가 아니다.

## 큰 구성부터 집필하기

`storyboard/chapters.json`은 소설의 메인 구성을 정의하고 `series.json`은 원작 퀘스트별
근거·후보·주의점을 보존한다. 메인 장은 모두 `mandatory: true`이며 장 안의
`required_beats`를 전부 지난 뒤 다음 장으로 넘어간다(`exit_requires_all: true`).
선택 이야기는 다음 필수 사건 전에 합류하고 실제 선택한 동료·장비·경험만 이어받는다.
핵심 사건의 `after`는 선행 사건 ID다. 9장의 두 봉인은 서로의 선행 조건이 아니므로
어느 쪽을 먼저 진행해도 되지만 둘 다 끝내야 10장의 게이트로 이어진다.

1장은 도입과 첫 의뢰를 합쳐 「부탁을 받은 사람들」이다. 여섯 핵심 사건 묶음의
`scene_nodes`가 현재 선택형 본줄기 17개 장면을 전부 순서대로 참조한다. 읽기 화면의
장 제목도 이 중앙 JSON에서 가져온다. 후속 장에는 별도 큰 줄거리 초고가 있지만,
상세 본문은 아직 없는 `outline_only`이며 장면 참조는 `null`이다.
미래 본문·선택 검증이 끝났다고 주장하지 않는다.

12장의 피난처 방문은 이 소설에서 필수 메인으로 채택한 **창작 편집 추가**다.
원작 방문 조건이나 시설 이용·영입을 강제로 바꾸지 않는다. 선택 성전의 입구는
보존된 입장 코드에서 확인했고, 소설 방문·합류 시점은 별도 선택 이야기로 보존한다.
마지막 대결의 결과별 원문도
하나의 승리/사망 사실로 합치지 않는다. 제목·필수화·묶음은 `authored`, 원문 사건
요약은 근거를 연결한 `inferred`로 구분한다. 전편 목차와 요약은 작가용이며 웹에는
현재 장의 제목과 본문만 들어간다.

### 큰 이야기를 먼저 다듬는 단계

`storyboard/chapter-stories.json`은 기존 사건 목록을 대신하지 않는 **큰 이야기 초고**다.
15개 장마다 네 줄거리 문단(`opening`, `escalation`, `turning_point`, `ending`),
당장의 질문, 겪은 뒤의 변화, 다음 장으로 이어지는 이유를 썼다. 장 제목은 복제하지 않고
`chapter_id`로 중앙 구성에서 가져오며, 필수 사건 44개도 `beat_refs`로 연결한다.
이름·장비·지명은 `ref`, 새 감정선·연결은 `origin: authored`와 추가 메타데이터를 쓴다.
원작 조건과 공개 시점의 주의사항은 줄거리 문장 대신 `continuity_limits`에 둔다.

현재 개정은 **논리적으로 이어지는 메인 이야기**를 만드는 단계다. 60개 문단을
상황 → 목표 → 수행 사건 → 결과 → 다음 행동으로 다시 썼다. 선택 메뉴, 장식적인 묘사,
구체 전술은 넣지 않았다. `source_section_refs`는 원작 연결 판본의 근거 구간을 가리키며,
존재하지 않거나 다른 장에 속한 ID는 거부한다. 구간의 모든 배타 응답을 겪었다는 뜻은 아니다.
동료 영입은 보류하고, 주 진행에 채택한 원작 선택 방문은 집필 조건에 추가 표시한다.

4막의 중심은 탐사 성공과 다음 의뢰 → 위협 해결과 열쇠·배움 → 두 봉인과 결전 조건 →
피난처·사칭 확인·마지막 도움과 이별이다. 같은 보고를 반복하는 대신 각 보고가
다음 지역의 신뢰·열쇠·이동을 어떻게 바꾸는지 구별했다.
황금의 봉인은 **찾아 지키는 것**, 늪의 두 봉인은 **둘 다 풀어야 하는 것**으로 구별한다.
9장의 초고는 두 탐색을 차례로 서술하지만 원작의 순서 자유는 유지한다.

8장에서 읽은 반신반인 조건은 14장의 실제 계급 변화로 이어진다. 마지막 도움 코드가
68·67번 인물을 표시하며, 내부 템플릿은 각각 성주와 에인션트 이블이다. 그 뒤
현재 일행을 `class=10`으로 바꾼다. 이를 도움 약속의 이행으로 연결한 것은 근거 있는
집필 해석이며, 개별 대사를 말한 인물은 특정하지 않는다. 새 무제한 힘·자동 부활을 만들지 않는다.

현재 초고는 성공하며 본줄기를 진행하는 시나리오를 중심으로 잇는다.
도주·실패·다른 동료 경로를 삭제하거나 모든 선택이 승리한다고 정한 것이 아니다.
원작 조건별 대사 전체를 상세 집필할 때 발생 ID별 반영표로 연결해야 하며,
지금의 줄거리를 대사 전체가 들어간 완성 본문이라고 표시하지 않는다.

분기와 세부 설계는 `deferred`다. 먼저 장의 동기·갈등·변화·인과관계를 검토한 뒤,
실제 행동·동료·경험·후속 반응을 바꾸는 분기만 만든다. 상태 조회나
“아니오 → 다시 생각 → 돌아가기”는 분기로 만들지 않는다.
새 큰 구성 때문에 기존 첫 챕터의 본문·선택 경로·저장 형식을 덮어쓰지 않는다.
큰 이야기 검토 → 소단락 주요 내용 → 의미 있는 분기 설계 → 장면 계약 → 소편 분할 →
한 소편 집필/검증/푸시 순으로 진행한다.

### 소단락 주요 내용과 분기 경계

큰 이야기를 `storyboard/chapter-subsections.json`의 **88개 소단락**으로 나눴다.
각 소단락은 목적을 수행하고 결과가 생기는 이야기 묶음이다. 대사 한 줄이나
단순 이동 클릭을 뜻하지 않으며, 기존 `episodes/`의 긴 소편과도 자동으로 같은 단위가 아니다.
지금은 주요 내용 초안으로, 선택지·꾸밈 묘사·상세 본문을 쓰는 단계가 아니다.

각 항목은 `entry`(시작 상황), `main_content`(주요 이야기), `outcome`(필수 결과)를 가진다.
중앙 구성의 장 제목을 참조하고 부모 큰 이야기의 `continuity_limits`를 상속한다.
`macro_revision`이 달라지면 재검토해야 한다. 필수 사건 44개는 `completes_beats`에 한 번씩
배치하고, 부모의 원문 구간 42개를 `source_section_refs`로 이어 누락을 확인한다.
원문을 요약으로 대체하지 않으며, 기술 문자열·조건부 대사·선택 성전 등은 기존 연결 판본에 남는다.

분기 여지 29곳은 `branch.mode: candidate`로 표시했다. `variation_scope`에는 접근법·교류·
동료의 역할이 어떻게 다른 이야기와 후속 반응을 만들 수 있는지 적었다. 후보를 모두
선택지로 만들거나 여러 선택을 반복 순회시키지는 않는다. 필수 사건을 전달하는 나머지
59곳은 `fixed`로 두었다. 성주 접견·보고·봉인 완료·정체 공개 등을 선택으로 건너뛸 수 없다.

후속 분기는 `outcome`을 유지하고 `rejoin_before`가 가리키는 다음 소단락 전에 합류한다.
`carry_keys`는 현재 동행·장비·물자·실제로 겪은 경험을 기록할 **설계 제안**이다.
기존 실행 상태에 이미 연결된 변수가 아니며, 구현 단계에서 원문 발생 ID·지식 공개 시점·
원고의 연속성 계약을 먼저 연결해야 한다. 만남을 자동 영입으로, 사전을 소지품으로 바꾸지 않는다.

`reading_next`는 현재 편집 배열이고 `after`가 논리적 선행이다. 9장은 두 봉인의 소단락
묶음이 서로 독립이며 마지막 소단락은 두 묶음이 모두 완료된 뒤에만 이어진다.
따라서 나중에 어느 탐색을 먼저 하게 하더라도 두 필수 결과를 지켜야 한다.
검사는 구조·참조·보존 범위를 확인할 뿐 산문의 의미나 실제 분기 실행 완료를 증명하지 않는다.

### 원작 우선 연결 판본

큰 줄거리에서 빠졌던 쌍둥이 성의 직접 경유, 부상당한 용사와 특공대 지휘관,
간접 공격·초자연력 전수와 재방문, 예언서·섬의 차원 이론·성전의 의지,
피난처의 제작자 메타 서사를 원문과 연결했다. 동료의 개인적 복수처럼 원문이
확인해 주지 않는 해석은 걷어냈다.

`source-connected.plan.json`의 44개 구간은 **편집상 선형 배열**이다. 원작 타이틀의
다른 지구로의 초대문·운명의 대륙 글도 첫 장 앞머리에 연결했다. 기존 15장과
필수 사건 44개는 유지하며, 원문 조건을 평탄화하지 않는다. 두 봉인의 순서는
읽기 배열일 뿐 원작 강제 조건이 아니다. 성전 입구는 지도 1의 `at(20,6)`이며
지도 27로 들어간다. 이전 ‘접근 미확정’은 정정하지만 자동 방문·지식 습득은 아니다.

연결 JSON의 `sections`에는 창작 표시가 있는 전후 산문과 **실제 원문 출력·문구**가 있다.
`original`은 정확한 원문, `branch_context`는 원작 조건, `literal_ids`는 발생 ID다.
`display_parts`는 이름을 참조 사전으로 바꿔 읽는 각색이고 원문은 바꾸지 않는다.
`player[1].name`은 주인공 참조로 표시하며 다른 동료·수치 변수는 임의로 채우지 않는다.
`script_index`에는 모든 원작 장면의 코드·상태 변화·호출도 보존한다.

한 사람이 수락과 거절을 동시에 말하거나, 매 무작위 시험에서 모든 문항을 보았거나,
도주 뒤 승리의 이별까지 이어졌다는 뜻이 아니다. 배타 응답·실패·재방문은 조건부
원문 묶음으로 구분해 모두 읽고 검토할 수 있게 했다. 공통 시설은 실제로 이용한
경로에만 끼워 넣고, 전투·마법 UI와 기술 문자열은 부록으로 남긴다.
원작의 오탈자·과학적 주장·컴퓨터 문답·프로그래머 대사도 삭제하지 않는다.

반영표는 현재 보존 스냅샷의 2,483개 문구·1,674개 출력·307개 장면과 대조하며
누락·중복·변조·조건 누락을 거부한다. 이것은 원작 보존과 배치 검사이지, 모든 분기의
실행·단일 플레이 가능성·최종 문체 완성의 증명이 아니다. 새 선택지보다 원문 보존을
우선한 단계이며 기존 첫 챕터 선택소설의 실행 경로는 바꾸지 않았다.

```bash
python3 tools/source_story.py export
python3 tools/source_story.py validate
python3 tools/source_story.py export --check
python3 tools/writing.py export
python3 tools/writing.py export --check
```

생성 JSON은 직접 편집하지 않는다. 연결 산문·배치는 입력 계획을 수정하고 재생성한다.
생성물을 수동 변경했으면 덮어쓰기를 거부하므로 먼저 그 변경을 보존하고 입력으로 옮긴다.
작가용 연결 판본과 전편 원문은 독자용 `/novel/` 웹에 통째로 게시하지 않는다.

새 시범은 제한적 3인칭을 **미승인 문체 제안**으로 사용한다. 성별·나이·직업·초기 장비와
동료 네 명은 이 기존 기본 판본에서 임의로 확정하지 않았다. 최신 선택형 첫 챕터에서는
사용자 지정 새 동료·직업·무기를 참조 사전에 추가했다. 수감소 접근은 원작 미확정과
구별한 창작 연결로 처리하며, 원작 대사·영입/이탈 조건은 별도로 보존한다.

## 현재 집필 범위

1장은 14장면·15선택을 여섯 소편으로 묶었다. **첫 퀘스트 기본 경로의 여섯 소편을
모두 긴 본문으로 집필했다.** 각 소편을 따로 집필·확인·푸시했으며, 문체와 의미는
아직 편집 검토 전인 초고다. 소편별 상태는 아래 표와 `episodes/lore_menace.json`에 기록한다.
성주의 의뢰 → 첫 출구의 동행 요청 →
남서쪽 이동 → 동굴 중심부 확인 → 귀환·보상 → 다음 지역 안내까지의 기본 경로다.
스켈레톤의 첫 합류 요청은 원작의 성 출구 사건이며 수락·거절을 따로 보존한다.
수락을 정사로 고정하거나 미작성 동료의 슬롯을 자동 교체하지 않는다.
기존 기본 판본에서 보류했던 무기고·수감소·선택 금/방패는 새 선택형 판본에서 다룬다.
무작위 전투·공유 상점/훈련/회복 UI 전체는 여전히 별도 범위다.
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
| 1-5 돌아온 사람들 | 귀환·보고와 보상 | 긴 장면으로 집필한 미승인 초고 |
| 1-6 다음 부탁 | 다음 지역의 부탁·작별 | 긴 장면으로 집필한 미승인 초고 |

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

# 인물 참조 JSON

[registry.json](registry.json)에 주인공·주요 인물·선택 동료·시작 동료 후보·악당·보스
48개의 카드를 넣었다. 대사가 없는 적의 세부 성격과 원문에 없는 나이·외모는 미상이다.
원작의 모든 군중 NPC에 개인 전기를 창작한 설정집은 아니다.

각 인물은 이름 대신 안정된 ID로 참조한다. 예: `lord_ahn`, `mad_joe`, `initial_merlin`.
본문의 `speaker`, 등장 인물 `cast`, 사건 참여자·관계 대상도 같은 ID를 사용한다.

| 필드 | 의미 |
| --- | --- |
| `canonical_name` | 원어 이름. 원문 발생 ID 또는 원본 적 레코드로 확인 |
| `korean_name` | 의미 번역이 아닌 별도 한국어 음역. 네크로맨서·스켈레톤 등 |
| `display_name` | 편집용 이름·역할 표기. `display_name_metadata`로 추가 표기임을 구분 |
| `aliases` | 기존 별칭. 원어 이름의 변경을 뜻하지 않음 |
| `biography` | 나이·성별·종족·직업·외모·윤리적 성향. 항목마다 출처/미상/추가 메타 포함 |
| `source_facts` | 원문에서 확인한 역할·증언·초기 직업과 능력 등 |
| `writing.traits` | 집필용 성향과 반응 방식 |
| `writing.speech` | 말투와 표현 습관 |
| `writing.goals` | 동기·목표. 아직 정하지 않았다면 빈 배열 |
| `writing.boundaries` | 서술 시 지켜야 할 제한 |
| `relationships` | 다른 인물 ID와 관계의 근거·확정 여부 |
| `source_excerpts` | 카드 근거 범위의 원문 출력 문자열. 주변 인물의 말도 포함할 수 있음 |
| `resource_refs` | 장비·마법·적 템플릿 사전의 안정된 ID. 현재 소지/습득을 뜻하지 않음 |

정보마다 `origin`, `status`, `evidence`, `metadata`를 둔다. 원작 요약은
`source_adaptation`, 대사에서 해석한 성향은 `inferred`, 원작에 없는 새 설정은
`authored`다. 해석과 새 설정은 `metadata.addition: true`이며 미승인 `proposed`로
남긴다. 음역은 새 표기이므로 `transliteration`으로 구분한다. `confirmed` 음역은
표기를 정했다는 뜻이지 원작에 한국어 이름이 있었다는 뜻이 아니다.
`source_facts`에는 근거 있는 원작 사실/증언 요약만 넣는다. 능력 수치만으로
용감함·선량함·나이를 추정하지 않는다.

예를 들어 다음을 Joe의 성향 후보로 넣었다.

```json
{
  "field": "temperament",
  "value": "함께 떠날 기회를 놓치지 않으려 한다.",
  "origin": "authored",
  "status": "proposed",
  "evidence": [],
  "metadata": {
    "addition": true,
    "kind": "new_setting",
    "note": "원작에는 명시되지 않은 집필용 성향 후보",
    "knowledge_policy": "author_reference_not_character_knowledge"
  }
}
```

나이·외모는 `biography`에, 신념·반응 습관은 `writing.traits`에 같은 구조로 추가한다.
`value: null`, `origin: unknown`, `status: unknown`, `metadata.kind: unknown`은
미상이지 임의의 나이를 채우라는 지시가 아니다.
일시적 부상·소지품·생존·영입 상태는 인물 카드에 고정하지 말고 경로 상태와 사건에
기록한다. 원문에 이름이 없는 인물은 `canonical_name.value: null`을 유지한다.
고유 이름을 창작하면 `origin: authored`로 구분한다.

변경은 [분석 입력](../reference/analysis.json)의 `enrichment` 또는 `new_characters`에서
하고 `python3 tools/build_reference.py`로 재생성한다. 문구 요약·음역·해석 입력은
생성 시 메타데이터를 붙이며, 창작 나이는 `biography_overrides.age`에 완전한 claim을
넣는다. 창작 성향은 `writing_additions.traits`, 관계는 `relationships_additions`에
완전한 claim을 넣어 표시를 생략하지 않는다. 기존 v1 카드의 보존 입력인
`preserved_profiles`는 마이그레이션 근거이며 현재 출력 카드가 아니다.
생성 도구가 해당 인물과 목록의 `revision`을 올린다. 장면 계약의
`character_dependencies`가 이전 버전을 가리키면 재검토가 필요하다고 보고한다.
`cast`에서 등장 조건을 정하며 본문의 화자가 그 경로의 등장 인물인지도 검사한다.
실제 이름·말투가 산문에서 잘 지켜졌는지는 별도의 서사 검토가 필요하다.

원작 이름과 근거는 내부 [원문 스냅샷](../materials/scripts.json)으로 검증한다.
원본 게임 파일을 다시 읽지 않는다.

가짜 네크로맨서(`false_necromancer`)와 최종 네크로맨서(`necromancer`)는 같은 표시
이름을 써도 별도 ID다. 드라코니안 동료와 아키드라코니안, 히드라의 머리/드래곤의 꼬리,
스핑크스와 기반 Sprite 템플릿도 구분한다. 이름이 Evil인 존재의 실제 윤리적 성향을
이름만으로 정하지 않는다. 증언·차원 이론·마법사에 대한 자평도 시점별 검토가 필요하다.
예언서가 설명하는 로드 안의 선의 상징, 에인션트 이블의 역할, 주인공의 탄생 관계는
`prophecy_testimony`로 보존했다. 이 전편 정보가 카드에 있다고 도입부터 주인공이
알고 있는 설정으로 쓰지 않는다.

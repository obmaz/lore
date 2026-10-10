# 인물 참조 JSON

[registry.json](registry.json)에 주인공·주요 인물·선택 동료·시작 동료 후보·악당·보스
53개의 카드(원작 참조 49 + 집필용 시작 동료 4)를 넣었다. 관계 35건을 분석했고, 역방향을 포함해 카드에는 48개의 관계
링크가 있다. 로어 헌터의 배우자라고 말하는 익명 주민도 별도 카드로 보존했다.
대사가 없는 적의 세부 성격과 원문에 없는 나이·외모는 미상이다.
원작의 모든 군중 NPC에 개인 전기를 창작한 설정집은 아니다.

선택형 첫 챕터의 시작 동료는 `party_woodcutter`, `party_hunter`, `party_cook`,
`party_magician`이다. 사용자가 이름과 직업을 지정한 새 집필 인물이므로
원작 이름·음역·나이는 미상으로 두고 집필 이름/직업을 `authored/new_setting/proposed`로
표시했다. 원작 초기 후보 10명은 그대로 보존한다. 카드의 장비 참조와 실제 동행/소지는
별개이며 `writing/interactive/chapter01.json`의 경로 상태가 실제 소지를 정한다.

각 인물은 이름 대신 안정된 ID로 참조한다. 예: `lord_ahn`, `mad_joe`, `initial_merlin`.
본문의 `speaker`, 등장 인물 `cast`, 사건 참여자·관계 대상도 같은 ID를 사용한다.
새 `writing/` 원고의 본문 속 이름도 구조화된 `ref`를 쓴다. 임시 주인공 집필 이름은
`reference/names.json`에서 변경하고 생성 도구로 반영한다. 원작 주인공 고유 이름과
한국어 음역은 미상을 유지하며, 이름만으로 성별·나이·직업을 정하지 않는다.

| 필드 | 의미 |
| --- | --- |
| `canonical_name` | 원어 이름. 원문 발생 ID 또는 원본 적 레코드로 확인 |
| `writing_name` | 새 집필 이름. 선택적인 창작 claim이며 원어 이름을 덮어쓰지 않음 |
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
| `disclosure` | 작가 전용 원본, 공개용 ID/이름, 필드 공개 조건 |
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
넣는다. 창작 성향은 `writing_additions.traits`에 완전한 claim을 넣고, 관계는
[relationships.analysis.json](relationships.analysis.json)에서 공개 정책과 함께 작성한다.
옛 `relationships_additions`를 사용하면 생성 도구가 중단하므로 새 형식으로 옮긴다.
기존 v1 카드의 보존 입력인
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

## 스포일러 공개와 복선

이 문서와 원본 JSON은 작가 전용이다. **원본 카드를 집필 프롬프트나 독자 화면에
그대로 전달하지 않는다.** 상세 작업 규칙은 [AGENTS.md](AGENTS.md)에 있다.

관계에는 `id`, `target`, `relation_type`, `truth_type`, `claimant`, `branch_condition`과
`disclosure`가 있다. 직접 사건·증언·문서 설명·추론·창작을 구분하며, 증언의
`confirmed`는 그렇게 말한 사실을 확인했다는 뜻이지 세계의 진상을 확정한 것이 아니다.
조건부 영입·이탈·공격은 고정 관계에서 현재 상태로 자동 반영하지 않는다.

`disclosure.spoiler`는 `minor/major`, `after_events`는 공개 체크포인트 목록이다.
체크포인트 ID와 시점은 편집자가 추가한 정책이며 원작의 게임 이벤트 ID가 아니다.
퀘스트/장 번호가 커졌다는 이유로 자동 공개하지 않고 경로 사건의 `reveals`를 사용한다.
다른 분기로 건너뛴 사건은 공개하지 않는다. 한 퀘스트 안에서도 전투 전 소개와
정체 공개, 최종 결전 소개와 결말은 다른 체크포인트다.

`foreshadowing`에는 허용 시점과 검토된 복선 claim만 둔다. 공개 전에는 진상,
관계 대상/유형/ID, 공개 예정 시점을 출력하지 않고 허용된 복선만 전달한다.
복선은 새 집필 해석이므로 추가 메타데이터와 `proposed` 상태를 유지한다.

```bash
python3 tools/characters.py --view writer --character lord_ahn --events castle_arrival
python3 tools/story_continuity.py --route enter_courtyard visit_lord
```

첫 명령의 이벤트 목록은 작가가 지정한 미리보기 조건이다. 독자 공개를 인증하는
기능이 아니다. 둘째 명령은 실제 선택 경로에서 발생한 사건의 공개만 계산한다.
`characters.py --view writer`는 대상 인물 지정이 필수여서 미래 명단을 일괄 출력하지 않는다.
정체를 암시하는 내부 ID/제목은 공개용 핸들/이름으로 가린다.

필터된 카드의 `source_facts`는 `disclosure.fact_after`에 지정된 필드만 공개한다.
미지정/새 필드는 계속 숨기며, 생애·성향·장비 묶음은 `after_events` 뒤에 열린다.
비어 있는 공개 목록은 기본 비공개다. 공개 전 빠진 필드는 원작 미상이 아니라
아직 공개되지 않은 정보일 수 있다. 원문 발췌·별칭·작가 비고는 항상 제외한다.
상세 원문은 해당 장면의 원고/원문 대응으로 읽고 전편 발췌를 몰아서 프롬프트에 넣지 않는다.

이것은 데이터 투영/집필 검증이지 원본 파일의 접근 제어나 산문 의미 검증이 아니다.
원본 JSON을 직접 공유하면 진상도 공개된다. 복선의 강도와 최종 산문은 별도 검토한다.

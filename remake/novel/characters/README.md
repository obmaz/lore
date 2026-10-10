# 인물 참조 JSON

[registry.json](registry.json)에 주인공·주요 인물·선택 동료·시작 동료 후보 24개의
카드를 넣었다. 전 등장인물의 완성된 설정집은 아니며 미작성 성향·동기는 빈 배열이다.
주인공과 Joe에는 작성 방식의 예시인 창작 성향 제안을 넣었다.

각 인물은 이름 대신 안정된 ID로 참조한다. 예: `lord_ahn`, `mad_joe`, `initial_merlin`.
본문의 `speaker`, 등장 인물 `cast`, 사건 참여자·관계 대상도 같은 ID를 사용한다.

| 필드 | 의미 |
| --- | --- |
| `canonical_name` | 고정 이름. 원작 그대로인 이름은 원문 발생 ID로 확인 |
| `display_name` | 집필 자료에 표시할 이름·역할 표기 |
| `aliases` | 별칭·번역 표기. 원문 이름의 변경을 뜻하지 않음 |
| `source_facts` | 원문에서 확인한 역할·증언·초기 직업과 능력 등 |
| `writing.traits` | 집필용 성향과 반응 방식 |
| `writing.speech` | 말투와 표현 습관 |
| `writing.goals` | 동기·목표. 아직 정하지 않았다면 빈 배열 |
| `writing.boundaries` | 서술 시 지켜야 할 제한 |
| `relationships` | 다른 인물 ID와 관계의 근거·확정 여부 |

정보마다 `origin`과 `status`를 둔다. 원작에서 얻은 요약은 `source_adaptation`, 새로
정한 성향은 `authored`다. `proposed`는 미승인 집필 제안이고 `confirmed`는 검토를
거친 설정이다. `source_facts`에는 원작 근거가 있는 확정 요약만 넣는다. 새로운
성향은 `writing`에 둔다. 원작 수치가 높다는 이유로 용감함·선량함 등을 추정하지 않는다.

예를 들어 다음을 Joe의 성향 후보로 넣었다.

```json
{
  "field": "temperament",
  "value": "함께 떠날 기회를 놓치지 않으려 한다.",
  "origin": "authored",
  "status": "proposed",
  "evidence": []
}
```

나이·외모·상처·가족·신념도 같은 구조로 `writing.traits` 등에 추가할 수 있다.
일시적 부상·소지품·생존·영입 상태는 인물 카드에 고정하지 말고 경로 상태와 사건에
기록한다. 원문에 이름이 없는 인물은 `canonical_name.value: null`을 유지한다.
고유 이름을 창작하면 `origin: authored`로 구분한다.

변경 시 해당 인물의 `revision`과 목록의 `revision`을 올린다. 장면 계약의
`character_dependencies`가 이전 버전을 가리키면 재검토가 필요하다고 보고한다.
`cast`에서 등장 조건을 정하며 본문의 화자가 그 경로의 등장 인물인지도 검사한다.
실제 이름·말투가 산문에서 잘 지켜졌는지는 별도의 서사 검토가 필요하다.

원작 이름과 근거는 내부 [원문 스냅샷](../materials/scripts.json)으로 검증한다.
원본 게임 파일을 다시 읽지 않는다.

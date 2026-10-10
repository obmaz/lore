# 소설 집필과 참조 자료 작업 지침

- **기본 작업 위치와 수정 범위는 저장소 최상위의 `novel/`이다.**
  `original/novel/`이나 `remake/novel/`에 자료를 만들지 않는다. 사용자가 별도로
  요청하지 않으면 `original/`, `remake/`, 게임 빌드·배포·환경설정 파일은 수정하지 않는다.
- 집필 자료 변경은 이 저장소의 `origin/main`에 푸시한다. 커밋에는 해당 작업의
  `novel/` 변경만 포함하고, 다른 작업의 변경이나 보류한 stash를 함께 반영하지 않는다.
- 새 스토리보드·본문은 `writing/` 아래에서 공용 템플릿을 이용해 작성한다.
  `authoring/drafts/`의 기존 예시는 보존한다. 이름·장비·마법·지명은 본문에 복사하지
  않고 `ref`의 분류와 안정된 ID로 연결한다. 집필 이름은 `reference/names.json`에서
  변경하고 생성된 카드/읽기본을 갱신한다. 보존 원문은 치환하지 않는다.
- `novel/`는 독립 집필 패키지다. 검증·집필 도구는 내부 JSON만 읽는다. 원작 데이터의
  신규 수입은 사용자가 별도로 요청할 때만 수행하며, 원본 게임이나 다른 프로젝트의
  도구에 대한 실행 의존성을 다시 만들지 않는다.
- **원작에 없는 내용은 추가할 때 반드시 메타데이터로 표시한다.** 인물의 나이·외모·
  성향·과거·동기·관계, 무기와 마법의 새 효과·제약·설정에도 동일하게 적용한다.
  `origin: authored`, `metadata.addition: true`, `metadata.kind: new_setting`,
  `status: proposed`를 기본으로 하고 `metadata.note`에 추가 이유를 적는다.
- 산문/사건 스키마가 항목별 `metadata`를 지원하지 않으면 기존 `origin: authored`
  표기를 반드시 쓰고 집필 메모에 추가 설정 목록을 기록한다. 인물·참조 사전의
  구조화된 추가 설정은 위 메타데이터를 생략할 수 없다.
- 스크립트 해석·추론은 `origin: inferred`, `metadata.addition: true`,
  `metadata.kind: interpretation`으로 표시한다. 근거가 있어도 추론을 원작의 확정
  사실로 바꾸지 않는다. 원작 요약은 `source_adaptation`, 정확한 원문 값은
  `source_exact`로 표시하고 근거를 내부 원문 위치/레코드로 연결한다.
- 원문에 없는 나이 등은 `value: null`, `origin: unknown`, `status: unknown`으로
  기록할 수 있다. **레벨·능력 수치·사망 카운터를 나이로 해석하지 않는다.**
- 원어 이름을 보존하고 한국어 음역을 별도 필드로 둔다. `Necromancer → 네크로맨서`,
  `Skeleton → 스켈레톤`처럼 소리를 옮기며 의미 번역이나 새로운 이름으로 대체하지
  않는다. 새 음역은 `metadata.kind: transliteration`으로 표시한다.
- 인물의 증언, 신념, 세계의 확정 사실을 구분한다. 참조 카드에 있는 전편 정보를
  등장인물이 이미 아는 것으로 쓰지 않는다. 지식은 경로의 사건 기록으로 전달한다.
- 인물 원본 `characters/registry.json`은 **작가 전용 마스터**다. 집필 프롬프트나
  독자용 인물 소개에 통째로 넣지 않는다. `characters/AGENTS.md`의 공개 정책에
  따라 `story_continuity.py`의 필터된 카드 또는 `characters.py --view writer`를 쓴다.
- 관계를 추가할 때 관계 유형, 증언/문서/직접 사건/추론/창작의 구분, 조건부 경로,
  스포일러 등급, 공개 체크포인트, 허용한 복선을 반드시 함께 기록한다. 공개 전
  복선에서는 진상·관계 대상·관계 유형을 직접 또는 부정형 경고로 누설하지 않는다.
- 동료의 영입·이탈·사망, 부상·소지품, 기술 습득은 경로 상태다. 인물 카드의 고정
  성격·직업과 섞지 않는다. 가짜 네크로맨서와 최종 네크로맨서를 같은 인물로 합치지 않는다.
- 원작 마법은 실패·저항·사용 조건을 보존한다. 이름만 보고 화염 피해·즉사·무제한
  부활 등 효과를 추가하지 않는다. 새 효과는 창작 메타데이터를 붙여 별도 검토한다.
- 인물·참조 항목을 수정하면 해당 항목과 목록의 `revision`을 올리고, 의존 장면을
  재검토한다. 승인 해시가 달라진 원고를 승인된 것으로 취급하지 않는다.
- 자동 생성 자료는 수동 편집을 묵시적으로 덮어쓰지 않는다. 분석 근거·집필 해석은
  `reference/analysis.json`에서 관리하고, 생성 도구는 기준 해시가 다르면 멈춘다.
- 변경 후 `python3 tools/characters.py`, `python3 tools/reference.py`,
  `python3 tools/validate_story_authoring.py`, `python3 tools/writing.py validate`와
  `PYTHONPATH=tools python3 -m unittest discover -s tests`
  를 `novel/` 안에서 실행한다. 게임 빌드는 필요 없다.

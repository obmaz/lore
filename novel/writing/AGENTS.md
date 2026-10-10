# 새 집필 작업

상위 `novel/AGENTS.md`를 따른다. 설정과 보존 원문은 상위 사전을 참조하고,
스토리보드·새 본문·퀘스트별 사건 기록은 이 폴더에 작성한다.

- 공용 `templates/`를 이용해 전편 보드 → 퀘스트 목표/갈등/분기 → 장면 → 본문
  순으로 작성한다. 전체의 세부 문장을 미리 확정하지 않는다.
- 본문, 대사, 선택지, 제목의 이름·장비·마법·지명은 **구조화된 `ref`**로 쓴다.
  `characters/protagonist` 같은 ID는 이름 변경으로 바꾸지 않는다.
  `reference/names.json`의 집필 이름을 문자열로 본문에 복사하지 않는다.
  `reference_text: true`를 끄거나 문자열 치환으로 검사를 우회하지 않는다.
- 표시명 변경은 `reference/names.json`에서 관리하고 인물/참조 자료를 재생성한다.
  원작 이름·음역·`materials/`의 보존 문자열은 이름 변경을 위해 수정하지 않는다.
- 원문 대사는 발생 ID의 순서 있는 `source.literal_ids`로 참조한다. 이름 위치에는
  원문 문자열 기준 `start`/`end`와 `ref`를 연결한다. 원문 이름이 동일한 가짜/진짜
  인물은 사건 근거로 구별하고 이름만 보고 합치지 않는다.
- `source_exact`는 보존 원문을 뜻한다. 표시명으로 치환된 읽기본은
  `display_origin: source_adaptation`이며 원작 한국어 대사였다고 주장하지 않는다.
- 새 연결 서사·감정·행동·공간·대사는 `provenance.origin: authored`와 이유를 기록한다.
  원작에 없는 고정 인물/장비 설정은 상위 사전에 완전한 추가 메타데이터를 등록한다.
  보드의 `authored_fields`는 새 감정선·연결 제안의 표시다. 원작 사실로 승격하지 않는다.
- 보드의 배열은 집필 제안이다. 원작 `materials/quests.json#/route_edges`의 강제 조건,
  병렬 목표, 선택 동료·이탈, 접근 미확정 경로를 우선한다. 후보 인물/공개 사건 목록은
  그 인물의 영입이나 정보의 자동 공개를 의미하지 않는다.
- 원고와 `*.continuity.json`을 함께 편집한다. 등장 인물, 들은 증언, 모르는 사실,
  상태 변화, 원문 필수 블록과 다음 파일 인계를 검사한다. 사전의 장비 참조는 소지품이 아니다.
- 공개 전에는 인물 카드 마스터나 전편 보드를 프롬프트/독자 화면에 통째로 넣지 않는다.
  `writing.py preview`의 경로별 필터를 쓰며 미래 사건으로 과거 장면을 먼저 열지 않는다.
- 새 원고는 `outline`/`draft`, 새 사건은 `proposed`로 둔다. 구조 검사를 통과했다고
  원문의 접근 조건, 산문의 의미, 모든 분기가 검증되었다고 주장하거나 자동 승인하지 않는다.
- `previews/`는 읽기 전용 생성물이다. 변경 후 `python3 tools/writing.py validate`,
  `python3 tools/writing.py export`, `python3 tools/writing.py export --check`와
  상위 지침의 테스트를 실행한다. 생성된 HTML에서 집필하지 않는다.

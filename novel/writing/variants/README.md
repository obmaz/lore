# 문체별 본문 레이어

[공용 A/B 기준](../styles.json)을 매 집필 전에 읽는다. A 정의는 기존 `project.json#/style`을
참조하며 현재 원고는 그대로 A다. B 정의는 `styles.json#/profiles/B`이며 빠른 호흡·행동과
판단 중심의 웹소설형 산문이다. 특정 작품의 문장·설정·시스템을 복제하지 않는다.

현재 A는 1~3장, B는 1~2장 초고다. 문체·의미·출판 승인은 별도 검토 대상이다.
[B 1장](B/chapter01.json)은 공통 첫 장의 창작 블록 274개에 대해 별도 본문을 제공한다.
[B 2장](B/chapter02.json)은 창작 블록 77개를 별도로 집필한다. [연결 인덱스](B/series.json)는
집필한 순서의 장 ID와 파일 참조만 기록하며 공통 목차·사건·분기를 복제하지 않는다.
이것은 독립 분기 그래프나 새로운 게임 데이터가 아니다. `tools/prose_variants.py`는 검증된
A의 집필한 장을 읽고 각 장의 블록 `text`와 창작 메모만 바꾼다. 제목·노드·조건·원작 인용·선택·효과·공개·
동료·장비는 공유한다. 인물·무기·지명은 같은 안정된 `ref`를 사용하므로 개명이 양쪽에 반영된다.

`base_source_sha256`는 검토한 원고를 고정한다. 첫 장은 원고·오버레이, 후속 장은 해당 퀘스트·
연속성 계약·공통 장 연결의 해시다. 공통 사건이나 A 원고가 바뀌면
생성이 중단된다. 변경을 B에 대조한 뒤에만 해시를 갱신한다. `style_revision`이 달라도 중단된다.
누락 블록·원문 인용의 덮어쓰기·모르는 ID·다른 장 블록의 주입·중간 장 건너뛰기·중복 인덱스를 거부한다.
B 미집필 장을 A 본문으로 채우지 않는다. 장별 파일이 모두 있어도 인덱스에 연결하지 않은 장은 읽기본에 넣지 않는다.
공통 골격이나 분기 변경이 필요하면 먼저 원래 원고·계약에서 검토한다.

후속 B 장은 `prose.schema.json`의 공용 레이어 형식을 사용한다. `chapter_id`는 공통 장 ID,
`chapter_limit`는 그 장의 번호다. 모든 창작 블록을 집필하고 해당 장의 의존 해시를 검토한 뒤
`B/series.json`과 `styles.json#/profiles/B/written_chapters`에 같은 연속 장 목록을 등록한다.
문체 revision 1은 유지하며 등록 목록·인덱스 revision만 올린다. 기존 B 장을 자동 재집필하지 않는다.

읽을 판본에는 A와 B 두 개만 나온다. `/novel/`의 선택 화면은 기본 A이며
`?edition=B`로 B에서 시작할 수 있다. 판본을 바꾸면 처음부터 읽는다. 경로 저장의
fingerprint가 달라 다른 판본의 경로 파일을 무심코 불러오지 않는다. 두 HTML 모두 외부 요청과
작가용 마스터 없이 오프라인으로 동작한다. 제작실의 목차·장별 그래프는 하나를 공유한다.

```bash
python tools/prose_variants.py
python tools/writing.py validate
python tools/writing.py export
python tools/writing.py export --check
```

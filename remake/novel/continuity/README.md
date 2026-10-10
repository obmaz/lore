# 연속성 관리와 생성형 집필

공유 설정은 [canon.json](canon.json), 퀘스트별 장면 계약과 사건 후보는
[프롤로그 연속성 자료](../authoring/drafts/prologue.continuity.json)에 보관한다.
본문은 기존 `prologue.json`을 유지한다. 선택 경로마다 다음 장면의 집필 자료를 계산한다.
인물의 이름·성향·관계는 [../characters/registry.json](../characters/registry.json)에서
참조한다. `canon.json`에는 인물 이름을 중복 저장하지 않는다.

## 사실과 지식

`world_fact`는 세계의 사실, `testimony`는 누군가의 증언, `belief`는 인물의 믿음이다.
`confirmed`인 증언은 **그렇게 말했다는 사실**을 확인한 것이지 그 내용이 세계의
진실이라는 뜻은 아니다. 미확정 사항은 `unknown`, 충돌하는 주장은 `disputed`다.
증언·믿음에는 소유 인물을 반드시 기록한다.

`initial_knowers`는 시작부터 알고 있는 인물이다. 새 지식은 경로 사건의
`knowledge_gained`로 추가하며, 누구에게 어떤 방법으로 알았는지 남긴다.
같은 일행이라는 이유로 모든 지식을 자동 공유하지 않는다.

공통 설정에는 경로에 무관한 사실을 넣고 영입·사망·방문·약속은 경로 상태와 사건에
넣는다. 서로 배타적인 경로의 사건을 합치지 않는다. 사실을 수정하면 해당 사실과
설정집의 `revision`을 올린다. 현재 확정 설정의 근거는 원작 소스다. 새로운 창작
설정의 근거 형식은 이후 승인된 원고 참조로 확장할 수 있다.

## 장면 계약

모든 장면에 `contracts`를 작성한다. `before/after`는 진입 전·선택 후 조건,
`allowed_state_changes`는 수정 가능한 상태다. 부상·소지품·약속도 상태로 정의하면
허용되지 않은 변경을 검사할 수 있다. 예시는 해당 상태를 아직 정의하지 않았다.

`must_include_block_ids`는 실제 표시될 필수 본문이며 `author_note`로 대체할 수 없다.
`must_not_assert`는 확정하면 안 되는 사실을 생성 자료에 전달한다. 산문 의미를
자동 판독하지 않으므로 이 목록은 서사 검토에도 사용한다. `knowledge_required`는
장면 전체에서 인물이 알아야 할 정보를 검사한다. 문단별 조건은 기존 `when`을 쓴다.

`dependencies`는 참고한 사실 ID와 버전이다. 수정 시 영향받는 장면이 `needs_review`에
표시된다. 빠뜨린 의존성은 추적할 수 없으므로 검토 때 근거의 충분성도 확인한다.
줄거리 요약은 참고 자료이며 사실 기록을 대체하지 않는다.

## 집필과 확정

1. 앞서 선택한 경로로 현재 상태·사건·지식을 계산한다.
2. 관련 설정, 조건부 본문, 장면 계약, 이전 기록, 미해결 사건을 생성 자료로 전달한다.
3. 새 본문과 사건·지식·상태 변경 후보를 작성한다.
4. 조건 검사와 원문 보존·산문 모순·인물 동기의 검토를 수행한다.
5. 통과한 본문과 연속성 자료를 같은 커밋으로 확정한다.

미검토 사건은 `proposed_events`, 지식은 `knowledge_is_provisional: true`로 출력한다.
승인된 자료만 `committed_events`로 계산한다. 초안을 다음 장면에 참고할 수 있지만
확정된 과거로 혼동하지 않는다. 원고가 미완성인 현재 예시는 모두 초안이다.

승인은 원고·설정 버전과 실제 내용의 SHA-256에 묶는다. 버전을 올리지 않고 내용을
바꾸어도 승인 검사가 실패한다. `input_fingerprints.continuity`는 승인 정보를 담은
`review`를 제외한 내용의 해시다. 승인에는 원문 보존 완료, 미해결 사항 해소,
사건 후보 승인도 필요하다. 해시 일치가 산문 의미를 검증했다는 뜻은 아니다.

## 경로별 생성 자료

```bash
# 바로 성주를 만남
python3 tools/story_continuity.py --route enter_courtyard visit_lord

# 수감자 증언을 듣고 Joe를 영입한 뒤 성주를 만남
python3 tools/story_continuity.py --route enter_courtyard visit_prison accept_joe visit_lord

# 주점도 방문한 뒤 다음 퀘스트 경계까지 진행
python3 tools/story_continuity.py --route enter_courtyard visit_tavern remember_veteran visit_prison accept_joe visit_lord trust_lord
```

JSON 출력은 현재 장면, 본문·선택지, 상태, 장면 전후 기록, 사건·인물별 지식,
관련 설정, 미해결 사건과 재검토 사항을 포함한다. 지정한 경로만 계산하며 모든
경로를 자동 탐색하지 않는다. 이전 기록은 구조 자료이므로 실제 생성 호출에는
필요한 직전 완성 원고도 제공한다. 도구는 읽기 전용이며 모델 호출·승인 변경·
원고 작성·게임 실행을 하지 않는다.

퀘스트 경계의 `handoff_packet`에는 전달할 전편 상태, 지식과 사건 기록을 넣는다.
미승인 자료는 `provisional` 표시를 유지한다. 다음 퀘스트의 입력 로더는 아직 없으므로
자동 연결을 완료했다고 해석하면 안 된다. 집필 시 이 패킷을 초기값 대신 이어받는다.

명령은 `novel/` 폴더 안에서 실행한다. 필요한 Python 패키지는
`python3 -m pip install -r requirements.txt`로 설치한다.
원문은 내부 `materials/` JSON으로 확인하며 게임 소스를 읽는 복구 경로는 없다.

```bash
PYTHONPATH=tools python3 -m unittest discover -s tests -p 'test_story_continuity.py'
```

프롤로그의 미작성 대사와 감옥 접근 조건은 남아 있다. 경로별 동료·지식·사건,
설정 수정의 영향, 승인 후 변경 탐지를 위한 작동 예시다.

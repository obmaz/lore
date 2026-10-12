# 원작 내부 보관소

이 폴더는 **이미 가져온 원문 스냅샷**입니다. 현재 집필 원고가 아니며 원본 게임을 여는 경로도 아닙니다.
`file: LORETALK.PAS`, 줄 번호, `lib/game/...` 같은 문자열은 당시 자료의 출처 이름입니다.
도구는 이를 내부 JSON의 원문 목록에서 찾으며 외부 파일로 해석하지 않습니다.

| 파일 | 내용 | 실제 사용 |
| --- | --- | --- |
| `scripts.json` | Pascal 14개 파일의 `original_source` 전문·문자열·장면·조건 | 대사 렌더링·근거 검증·원문 연결 판본 |
| `quests.json` | 19개 원문 재료 묶음과 강제/병렬/선택 이동 관계 | 전편 구성·필수 사건·퀘스트 생성 |
| `quests/*.json` | 각 재료 묶음의 실제 대사·조건·출력문·추출 장면 | 원문 조사용 지역별 보기·스냅샷 해시 검사 |
| `progression.json` | 원작 상태 변경·지도 이동·중단/계속의 추출 기록 | 조사용 보관 자료·스냅샷 해시 검사 |
| `coverage.json` | 추출 누락·구문·문자열 집계 | 보관소의 범위 확인·스냅샷 해시 검사 |
| `enemy_templates.json` | 적 75개 레코드의 원본 바이트·이름·수치 | 인물/적 사전 생성·원문 값 검증 |
| `manifest.json` | 위 JSON의 해시, 원작 파일 해시와 개수 | 내부 보관소 변조·누락 검사 |

퀘스트별 보기와 `progression/coverage`는 집필 본문의 직접 원본이 아닌 **보관·조사용 자료**입니다.
재생 중 매번 해당 필드를 쓰지 않는 것과 불필요한 파일인 것은 다릅니다.
옛 `writing_workspace`·`bridge_slots`는 추출 당시 편집 주석이며 현재 집필 파일로 사용하지 않습니다.
현재 본문은 `../writing/quests/`, 실제 전편 분기는 `../writing/branches/series.json`입니다.
추출 주석을 정리하려고 원문 보관소와 해시를 다시 쓰거나 원문을 삭제하지 않습니다.

## `another_lore.json`의 예

`quests/another_lore.json`에는 지도 27의 실제 출력 사건 220개와 대사, 조건,
`original_statement`가 들어 있습니다. `evidence.file: LORETALK.PAS`는 원작을 여는 지시가 아니라
`scripts.json`의 `source_units`에서 `file == LORETALK.PAS`인 항목을 찾는 출처 키입니다.
그 항목에는 1,063줄의 파일 전문이 `original_source`로 이미 들어 있고 원작 바이트 해시로 검증합니다.
따라서 전문을 다시 가져오거나 모든 퀘스트 JSON에 중복 복사할 필요가 없습니다.

`novel/`에서 내부 원문만 조회합니다.

```sh
python3 tools/materials.py
python3 tools/materials.py source --file LORETALK.PAS
python3 tools/materials.py source --file LORETALK.PAS --start-line 741 --end-line 1053
python3 tools/materials.py quest --quest-id another_lore
```

출력은 JSON이며 `source_ref`는 내부 위치를 가리킵니다. Pascal 코드를 실행하지 않습니다.
전문은 원문 보존용, 이름 치환 읽기본은 각색용입니다. 원문을 집필 이름으로 덮어쓰지 않습니다.

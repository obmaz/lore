# LORE 완전 이식 실행 계획

## 완료 조건

각 기능은 원본 Pascal의 해당 분기와 대조하고, 화면 밖에서 같은 입력을 재현하는
시나리오 테스트를 통과해야 한다. `flutter analyze`, 관련 테스트, 전체 테스트를
확인한 뒤 변경 범위를 리뷰하고 그 기능만 커밋한다. 문구·좌표 개수 검사는
실행 결과 검증을 대신하지 않는다.

## 현재 순서

1. **파티 수치 효과 · 완료** — 스크립트 경험치와 직업 변경을 순수 상태 전이로
   옮겼다. 빈 슬롯은 건너뛰고 입력 파티를 변경하지 않는다. 성주 알현의 실제
   스크립트와 레벨 유지 시나리오를 검증했다. 커밋: `Apply script party rewards as pure state transitions`.
2. **장비 지급 · 완료** — 원본 `choosewhom`, 무기 없는 대원만 지급, 전투승
   무기 금지, 선택형 기사 무기 보정과 기본 무장의 직접 위력 대입, 방패·갑옷
   AC 계산을 한 규칙에서 적용한다. 취소·전투승 거절 시 획득 플래그와 1회
   스크립트 소모를 막고, 실제 장착 시에만 성공 메시지를 낸다.
   커밋: `Apply script equipment only after a valid party selection`.
3. **전투 후속 명령 · 완료** — 승리·도주·패배 후 `ScriptRun`의 후속 효과와
   진행 상태를 한 세션 명령에서 처리한다. Major Mummy의 세 번째 슬롯 생존·격퇴,
   Necromancer의 재도전·격퇴, 패배 종료를 실제 스크립트로 검증한다. 스크립트
   적용이 취소되면 후속 선택지와 포털 전환도 중단한다.
   커밋: `Resolve battle progress and script continuations together`.
4. **저장 계약 · 완료** — 스키마 버전 2를 기록하고 무버전·v1 저장을
   명시적으로 변환한다. 미래 버전은 원본 저장을 보존하며 읽기를 거절한다.
   실제 성 도전·경험치·장비·지도 타일·소모 이력의 왕복 시나리오를 검증한다.
   커밋: `Version save data and migrate legacy game slots`.
5. **분기 시나리오 목록 · 완료** — `PORT_BRANCH_AUDIT.md`에 27개 맵의
   현재 활성 297개와 비활성 294개를 출처·조건·거짓 탐침·효과별로 기록했다.
   원본 좌표 46개 추출 범위 안에서는 미커버 0개이고, 활성 규칙과 좌표가
   겹치지 않는 비활성 항목 77개를 다른 시스템 대조 후보로 분리했다.
   맵 11·13·26과 라바 게이트의 실제 참·거짓 분기를 실행 검증했다.
   커밋: `Audit script branches and record unresolved port candidates`.

## 다음 이식 순서

6. **포털 대조 · 완료** — 비활성 단독 후보 77개 모두 포털과 좌표가 겹친다.
   56개는 이동 목적지가 같고, 17개는 진입 거절 이동, 4개는 차단·플래그
   분기다. 맵 8 확인 전 위치 유지와 맵 21 수문장 상태 분기를 실행 검증했다.
   목적지 일치만으로 전투·플래그 효과까지 같다고 판단하지 않는다.
   커밋: `Reconcile disabled exit branches with portal routes`.
7. 나머지 비활성 217개도 활성 규칙과 **효과가 같은지** 대조한다. 좌표가
   겹친다는 사실만으로 이식 완료 처리하지 않는다. 첫 발견인 맵 12 황금의
   봉인에서 누락된 GAIA 단계 2 변경과 `< 2` 조건을 복원했고, 이후 성주 보상과
   저장 복원, 퀘스트 표시를 검증했다.
   커밋: `Restore GAIA progress when finding the golden seal`.
   맵 20 DEN7의 y=13 전투·복귀 네 단계에서 빠졌던 횃불 효과도 복원했다.
   커밋: `Restore DEN7 torch effect across final maze branches`.
   맵 11 출구와 맵 1 입구에서 LASTDITCH로 돌아올 때 원본은 현재 파티의
   Polaris를 확인해 NPC 타일을 길로 바꾼다. 기존 재진입 규칙의 과거 영입
   플래그 판정을 현재 파티 이름 판정으로 고치고, 영입 슬롯 취소 시 후속 타일
   변경을 중단한다. 커밋: `Match Polaris town tile to current party membership`.
8. 포털과 겹친 77개의 취소·수문장·부수 효과를 원본과 더 깊게 대조한다.
   맵 22 Ancient Evil 안내는 원본에서 맵 21 라바 게이트로 진입할 때만
   실행된다. 진입 출발 맵 조건을 스크립트 계약에 추가해 맵 5에서 들어올 때
   잘못 재생되던 안내를 막았다. 커밋: `Scope Ancient Evil speech to lava gate entry`.
   원본은 Lore Hunter 합류 후 맵 10의 (40,56)만 바꾼다. 맵 16의 범위 밖
   (40,56)을 바꾸려던 잘못된 진입 규칙을 제거하고, 모든 활성 고정 타일 변경의
   지도 범위를 검사한다. 커밋: `Remove unreachable Lore Hunter tile rule`.
9. 원본 `LORETALK.PAS`, `LOREENT.PAS`, `LOREBATT.PAS`의 분기 추출 범위를
   넓혀 스크립트·포털·전투와 상호 대조하고 남은 누락을 처리한다. 첫 단계로
   `LOREENT.PAS`의 지도 로드 27건을 추출해 출발 맵, 명시 좌표 16건, 목적지
   맵·좌표를 포털 데이터와 재실행 가능한 방식으로 대조했다. 현재 미매칭 0건이며
   전투·대사·거절·진입 후 타일 효과는 후속 대조 대상이다.
   커밋: `Audit original entrance routes against portal data`.
   다음으로 `LORETALK.PAS`의 리터럴 `at(x,y)` 148곳을 추출해 활성 talk
   스크립트·시설·대화 데이터와 대조했다. 제공자 없는 좌표는 0곳이다.
   조건·선택지·효과의 동등성은 별도로 검증한다.
   커밋: `Audit original talk coordinates against active data`.
   `LOREBATT.PAS PlusGold`는 전투 중 덮어쓴 적 능력치가 아니라
   `enemydata[E_number]`의 레벨·AC로 지급액을 계산한다. Major Mummy
   전투를 원본 수치로 재현해 보상 계산을 바로잡았다.
   커밋: `Calculate battle gold from original monster templates`.
   `PlusExperience`는 의식불명 적을 처형할 때 행동 가능한 일행 모두에게
   경험치를 주며, `CastOne`은 이 처형을 SP 소모보다 먼저 수행한다. 무기·단일·
   전체 마법에 파티 경험치 분기를 적용하고 전투 화면에서 파티 명단을 전달했다.
   커밋: `Share execution experience with active party members`.
   `CastAll`은 `CastOne`을 적마다 호출한다. 따라서 의식 있는 적마다 SP를
   계산·소모하고, 중간에 SP가 부족하면 남은 적은 공격받지 않는다. 의식불명
   적의 처형은 SP 없이 실행되도록 하고 선택창에 대상별 비용을 표시한다.
   커밋: `Charge all-target magic per conscious enemy`.
   `BattleESP` 염력 1~6단계는 적을 처음 의식불명으로 만들면 시전자에게,
   이미 의식불명인 적을 처형하면 행동 가능한 일행 전원에게 경험치를 준다.
   같은 적을 두 번 공격하는 시나리오로 보상과 ESP 소모를 검증했다.
   커밋: `Award battle experience for telekinetic knockouts`.
   염력 7~10단계는 적 전원에게 한 번씩 피해를 주고 기절·처형 보상을
   처리한다. 원본의 전체 공격 처형은 현재 반복 중인 적이 아닌 선택한 적으로
   `PlusExperience`를 호출하므로 그 수치·분배까지 재현하고 기록했다.
   전투 화면은 전체 적 목록을 엔진에 전달한다.
   커밋: `Apply telekinetic blast to every enemy`.

각 기능이 끝날 때 이 문서에 결과와 커밋을 갱신한다.

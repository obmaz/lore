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
   염력 13~14단계 중독은 원본 순서대로 적의 저항, 시전자의 ESP 명중을
   통과할 때만 적용한다. 저항·빗나감·성공을 고정 난수로 검증했다.
   커밋: `Respect resistance and accuracy for telekinetic poison`.
   염력 15~17단계 심장 정지는 저항 시 저항력 -5, 명중 실패 시 HP -5
   또는 HP 10 미만 기절, 성공 시 HP를 유지한 채 기절시키는 원본 분기를
   복원했다. 각 결과와 ESP 소모를 검증했다.
   커밋: `Restore telekinetic heart-stop branches`.
   염력 18단계 이상 환상은 원본처럼 저항 시 민첩 -5, 명중 실패 시 무효,
   성공 시 무기·마법 명중치 각각 -1을 적용한다. 몬스터 전투 인스턴스의
   해당 능력치를 변경 가능하게 만들고 세 경로를 검증했다.
   커밋: `Apply telekinetic illusion to monster combat stats`.
   염력 11~12단계 공포는 저항 시 저항력 -5, 명중 실패 시 인내력 -5,
   성공 시 사망 플래그만 설정한다. 현재 HP를 유지하는 원본 동작과
   인내력 변경에 따른 최대 HP 재계산도 검증했다.
   커밋: `Restore telekinetic fear and endurance effects`.
   독심술은 포섭 가능 여부 다음에 고레벨 적의 50% 거부 판정을 거치며,
   62번 적은 현재 레벨 19 대신 고정 레벨 17로 비교·명중 계산한다.
   거부·통과·동레벨의 세 경우를 검증했다.
   커밋: `Restore telepathy level resistance and Draconian exception`.
   독심술 성공 시 전투 화면에서 `join(E_number, 6)`을 호출해 6번 슬롯을
   즉시 교체한다. 동료 능력치는 전투 중 덮어쓴 적이 아닌 도감 원본에서
   생성하며, 62번 적의 비교 레벨 17과 실제 합류 레벨 19를 구분했다.
   커밋: `Recruit telepathy targets into the sixth party slot`.
   `BattleESP`는 직업 2·3·6 또는 `etc39_bit1` 보유자만 사용할 수 있다.
   전투 화면에서 스크립트 플래그를 엔진에 전달하고 거부 시 ESP가 소모되지
   않도록 했다. 기존 염력 테스트의 잘못된 기사 시전자를 마법사로 교체했다.
   커밋: `Gate battle ESP by class or granted access`.
   실제 전투 화면에서 초능력 메뉴의 독심을 선택해 적이 6번 슬롯에 합류하고,
   ESP 소모와 승리 콜백까지 이어지는 위젯 시나리오를 검증했다.
   커밋: `Verify telepathy recruitment through battle viewport`.
   적 `castattackone`·`castattackall`의 정신력 구간별 위력 배수가 기존의
   단순 나눗셈과 달라 단일 1/2/4/6/7/10, 전체 1/2/3/5/8로 복원했다.
   정신력 20·21 적의 실제 전투 피해를 고정 난수로 검증했다.
   커밋: `Match enemy spell power to original mentality tiers`.
   `enemycure`는 사망 플래그 해제, 의식불명 해제와 HP 1 복구,
   일반 HP 상한 회복을 순서대로 처리한다. 적 자기 치료는 등급 4의 1/2,
   등급 5~6의 1/3 확률과 `level * mentality div 4` 회복량을 따른다.
   커밋: `Restore enemy cure states and self-heal formula`.
   5단계 적은 단일 마법 경로를 고른 뒤에만 적 전체 치료를 검사하며,
   6단계 적은 파티의 평균 방어도가 4를 넘으면 방어도 약화를 먼저 시도한다.
   이후 빈사 적 셋 이상의 전체 치료와 최저 HP 파티원 대상 공격을 수행한다.
   선택 순서, 우선순위, 상태 회복과 `exist` 기준의 대상 수를 고정 난수로 검증했다.
   커밋: `Restore high-tier enemy support spells`.
   `SpecialCastAttack`의 소환은 원본 E_number에서 20을 뺀 계열의 몬스터를
   만들고, 적 최대 7칸에서 사망 슬롯을 재사용한다. 소환해도 시전자 행동은
   계속되며 전투 화면은 턴 시작 시의 적 수만큼만 순회한다. 원본 1번 예외,
   신규 슬롯·사망 슬롯, 후속 공격을 검증했다.
   커밋: `Restore enemy special-cast summoning`.

각 기능이 끝날 때 이 문서에 결과와 커밋을 갱신한다.

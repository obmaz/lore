# LORE 완전 이식 실행 계획

## 완료 조건

각 기능은 원본 Pascal의 해당 분기와 대조하고, 화면 밖에서 같은 입력을 재현하는
시나리오 테스트를 통과해야 한다. `flutter analyze`, 관련 테스트, 전체 테스트를
확인한 뒤 변경 범위를 리뷰하고 그 기능만 커밋한다. 문구·좌표 개수 검사는
실행 결과 검증을 대신하지 않는다.

## 원본 실행 추출 시범: 맵 17 경로

`tool/source_route_pilot.py`가 원본 `LORESPEC.PAS`의 맵 17에서 순서대로
실행되는 단순 좌표 규칙 4개를 추출하고, 실제 `DEN4.MAP`의 통과 가능한
좌표 122개에 적용한다. 생성된 `test/fixtures/map17_route_parity.json`을
`test/map17_source_route_parity_test.dart`가 현재 스크립트·지도 상태 전이와
비교한다. `python3 tool/source_route_pilot.py --check`는 원본·맵·기대 결과의
드리프트를 검사한다. 이 시범은 대사·전투·선택지까지 추출하지 않는다.

이 비교에서 `(72,80)`은 이식본 `y=73`, 원본 계산 `y=-1`로 달랐다.
원본의 지도 밖 결과를 그대로 재현하면 이동 상태가 유효하지 않으므로,
마지막 유효 위치 `y=6`에 머무는 예외를 명시하고 지름길 타일 변경은
원본과 맞췄다. 이후 맵을 확장할 때도 모든 안전 예외를 별도로 집계한다.
커밋: `Extract and compare map 17 Pascal route behavior`.

같은 추출기에 맵 20의 `map[x,y] = 0` 조건을 추가했다. DEN7의 통과 가능한
두 줄에서 현재 타일이 0인 상태와 원래 값인 상태를 각각 재생해 160개
시나리오의 목적지 지도·좌표·타일 보존을 비교한다. 이 범위에서는 차이가
발견되지 않았다. 커밋: `Compare DEN7 passages against Pascal tile gates`.

맵 19에서는 원본 레버 분기의 타일 변경 루프와 완료 비트 조건을 추출해
걷기 마법·봉인 완료의 참/거짓 네 조합을 실행 비교했다. 이 과정에서 완료 후
레버를 다시 밟으면 이식본이 복도와 무작위 방을 재설정하는 차이를 발견했다.
완료 상태에서는 원본처럼 레버 칸만 바꾸도록 분기를 나눴다.
커밋: `Preserve completed seal puzzle when replaying its lever`.

첫 번째 레버도 원본의 두 타일 변경과 걷기 마법 차단 분기를 추출했다.
두 레버의 여섯 상태를 원본에서 생성하고, 첫 레버가 연 칸에서 두 번째
레버까지 실제 지도 상태를 이어서 검증한다.
커밋: `Replay both EVIL SEAL levers from Pascal state changes`.

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
   같은 좌표에서 수호룡 승리 후 진흙 인간, 미궁의 주인 전투가 즉시 이어지는
   원본 흐름을 스크립트 참조로 연결했다. 앞 두 전투의 도주 시 한 칸 후퇴도
   복원하고, 세 번의 승리와 도주 분기를 실행 검증했다.
   커밋: `Chain DEN7 guardian battles after each victory`.
   맵 20의 Minotaur 전투는 원본이 전투 결과와 관계없이 1회 방문 플래그를
   기록한다. 횃불이 켜진 경우와 꺼진 경우 모두 도주 후 플래그를 설정하도록
   복원했다. 커밋: `Record DEN7 Minotaur encounter after retreat`.
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
   `SpecialCastAttack`의 6번 동료 정신 지배는 동료 능력치로 적을 만들고 원래
   파티 슬롯의 이름을 지운다. 전투 턴 판정을 원본 `exist` 조건으로 통일해
   빈자리와 HP 0 대원이 행동하지 않게 했다. 원본 `turn_mind(k,6)` 호출은
   함수 인자 순서와 어긋나므로, 6번 동료를 선택된 적 슬롯으로 바꾸는 의도에
   따라 안전하게 구현했다. 신규·사망 적 슬롯, 빈자리 턴 제외와 실제 전투
   화면의 소환 중 목록 확장을 검증했다.
   커밋: `Restore sixth-party mind conversion in battle`.
   `SpecialCastAttack`의 전체 즉사 저주는 이름 있고 생존한 대원 각각에게
   명중·행운 판정을 수행한다. 죽음·회피·빗나감 결과를 기록하고 살아남은
   대상이 있으면 원본처럼 기본 공격을 이어간다. 전멸 시에는 안전하게 턴을
   끝낸다. 커밋: `Continue enemy turn after group death curse`.
   일반 독·기절·즉사 특수 공격은 적 진영에서 행동 가능한 적이 넷 이상일 때
   발동한다. 명중 실패나 행운 회피도 해당 적의 행동을 소모한다. 살아 있는
   적 수·의식불명 제외·실패 후 추가 공격 금지와 상태별 대상 선정을 검증했다.
   커밋: `Gate enemy special attacks by active monster count`.
   `EnemyAttack`의 무기·마법 선택은 양쪽 명중치에 1000을 곱한 난수를
   비교하고, 공격력이 0이면 마법을 쓴다. 시전 등급 0에서 마법 쪽이 선택되면
   원본처럼 행동하지 않는다. 오크의 휴식·무기 공격과 Sprite의 강제 마법,
   기존 고정 난수 시나리오를 검증했다.
   커밋: `Match original enemy weapon and magic choice`.
   3·4단계 적 마법은 `random(행동 가능 대원 수) < 2`이면 단일 공격,
   그렇지 않으면 전체 공격을 한다. 행동 가능한 대원 둘·셋인 경우와
   단일 공격 대상 선택을 원본 분기대로 검증했다.
   커밋: `Scale enemy spell area choice with party size`.
   적 단일·전체 마법의 공통 피해 처리는 의식불명 수치와 사망 수치를 누적하고,
   의식불명 수치가 최대 HP를 넘으면 사망시킨다. 행동 불능 대원은 저항·방어도
   판정을 하지 않는다. 전체 공격은 이름 있는 대원 모두에 적용하고 빈 슬롯은
   안전하게 건너뛴다. 일반·의식불명·사망·빈 슬롯 경로를 검증했다.
   커밋: `Apply enemy magic to downed party members`.
10. **원본 근거 실행 명세 · 시작** — `test/fixtures/source_parity.json`에
    Pascal 파일·줄 범위·근거 문장과 같은 입력의 예상 효과를 기록한다.
    공통 실행기는 선택된 규칙, 승리·도주 후 전투, 플래그, 횃불, 이동, 타일
    변형을 단계별로 비교한다. 현재 맵 6·11·13·15·16·17·18·19·20·21·22에서
    32개 시나리오와 효과 검사 43지점, 미발동 3건을 검증한다.
    `tool/report_source_parity.py`가 맵별
    규모를 집계한다. 이는 원본 전체 분기의 완료율이 아니며, 예상 효과는
    사람이 원본에서 옮긴다. 커밋: `Add source-backed script parity scenarios`.
    맵 21 출구는 두 수문장을 격퇴한 뒤 일반 적을 피해 도주해도 원본에서
    완료 비트를 기록한다. 적 슬롯 집합의 격퇴를 도주 후속 조건으로 추가하고
    실제 전투 세션과 원본 근거 시나리오에서 검증했다.
    커밋: `Record SWAMP KEEP completion when guardians fall before retreat`.
    `BattleMode(FALSE)`의 적 선공을 전투 데이터 → 화면으로 전달한다. 맵 22의
    일반 습격·Death Knight·출구 전투에 적용하고, `BattleMode(TRUE)`인
    수문장 좌표는 파티 선공으로 남긴다. 연속 전투마다 화면 상태를 새로 시작한다.
    커밋: `Honor scripted enemy initiative in IMPERIUM MINOR`.
    맵 6 수용소, 11 Major Mummy, 13 Gorgon, 15 ArchiGagoyle의
    `BattleMode(FALSE)`를 활성·비활성 규칙 모두에 반영했다. 대표 분기의
    원본 근거와 엔진 실행 결과를 검증한다.
    커밋: `Restore enemy initiative in early scripted battles`.
    맵 16 Wivern, 18 감옥 수문장·Huge Dragon, 19 봉인 방은 적 선공으로
    복원했다. 맵 17 Hidra와 맵 19 복도 Crab God의 파티 선공은 원본대로
    유지했다. 활성·비활성 전투 규칙의 선공 분포와 대표 실행 분기를 검토했다.
    커밋: `Restore mixed initiative in midgame scripted battles`.
    맵 20 DEN7의 수문장·연속 전투와 맵 21 SWAMP KEEP의 출구·일반 습격은
    모두 원본 `BattleMode(FALSE)`로 적 선공이다. 전투 연쇄의 각 단계와
    도주 후속 분기를 실행 명세로 재검증했다.
    커밋: `Restore enemy initiative across DEN7 and SWAMP KEEP`.
    맵 22의 나머지 비활성 분기, 맵 23·25·26의 실제 전투, 맵 5·21·23의
    진입 수문장 전투에도 원본 선공을 전달한다. 맵 22의 y=25 수문장과 맵 25의
    최종 방 진입은 파티 선공으로 유지한다. 맵 23·25의 자동 추출 규칙에는
    `DisplayEnemies`만 있던 자리가 전투로 오인된 흔적이 있어 해당 항목은
    선공 이식 대상에서 제외했다.
    커밋: `Restore initiative through late-game gates and bosses`.
    일반 필드 조우는 원본처럼 이름이 있는 파티원과 적 전체의 민첩성 정수 평균을
    비교해 선공을 정한다. 동률이면 적 선공이다. 활성 스크립트 전체를 재귀적으로
    검사해 원본 파티 선공 네 지점 외의 전투가 적 선공을 명시하도록 회귀 검사를
    추가했다. 커밋: `Match field encounter initiative and audit active battles`.
11. **일반 조우 선택 복원 · 진행 중** — `EncounterEnemy`의 전투 전 도주는
    이름 있는 대원의 평균 행운과 적 평균 민첩성을 정수로 비교한다. 동률은
    도주 실패이며 빈 파티·적 목록은 안전하게 거절한다.
    커밋: `Calculate prebattle evasion from party luck`.
    적 명단·평균 민첩성과 교전·도주 두 선택을 표시하는 재사용 가능한 조우
    화면을 분리했다. 두 입력 콜백을 위젯에서 확인했다.
    커밋: `Add the prebattle encounter choice view`.
    필드에서 적을 만나면 먼저 조우 화면으로 전환한다. 교전은 평균 민첩성에
    따라 선공을 정하고, 전투 전 도주는 평균 행운 판정 성공 시 필드로 복귀한다.
    실패하면 원본처럼 적 선공 전투가 시작된다. 키보드 1·2와 화면 버튼을
    같은 선택 함수에 연결하고 조우 중 필드 이동을 막는다.
    커밋: `Connect encounter choices to field and battle flow`.
    교전·도주의 결과를 순수 `EncounterDecision`으로 묶었다. 빠른 파티가
    교전하면 파티 선공, 행운 높은 파티가 도주하면 즉시 탈출, 도주 실패는
    민첩성과 관계없이 적 선공이라는 세 경로를 독립 실행 검증한다.
    커밋: `Resolve encounter choices as pure decisions`.
    조우 난수원을 화면에 주입할 수 있게 해 필드 이동부터 선택·전투까지
    재현했다. 교전, 전투 전 도주 성공, 도주 실패 후 적 선공을 실제 화면에서
    검증했다. 이 경로에서 발견된 좁은 전투 화면의 상태 배너 넘침도 고쳤다.
    커밋: `Replay encounter choices through the game screen`.
12. **전투 턴 검토 · 진행 중** — 적 턴은 원본처럼 기절한 중독 적에게도 독을
    적용한 뒤 행동 가능 여부를 판단한다. 전투 화면이 기절 적을 미리 건너뛰던
    경로를 고치고 실제 위젯 턴에서 사망·승리를 검증했다.
    커밋: `Apply poison before skipping unconscious enemies`.
    `EndBattle`은 파티 전멸을 적 전멸보다 먼저 검사한다. 양쪽이 동시에
    행동 불능이면 금화가 지급되는 승리가 아닌 패배가 되도록 전투 화면의
    종료 순서를 고쳤다. 커밋: `Resolve simultaneous battle wipe as defeat`.
13. **원본 지도 효과 재검토 · 진행 중** — 맵 23 레버는 (12..39, 7..34)의
    타일 값이 0인 곳만 39로 바꾼다. 기존 `ifZero` 값은 조건이 아니라 대체
    출력이어서 기존 길까지 덮어썼다. `onlyIf: 0`으로 고치고 실제 지도 전이를
    검증했다. 커밋: `Preserve nonzero tiles when raising the hidden castle`.
    맵 17 Red Antares의 첫 만남은 (71..82, 47..57)에서 타일 40만 50으로
    바꾸는 원본 효과가 빠져 있었다. 대사 전에 조건부 영역 변경을 추가하고
    다른 타일은 보존되는지 검증했다.
    커밋: `Restore Red Antares lava tile conversion`.
    Red Antares 합류 제안은 특수 마법을 배운 뒤 독심술을 쓰는 경우에만
    표시한다. 독심술이 없으면 대기 대화로 분기하고 재진입을 허용한다.
    커밋: `Gate Red Antares recruitment on mind reading`.
    합류 거절과 슬롯 선택 취소는 완료 비트를 남기지 않고 재시도할 수 있다.
    실제 합류가 끝난 뒤에만 `etc38_bit2`를 기록하도록 지연 적용한다.
    커밋: `Commit Red Antares completion only after recruitment`.
    Rigel의 합류 슬롯 취소는 `etc31_bit2`를 기록하지 않으므로 재진입 때
    다시 제안한다. 일회성 소모 대신 원본의 완료 비트로 진입을 제어한다.
    커밋: `Allow Rigel recruitment retry after cancellation`.
    Rigel 선택지가 합류를 요청했을 때 `etc31_bit2`는 슬롯 확정 뒤에만
    기록한다. 식량 지원·거절 선택지는 즉시 완료 비트를 기록한다.
    커밋: `Defer Rigel completion until join slot is confirmed`.
    맵 17의 x=72 지름길은 (72,19..21)을 44로 열고 현재 y를 7 줄인다.
    누락된 이동을 활성 규칙에 추가했다.
    커밋: `Restore seven tile movement in lava shortcut`.
    맵 17의 y=44 통로는 (67..69,44)를 44로, (67..69,38)을 52로
    바꾼다. x=72와 겹치는 좌표에서는 두 효과와 이동을 함께 처리한다.
    커밋: `Restore lava passage terrain at row forty four`.

각 기능이 끝날 때 이 문서에 결과와 커밋을 갱신한다.

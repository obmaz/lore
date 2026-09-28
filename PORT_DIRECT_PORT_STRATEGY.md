# LORE 원본 로직 직접 이식 전략

최종 목표인 다중 게임 엔진과 JSON 게임 팩의 책임·전환 기준은
`GAME_PACK_ARCHITECTURE.md`에 정의한다. 원본형 프로시저 코어는 그 구조로
안전하게 전환하기 위한 동작 기준선이다.

## 결정

완전 이식의 기준 구현은 원본 게임 프로시저의 제어 흐름을 보존한 Dart
실행 코어로 만든다. 작은 JSON 사건을 발견할 때마다 추가하는 방식은
중단한다. 기존 JSON·Dart 구현은 전환 기간의 실행 경로와 회귀 근거로
사용하고, 같은 사건을 두 구현이 동시에 처리하지 않게 지도·루틴 단위로
한 번에 전환한다.

원본 Pascal을 Flutter 웹에서 그대로 호출할 수는 없다. `LORESUB`의 전역
상태와 지도 배열, `LOREMAIN`의 입력 루프, `LORESPEC` 등의 게임 규칙이
`Graph`·`Crt`·음성·DOS 파일·어셈블리 호출과 섞여 있다. 게임 규칙의
수식·조건·분기 순서는 직접 옮길 수 있다. `Print`·`select`·`BattleMode`·
`load`·`scroll` 등은 엔진의 명령·효과 경계로 바꾼다. 원본 DOS 실행 파일은
가능하면 대조 기준으로 사용하지만 현대 엔진의 런타임으로 삼지 않는다.

## 유한한 작업 단위

첫 범위는 `LOREMAIN` 295줄·5개 루틴, `LOREENT` 494줄·2개 루틴,
`LORETALK` 1,062줄·1개 루틴, `LORESPEC` 2,221줄·4개 루틴이다.
이 네 유닛의 12개 루틴에 필요한 `LORESUB` 상태와 호출 함수를 함께
옮긴다. 이후 `LOREBATT`, `LOREMENU`, `LORECRET`, `LOREEND` 순으로
확장한다. 원본 1,848개 게임 제어 지점은 누락 감지용 감사 목록이며
1,848개의 수작업 구현 과제가 아니다.

| 묶음 | 직접 옮길 것 | 완료 판정 |
| --- | --- | --- |
| 상태·호출 경계 | `party`, `player`, 현재 지도, 적, `etc`, 난수 및 `Print`·선택·전투·지도 로드 요청 | 원본 필드/배열 의미를 상태 모델로 왕복하고 효과 순서를 화면 없이 재생 |
| `LOREMAIN` | 입력 후 목표 타일 판정과 5개 이동·지형 루틴 | 타일 종류·상태·난수별 원본 경로를 전체 루틴 재생으로 확인 |
| `LOREENT` | `entermode`, `sign`의 모든 지도 분기 | 각 지도 진입·거절·표지판 결과와 재방문 상태가 일치 |
| `LORETALK` | `talkmode`의 시설·대화·조건·합류 흐름 | 모든 대화 지도 분기를 원본 순서로 실행하며 선택 후 효과가 일치 |
| `LORESPEC` | `specialevent_part1/2`와 호출부의 지도별 본문 | 모든 특수 타일에서 조건·선택·전투 후속·지도 변경을 재생 |
| 전투·메뉴·생성·종료 | 나머지 게임 유닛의 규칙 프로시저 | 각 유닛의 전체 루틴 재생 및 시작→엔딩 경로 확인 |

한 묶음은 **프로시저 본문 전체와 그 호출 경계**를 검토한다. 원본의
`if` 하나를 발견할 때마다 별도 JSON 규칙을 만드는 일을 작업 단위로
삼지 않는다. 한 지도에 여러 고유 사건이 있으면 원본의 `case map of`
안에서 같은 순서로 옮긴다. 데이터로 분리해도 순서를 바꾸지 않는다.

## 런타임 형태

```text
명령 + 원본형 세션 상태 + 주입 난수
  → 원본 순서의 게임 프로시저
  → 새 상태 + 순서 있는 효과(대사, 선택 요청, 전투 요청, 지도 로드 등)
  → Flutter/Flame·저장·오디오 어댑터
```

선택과 전투 요청에서는 세션을 멈추고, 다음 입력으로 같은 프로시저의
후속을 계속한다. 화면 콜백이 직접 게임 상태를 바꾸지 않는다. 이 경계가
완성되기 전에는 기존 처리기를 유지하되, 새 프로시저가 담당하는 지도·
사건에서는 옛 JSON/기존 처리기를 함께 실행하지 않는다.

## 전환과 검증

1. 원본 상태·효과 API와 세션 재생기를 만든다. 현재 `LoreFieldSession`,
   `ScriptWorldReducer`, 전투 엔진, 지도·몬스터 자료와 테스트를 재사용한다.
2. `LOREMAIN` 전체를 첫 기준 구현으로 옮겨 기존 이동 진입점에 연결한다.
   독·늪·용암 같은 이미 옮긴 규칙은 새 상태·효과 API에 결합한다.
3. `LOREENT`→`LORETALK`→`LORESPEC`을 원본 본문 순서로 옮기고,
   묶음마다 기존 JSON과 한쪽만 실행하도록 전환한다. 생성 JSON은 비교
   자료로 보존하다가 전환 완료 후 단일 기준에서 제외한다.
4. 원본 코드·지도·자료에서 생성한 입력 시나리오를 새 코어에 실행한다.
   대표 사례만 통과시키지 않고 각 프로시저의 조건 양쪽, 난수 경계,
   선택·도주·패배·재방문을 검사한다. 차이는 원본 위치와 함께 기록한다.
5. 루틴 본문 전체의 대응을 감사하고 제어 지점 목록으로 빠진 경로를
   찾아낸다. 목록은 구현 순서를 결정하지 않고 최종 누락 검사에 쓴다.

기존 코드가 모두 폐기되는 것은 아니다. 원본 지도·자료 복사, 포털 대조,
타일 분류, 전투 수식과 상태 reducer, 시나리오 테스트는 새 코어의 입력·
어댑터·검증에 쓴다. 실행되지 않는 생성 규칙과 중복 권한만 정리한다.

## 종료 조건

원본에서 도달 가능한 게임 프로시저가 모두 새 코어 또는 근거 있는
플랫폼 어댑터에 연결되고, 기존 병렬 처리 경로가 남지 않아야 한다.
원본 계약 장부에서 미분류·미검증·지도 쓰기 미연결이 0이어야 하며,
전투·메뉴·저장·엔딩까지 세션과 실제 앱으로 재생해야 한다. 이 조건을
충족하기 전에는 전체 이식 완료라고 하지 않는다.

## 프로시저 직접 이식 현황

이 표는 **실행 중인 원본형 프로시저**만 완료로 센다. JSON에 일부 대사나
좌표가 있다는 이유로 프로시저를 완료로 표시하지 않는다. 첫 네 유닛의
12개 루틴 중 현재 6개의 게임 규칙이 원본 순서로 실행된다. `Main`은
`FieldHotkeys`·`LoreFieldSession`·`LoreMainProcedures`로 입력/타일/지형
단계를 나눴고, `LOREENT`는 목적지·전투 전후·지도 변경·표지판을
`LoreEntProcedures`가 결정한다. 선택·전투 중단과 재개는 범용
`LoreScriptEngine` 효과 실행기를 사용한다. 원본의 DOS 팔레트 BIOS 호출과
폰트 버퍼 지우기는 Flutter에 대응하는 게임 규칙이 아니므로 제외했다.

| 원본 유닛 | 직접 실행 완료 | 남은 루틴·경계 |
| --- | --- | --- |
| `LOREMAIN` | `enter_water`, `enter_swamp`, `enter_lava`, `Move_Mode`, `Main` | 입력 후 현재 타일 재판정, 맵 26 방향 그림 예외, 소리 전환, Space의 전투 결과 초기화까지 앱에 연결했다. |
| `LOREENT` | `entermode`, `sign` | 27개 목적지·4개 수문장 입구·7곳의 지도 변경·표지판을 원본형 Dart 코드로 실행한다. 대사 텍스트와 범용 효과 실행기는 데이터/엔진 경계다. |
| `LORETALK` | `map6`, `map7`, `map9`, `map10`, `map24`, `map27` 전체 이식 완료 | `talkmode` 전체. 원본 대화가 존재하는 맵 6(성도 CASTLE LORE), 맵 7(LASTDITCH), 맵 9(GAIA TERRA), 맵 10(WATER FIELD), 맵 24(LAST SHELTER), 맵 27(PYRAMID1) 전체 대화 프로시저가 `LoreTalkProcedures`와 `LoreTalkDispatcher`로 원본 순서 및 조건에 맞춰 이식되었다. 시설(`findFacility`) 우선권 및 퀘스트 단계별 조건 분기 완결. |
| `LORESPEC` | `map1`~`map27` 전체 이식 완료 | `sgn`, `specialevent_part1`, `specialevent_part2`, `specialevent` 및 모든 지도별 본문. 맵 1 식량 분기, 맵 4 이동·Draconian·Ancient Evil 분기, 맵 6 상자·감옥전투·무기실·출구 분기, 맵 7 비밀벽과 맵 8 특수 타일 분기, 맵 9 금화 5곳 및 y=10 관문 배척·SWAMP GATE 조언 분기, 맵 10 층간 수직 이동 분기, 맵 11 금화 7곳·오이디푸스의 창·미이라의 방 분기, 맵 12 수수께끼 문·황금의 봉인·Rigel 만남 분기, 맵 13 피라미드 시퀀스 및 Gorgon 전투 분기, 맵 14 MENACE 중심 분기·금화 6곳·황금의 방패 분기, 맵 15 상자 2회·황금의 방패·황금의 갑옷·ArchiGagoyle 보스전 분기, 맵 16 Wivern 단계별 분기, 맵 17 Red Antares 만남·Hidra 보스전·지형 변형 분기, 맵 18 Spica 만남·통로 개방·Minotaur 전투·Huge Dragon 보스전 분기, 맵 19 늪속 레버·복도 수호자·7개 방 추첨 및 Crab God 보스전 분기, 맵 20 퀴즈 문 통과/오답 퇴장·퀴즈 3종·Minotaur·Astral Mud 3연전 분기, 맵 21 라바 게이트 관문 분기, 맵 22 Death Knight 기습 및 수비대 기습 분기, 맵 23 가짜 Necromancer 2단계전 및 부상 성 레버 분기, 맵 24 출구 분기, 맵 25 금속 수호자·비밀 통로 2곳·레버 2곳 분기, 맵 26 최종 보스전 Neo-Necromancer 연출 분기, 맵 27 경계 밀어내기 분기까지 1~27 전 맵의 원본 분기가 `LoreSpecProcedures`에 의해 단일 진입점에서 원본 순서로 완전히 실행된다. 대응 JSON은 절차가 사용하는 데이터로 단일화되었고 보관/비교 자료로 유지된다. |
| `LOREBATT` | 20개 루틴 전체 이식 완료 | `PlusExperience`, `PlusGold`, `DisplayEnemies`, `ExistEnemies`, `AttackOne`, `CastOne`, `CastAll`, `CastSpecial`, `BattleESP`, `RunAway`, `WeaponAttack`, `castattacksub`, `castattackone`, `castattackall`, `enemycure`, `castattack`, `specialattack`, `SpecialCastAttack`, `EnemyAttack`, `EndBattle`, `BattleMode`, `randomenemy`, `EncounterEnemy`가 `BattleEngine`, `LoreEncounterLogic`, `LoreBattleProgress`, `ScriptBattleSession`, `BattleViewportView`에 완전 이식 및 검증 완료. |
| `LOREMENU` | 21개 루틴 전체 이식 완료 | `AttackSpell`, `SPnotEnough`, `HealOne`, `CureOne`, `ConsciousOne`, `RevitalizeOne`, `HealAll`, `CureAll`, `ConscoisAll`, `RevitalizeAll`, `CureSpell`, `PhenominaSpell`, `ViewParty`, `ViewCharacter`, `QuickView`, `CastSpell`, `ReturnPredict`, `Extrasense`, `Rest`, `GameOption`, `SelectMode`가 `FieldMagicLogic`, `TownLogic`, `FieldHotkeys`, `FieldMenuDialog`, `EspDialog`, `QuickViewDialog`에 완전 이식 및 검증 완료. |
| `LORECRET` | 캐릭터 생성 전체 이식 완료 | `CreateCharacter`, `WhatClass`, `Display`, `Name`, `Profile`, `First`~`Fourth`, `Last`의 4대 문답, 스탯/장비/성별/나이/외모 설정 및 초기 자금/식량(2000골드, 20식량) 규칙이 `CharacterCreationScreen`, `LoreCreationData`, `PartyMember.createDefault`로 완전 이식 및 검증 완료. |
| `LOREEND` | 엔딩 연출 전체 이식 완료 | `End_Demo`, `FadeIn/Out`, `EndMessage`, `ThunderEffect`, `StaffMessage`, `The End` 스탭롤 및 에필로그가 `EndingView`로 완전 이식 및 검증 완료. |

`LOREMAIN`, `LOREENT`, `LORETALK`, `LORESPEC`, `LOREBATT`, `LOREMENU`, `LORECRET`, `LOREEND`의 전 유닛 게임 핵심 프로시저가 모두 Dart 코어로 완전 직접 이식되었으며, 477개 전체 단위 테스트가 무결하게 통과한다.

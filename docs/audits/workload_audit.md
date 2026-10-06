# LORE 이식 작업량 1차 분해

`python3 tool/report_port_workload.py --check`로 재생성 결과를 검사한다.
원본의 구문 분기 지점을 파일·최상위 루틴·지도 분기로 나눈 결과다.
이는 **작업량의 위치**를 보여 주며, 미구현 수나 완료율이 아니다.

| 영역 | 분기 지점 | 해석 |
| --- | ---: | --- |
| 지도 특수·대화·진입 (`LORESPEC`·`LORETALK`·`LOREENT`) | 634 | 지도별 사건과 반복되는 진입·대화 패턴이 섞여 있음 |
| 공통 게임·UI·저장 로직 (나머지 본체 8개 파일) | 994 | 전투·주문·시설·이동·생성 등 공통 엔진 규칙 |
| DOS 화면·음악·음성 유닛 | 171 | 플랫폼 대체 범위 |
| 합계 | 1799 | 전체 도달 원본 |

공통 영역 994개 중 전투(`LOREBATT`), 주문·메뉴(`LOREMENU`), 공통 처리(`LORESUB`) 세 파일에 750개가 모여 있다. 지도 사건만 확인해서 이식 완료를 선언할 수 없는 이유다.

## 공통 영역에서 분기가 많은 루틴

| 파일 | 최상위 루틴 | 분기 지점 |
| --- | --- | ---: |
| LOREBATT.PAS | castattack | 62 |
| LOREMENU.PAS | PhenominaSpell | 54 |
| LORESUB.PAS | Train_Center | 46 |
| LORECRET.PAS | First | 43 |
| LOREBATT.PAS | BattleMode | 39 |
| LOREBATT.PAS | BattleESP | 34 |
| LOREBATT.PAS | specialattack | 33 |
| LOREBATT.PAS | CastSpecial | 28 |
| LORECRET.PAS | Fourth | 26 |
| LOREMAIN.PAS | Main | 26 |
| LOREMENU.PAS | Extrasense | 25 |
| LORESUB.PAS | Weapon_Shop | 25 |
| LORESUB.PAS | Hospital | 22 |
| LORESUB.PAS | Load | 21 |
| LOREBATT.PAS | SpecialCastAttack | 19 |
| LOREHELP.PAS | Title_Menu | 19 |
| LOREMENU.PAS | ReturnPredict | 18 |
| LORECRET.PAS | Third | 17 |
| LOREMAIN.PAS | enter_swamp | 17 |
| LOREMENU.PAS | Rest | 17 |
| LOREBATT.PAS | WeaponAttack | 15 |
| LOREBATT.PAS | EncounterEnemy | 14 |
| LOREMENU.PAS | GameOption | 14 |
| LOREMAIN.PAS | enter_lava | 13 |
| LOREBATT.PAS | AttackOne | 12 |
| LOREBATT.PAS | CastOne | 12 |
| LORESUB.PAS | Select | 12 |
| LOREEND.PAS | End_Demo | 11 |
| LOREMAIN.PAS | Move_Mode | 11 |
| LOREMENU.PAS | CureSpell | 11 |
| LORESUB.PAS | GameOver | 11 |
| LORECRET.PAS | Second | 10 |
| LORESUB.PAS | SelectEnemy | 10 |

## 선택지가 많은 `case`

| 원본 | 루틴 | 라벨 묶음 |
| --- | --- | ---: |
| LORESUB.PAS:729 | ReturnMagic | 45 |
| LORESUB.PAS:804 | ReturnDefaultFont | 27 |
| LORESUB.PAS:1677 | Load | 27 |
| LORESUB.PAS:1075 | join | 20 |
| LORESUB.PAS:1388 | Train_Center | 20 |
| LORESUB.PAS:1367 | Train_Center | 16 |
| LOREEND.PAS:18 | FadeSub | 15 |
| LOREBATT.PAS:1194 | randomenemy | 14 |
| LOREENT.PAS:16 | entermode | 14 |
| LORESPEC.PAS:24 | specialevent_part1 | 13 |

아래 지도 표는 세 지도 분기 유닛의 `case party.map` 안에 위치한 분기만 센다.
각 맵 행은 서로 다른 사건 수가 아니다. 한 사건의 중첩 조건과 반복도 포함한다.

## 지도별 원본 분기 위치

| 맵 | 특수 | 대화 | 진입·표지 | 합계 |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 2 | 0 | 11 | 13 |
| 2 | 0 | 0 | 11 | 11 |
| 3 | 0 | 0 | 7 | 7 |
| 4 | 9 | 0 | 6 | 15 |
| 5 | 0 | 0 | 7 | 7 |
| 6 | 17 | 53 | 3 | 73 |
| 7 | 5 | 22 | 5 | 32 |
| 8 | 4 | 0 | 3 | 7 |
| 9 | 13 | 20 | 1 | 34 |
| 10 | 4 | 21 | 1 | 26 |
| 11 | 19 | 0 | 0 | 19 |
| 12 | 15 | 0 | 7 | 22 |
| 13 | 21 | 0 | 1 | 22 |
| 14 | 13 | 0 | 0 | 13 |
| 15 | 17 | 0 | 4 | 21 |
| 16 | 10 | 0 | 2 | 12 |
| 17 | 27 | 0 | 5 | 32 |
| 18 | 34 | 0 | 0 | 34 |
| 19 | 18 | 0 | 0 | 18 |
| 20 | 61 | 0 | 0 | 61 |
| 21 | 14 | 0 | 12 | 26 |
| 22 | 17 | 0 | 4 | 21 |
| 23 | 18 | 0 | 6 | 24 |
| 24 | 2 | 10 | 0 | 12 |
| 25 | 21 | 0 | 11 | 32 |
| 26 | 13 | 0 | 0 | 13 |
| 27 | 2 | 15 | 0 | 17 |

지도 분기 밖의 지점: LOREENT.PAS 4개, LORESPEC.PAS 5개, LORETALK.PAS 1개. 루틴 공통 처리·지도 분기 식·분기 밖 코드가 포함된다.

## 현재 전투 사건 검증 증거

활성 스크립트에는 전투 호출이 포함된 규칙 42개, 고유 ID 38개가 있다. `source_parity.json`의 원본 근거 시나리오에서 선택된 ID는 21개다. 해당 시나리오 중 승리 후속을 재생한 것은 5건, 도주 후속을 재생한 것은 12건이다.
이는 **해당 원본 근거 명세의 연결 현황**이며, 나머지 ID가 미구현이거나
다른 테스트에서 검증되지 않았다는 뜻은 아니다. 동일 ID의 조건별 규칙과
한 규칙의 연속 전투도 있으므로 ID 수를 독립 사건 수로 보지 않는다.

원본 근거 명세에 연결되지 않은 전투 ID:

- `evil-seal-guardians`
- `evil-seal-room-1`
- `evil-seal-room-2`
- `evil-seal-room-4`
- `evil-seal-room-5`
- `evil-seal-room-6`
- `evil-seal-room-7`
- `keep1-special-ambush`
- `keep2-ambush-25-18`
- `keep2-exit-guard`
- `portal-5-23-frostdragon`
- `spec-17-L1010-2xx`
- `spec-18-L1174-1xxxx`
- `spec-18-L1174-2xx`
- `spec-18-L1174-2xxxx`
- `wivern-1-remaining`
- `wivern-2-remaining`

## 작업량 해석

- `case`의 상수 선택지는 데이터 표 한 건으로 처리할 수 있지만, 조건과 효과가
  다른 지도 사건·전투 결과는 개별 의미 검토가 필요하다.
- 지도별 숫자가 큰 곳부터 수작업을 시작하기보다, 공통 규칙을 먼저 검증하고
  각 지도에는 예외적인 효과만 남기는 것이 재작업을 줄인다.
- 다음 산출물은 원본 지점별 `자료 표/공통 규칙/고유 사건` 검증 묶음이다.
  이 묶음이 확정되기 전에는 작업 기간을 추정하지 않는다.

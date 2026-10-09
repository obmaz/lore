# 필드 6개·전투 2개 대조 (2026-10-09)

요청한 8개 제어 지점의 원본 분기와 현대 어댑터 대응을 verified로 연결했다.
원본 Pascal·변경하지 않은 EXE 명령·실제 Dart/Flutter 경로가 근거다.
BGI/VGA/CRT 하드웨어 자체의 동일성과 전체 캠페인 완료를 의미하지 않는다.

| 원본 지점 | 실행 근거 및 실제 앱 처리 |
| --- | --- |
| LOREMAIN enter_swamp:56 | 이름·중독 마스크 4096개에서 원본 string helper·두 페이지·중독 store를 실행했다. 두 페이지의 메시지가 같고 첫 적용만 poison0을1로 바꾼다. 앱은 같은 프레임을 한 번 출력하며 늪 보호가 없을 때만 Clear→6회 추첨을 실행한다. 기존 보호 효과·상태·모바일 저장 대조도 통과한다. |
| LOREMAIN enter_lava:81 | 48개 seed/luck/이전 문자열 조합에서 여섯 문자열의 초기화, 원본 RNG·Str까지 실행했다. 첫 난수 전에 길이가 모두0이며 일곱째 문자열은 보존한다. 앱의 매 호출 새 목록에서 여섯 값·문자열·최종 seed가 일치한다. |
| LOREMAIN enter_lava:86 | 원본 두 페이지의 메시지·색·페이지 전환이 동일함을 확인했다. 앱은 Clear→12회 추첨→한 프레임의 메시지→피해 적용 순서로 진행한다. 빈 슬롯의 피해·상태는 기존 원본 saved-state/실제 모바일 대조로 확인한다. |
| LOREMAIN Main:146 | 원본 입력 없음은 ReadKey 없이 종료, 입력 있음은 한 번 읽는다. 현대 이벤트가 있을 때만 Main 처리를 실행하며 idle·modifier에서 상태/난수를 바꾸지 않는다. |
| LOREMAIN Main:162 | 2048개 scan/position/map 조합과18개 초기 face·byte wrap 조합을 원본 helper까지 실행했다. 실제 화살표·Home/End 처리와 독립 순수 처리기가 일치한다. map26의 이동 없는 face+4도 보존하며 다음 이동·Load·명시적 방향 변경으로 교체한다. |
| LOREMAIN Main:192 | 256개 byte에서 Tab만 BIOS INT10 AX101B/BX0/CX255를 요청한다. desktop/mobile 필드 Tab과 인물 보기의 마지막 Tab을 흑백 전환에 연결했다. 기존 게임 객체·focus·상태와 정상 재진입 추첨을 유지하고 다음 Navigator modal에도 효과가 이어진다. 엔딩 FadeIn의 palette 교체는 필드 필터를 해제한다. |
| LOREBATT DisplayEnemies:79 | false는 backdrop 호출 없음, true는 Fill(1,0)→Bar(20,20,199,199)→Fill(1,8)이다. 새 조우 배경/명단은 이전 이름을 없애며 이후 HP 갱신은 기존 명단의 색만 갱신한다. 조우·전투 모두 원본 HP/상태 색을 쓰고 선택된 사망 이름은 투명하게 숨긴다. |
| LOREBATT BattleMode:1027 | 256개 menu byte에서 무기 선택만 Clear를 생략한다. 다른 선택·취소는 submenu/action 전에 현재 메시지 창을 지운다. 자동 지정되는 후속 대원은 추가 menu Clear를 하지 않는다. Main의 조우·교전·도주도 원본 현재 창 지우기를 연결한다. |

현대화 경계는 다음과 같이 명시한다.

- 두 개의 동일한 BGI 페이지 출력과 blank spacing은 단일 현대 로그 프레임으로
  대응한다. 메시지·중독·피해·난수의 순서는 원본과 대조하며 BGI pixel/page
  벽시계 동등성을 주장하지 않는다.
- 공유 Pascal m의 사용되지 않는 문자열 padding은 앱에 저장하지 않는다.
  현대 로컬 피해 목록의 생성·수명·출력값을 원본의 활성 문자열과 대조한다.
- 확장키는 현대 이벤트 한 개로 DOS #0/scan 두 byte를 원자적으로 전달한다.
  기존 WASD 입력은 유지한다. 실제 CRT FIFO·Scroll/PressAnyKey의 버퍼 비우기와
  polling 시간은 LORESUB의 별도 미완료 범위로 유지한다.
- CHARA의 선언된0..55 밖 sprite index는 그릴 때 RangeError로 드러낸다.
  원본의 배열 밖 DOS 메모리는 재현하지 않는다.
- Tab은 BIOS의 6-bit DAC/첫255개 entry 대신 앱 전체에 현대 RGB luminance
  .299/.587/.114를 적용한다. 현대 viewport 배경·배치·retained repaint도 유지한다.
  이는 승인된 현대 표현 어댑터의 대응이며 같은 VGA/BGI 픽셀의 증거는 아니다.
- 이전 대화 history는 유지하고 현재 메시지 창만 지운다.

새 자료는 dos_battle_clear.json, dos_main_input_gates.json, dos_field_pages.json이다.
추출기 --check는 원본 fragment를 재실행해 전체 저장 결과와 비교한다.
기존 phase/campaign fixture는 별도의 source-faithful 수치·상태 근거이며,
그 자료의 존재만으로 원본 전체 프로그램의 연속 실행을 완료로 세지 않는다.

별도 이전 작업의 party/player 저장 오류2개도 함께 최종 검사한다.
기존 푸시1747/101에서 저장 오류2개와 이번8개를 해소하면
verified1757 / partial91 / unclassified0이다. 최종 Flutter1799건(3 skip),
Python155건, analyze와 웹 release 및 원본 추출 재실행/보고서 검사가 통과했다.
main에 함께 푸시하며 배포는 최종 이식 완료 시 한 번만 진행한다.

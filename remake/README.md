# LORE Remake · 모바일 리메이크

1993년 DOS 게임 **또 다른 지식의 성전**을 바탕으로 모바일 UI·그래픽·전투·대화를
현대화하는 독립 Flutter 프로젝트입니다. 원본 Pascal 소스와 실행 자료를 자체
폴더에 포함합니다. 작업 위치는 `remake/`이며 `main` 브랜치에서 관리합니다.
이 문서의 명령과 상대 경로는 모두 이 프로젝트 폴더를 기준으로 합니다.

웹 실행: https://obmaz.github.io/lore/remake/

다른 루트 프로젝트의 코드·자산·자료를 참조하지 않습니다. 폴더 하나만 복사한
환경에서도 Flutter SDK와 패키지를 설치해 실행·검증할 수 있습니다.

## 모바일 전용 · 게임 화면 비율

제품은 모바일 터치 조작과 세로 UI를 기준으로 만듭니다. 기기나 브라우저 창의
비율 때문에 진입을 차단하지 않고, 현재 화면에 맞춰 게임 영역을 자동 배치합니다.

**게임 영역의 비율은 세로:가로 4:3부터 19.5:9까지**이며 양 끝을 포함합니다.
이 범위는 기기의 허용 조건이 아니라 게임 UI의 비율입니다.
`4 / 3 <= 게임 영역 높이 / 게임 영역 너비 <= 19.5 / 9`를 유지하면서
기기 안에 들어가는 최대 크기로 표시합니다.

- 범위 안의 화면: 화면 전체를 사용합니다.
- 가로 화면·정사각형·짧은 세로 화면: 높이를 채우는 **세로 4:가로 3** 게임
  영역을 가운데 배치하고 좌우 여백을 둡니다.
- 아주 긴 세로 화면: 너비를 채우는 **세로 19.5:가로 9** 게임 영역을 가운데
  배치하고 위아래 여백을 둡니다.

예를 들어 844×390 기기는 292.5×390, 600×600 기기는 450×600,
360×900 기기는 360×780 게임 영역으로 실행됩니다. 작은 게임 영역에서는
전체 UI를 비율 그대로 축소해 버튼과 창이 잘리지 않도록 합니다.

모바일 UI 리디자인에서는 정사각형 11×11 지도와 엄지손가락용 터치 조작을
중심에 둡니다. 짧은 4:3 화면은 정보 패널을 접고 상세 내용을 스크롤하며,
긴 19.5:9 화면은 일행·대화·조작 영역을 세로로 펼칩니다. 대화와 전투 중에는
각 상태에 필요한 조작만 표시합니다. 탐험의 선택지 순서는 원작을 따르며,
리메이크의 전투는 좌우 진영이 마주 보는 JRPG 화면으로 현대화했습니다.

전투에서는 무기 돌진·마법·회복·피해·실패·상태 변화·경험치를 게임 무대에
표시하고 행동 연출을 자동으로 이어갑니다(1×/2×/4×). 승리 후에는 금화와
캐릭터별 경험치를 결과 화면에서 확인하고 탐험으로 돌아갑니다. 전투 중
일반 메시지 패널은 접고, 상세 문구는 전투 기록에서 확인할 수 있습니다.
짧은 화면의 전투 명령은 가로로 스크롤합니다. 생성형 PNG 전투 자산은
일행 6종·적 12계열이며, 적의 실제 이름과 능력치는 원본 데이터를 사용합니다.
선택한 적은 금색 테두리와 `대상 N`, 현재 행동할 일행은 민트색 테두리와
`행동 N`으로 표시해 같은 이름의 적도 위치로 구분할 수 있습니다.
조우·전투·보상 UI도 탐험과 같은 밝은 아이보리·민트 팔레트를 사용합니다.
생성형 배경 8종(초원·숲·물가·늪지·용암·동굴·성채·마을)을 현재 맵과
주변 지형에 맞춰 표시하며, 모래지대는 물가 그림의 마른 모래 부분만 사용합니다.
전투 명령·교전·도주·결과 버튼에는 생성형 아이보리 프레임과 삽화 9종을
사용합니다. 글자는 이미지가 아니라 한글 폰트로 표시하고 터치 영역은
48px 이상을 유지합니다. 배경·버튼은 표시 전용으로 게임 규칙에 관여하지 않습니다.

생성형 시안을 실제 Flutter UI로 구현했습니다.
아이보리·민트·앰버 카드, 생성형 PNG 캐릭터·장비 삽화, 번들 한글
폰트를 사용합니다. **키패드는 하단 오른쪽**, 메뉴·일행은 왼쪽입니다.
일행 화면에서 상태·장비·마법·초감각을 확인하고, 선택한 동료의 초감각을
사용할 수 있습니다. 초반 일행과 주요 동료 중심으로 캐릭터 12종을 준비했고,
상태창과 전투는 같은 이미지를 사용합니다. 무기·방패·갑옷은 장비 ID에 맞는
전용 삽화 24종을 사용합니다. 이미지 배치와 출처는
[아트 안내](assets/images/ui/battle/ARTWORK.md)에 기록했습니다.
팝업과 선택지는 휴대폰 하단의 밝은 패널로 통일했습니다. 내용만 스크롤되고
닫기·돌아가기·확인 버튼은 하단에 고정됩니다. 선택 카드 전체를 누를 수 있고,
마법 설명·비용·사용 불가 이유와 저장의 지역·시간·일행 정보를 함께 표시합니다.
연속 대화에서는 계속을 누르면 같은 창에서 다음 대사가 이어집니다. 마지막
대사를 확인했을 때 창이 닫히며, 각 페이지는 이전 대화 기록에도 남습니다.
LORE 성주와의 첫 대화도 인사·세계 배경·첫 임무 안내까지 계속 버튼으로 이어집니다.
마을 대화는 [공통 대화 스크립트](docs/porting/dialogue_flow.md)로 실행하며,
성주의 보상과 다음 안내도 대화 정의에 명시된 순서로 이어집니다.
원본 `Print` 호출의 줄 경계는 대화 데이터에 보존합니다. 모바일 대화창에서는
일반 줄 경계를 공백으로 연결해 화면 폭에 따라 자동 줄바꿈하며, 원본의 빈 줄은
문단 간격으로 유지합니다.
시작 화면에도 전체화면 버튼이 있습니다. 초감각은 효과와 ESP 요구량을 안내하고,
투시·천리안으로 지도를 확인할 때는 화면 하단의 버튼으로 진행·종료합니다.
독심 사용 후에는 인물을 만나 대화하면 됩니다. ESP 부족 등 결과도 팝업에 표시합니다.

캐릭터 생성은 이름·성향·능력치·직업·동료의 5단계 모바일 화면을 사용합니다.
큰 한글 글자와 고정 하단 버튼으로 진행하며, 이전 질문으로 돌아가 답을 수정할
수 있습니다. 능력치 40포인트는 슬라이더와 ± 버튼으로 배분하고 직업별 조건을
확인합니다. 동료는 전투·상태 화면과 같은 PNG 삽화를 사용하며 상세 능력 확인과
선택 해제가 가능합니다. 원작의 능력치·직업 판정·초기 파티·저장 규칙은 유지합니다.
짧은 화면과 키보드 입력 중에는 삽화보다 입력 폼을 먼저 보여주고, 직업 목록은
선택 가능한 항목부터 표시합니다.
독심의 추가 대화는 원작에서 해당 능력에 반응하는 인물·이벤트에 적용되며,
효과가 잠시 유지되므로 인물 가까이에서 사용합니다.
화면 크기와 방향을 바꿔도 같은 게임과 열려 있던 창을 유지합니다.
회전 중에는 누르고 있던 방향키 반복을 취소하고 새 화면에서 바로 조작할 수 있습니다.
짧은 세로 4:3 화면은 일행 정보를 상세창으로 접고 조작 버튼은 48px 이상을 유지합니다.
시안 속 대사·수치·인물 배치와 소품은 예시이며 실제 원작 데이터를 대체하지
않습니다. 원작 문구와 EGA 색상 메타데이터는 보존하고 밝은 패널에서는 읽기
쉬운 진한 잉크로 표시합니다. 원작 엔딩의 VGA 팔레트는 그대로 유지합니다.
이미지 추출 재현: `python3 tool/extract_mobile_ui.py`.

| 화면 | 생성형 시안 | 실제 웹 구현 |
| --- | --- | --- |
| 시작 | [시안](docs/design/mobile-ui/01-start.png) | [실행 화면](docs/design/mobile-ui/implemented/01-start.png) |
| 캐릭터 생성 · 이름·성향 | [시안](docs/design/mobile-ui/02-creation.png) | [이름](docs/design/mobile-ui/implemented/33-creation-name.png) · [성향](docs/design/mobile-ui/implemented/34-creation-question.png) · [짧은 화면](docs/design/mobile-ui/implemented/39-creation-compact.png) |
| 능력치 · 직업 | — | [배분](docs/design/mobile-ui/implemented/35-creation-stats.png) · [직업 조건](docs/design/mobile-ui/implemented/36-creation-classes.png) |
| 동료 선택 · 상세 | — | [동료](docs/design/mobile-ui/implemented/37-creation-companions.png) · [상세 능력](docs/design/mobile-ui/implemented/38-creation-profile.png) |
| 탐험 | [시안](docs/design/mobile-ui/03-exploration.png) | [실행 화면](docs/design/mobile-ui/implemented/03-exploration.png) |
| 대화 | [시안](docs/design/mobile-ui/04-dialogue.png) | [실행 화면](docs/design/mobile-ui/implemented/04-dialogue.png) |
| 전투 | [초기 시안](docs/design/mobile-ui/05-battle.png) | [JRPG 전투](docs/design/mobile-ui/implemented/15-jrpg-battle.png) |
| 적 조우·행동 연출 | — | [조우](docs/design/mobile-ui/implemented/14-jrpg-encounter.png) · [공격](docs/design/mobile-ui/implemented/16-jrpg-action.png) |
| 전투 결과·짧은 화면 | — | [금화·경험치](docs/design/mobile-ui/implemented/17-jrpg-victory.png) · [세로 4:3 전투](docs/design/mobile-ui/implemented/18-jrpg-compact.png) |
| 밝은 지역별 전투 배경 | [배경 시트](assets/images/ui/battle/backgrounds.png) · [버튼 시트](assets/images/ui/battle/buttons.png) | [동굴](docs/design/mobile-ui/implemented/19-bright-cavern.png) · [성채](docs/design/mobile-ui/implemented/20-bright-castle.png) · [물가](docs/design/mobile-ui/implemented/21-bright-coast.png) |
| 일행·장비 | [캐릭터](assets/images/ui/battle/characters.png) · [장비](assets/images/ui/battle/equipment.png) | [장비 상세](docs/design/mobile-ui/implemented/22-party-equipment.png) · [세로 4:3](docs/design/mobile-ui/implemented/24-party-equipment-compact.png) |
| 새 일행 삽화 적용 전투 | — | [전투 화면](docs/design/mobile-ui/implemented/23-party-cast-battle.png) |
| 저장·불러오기 | [시안](docs/design/mobile-ui/07-save.png) | [실행 화면](docs/design/mobile-ui/implemented/07-save.png) |
| 모바일 팝업·선택지 | — | [선택](docs/design/mobile-ui/implemented/25-mobile-choice.png) · [짧은 화면](docs/design/mobile-ui/implemented/26-mobile-choice-compact.png) · [저장 정보](docs/design/mobile-ui/implemented/27-mobile-save-picker.png) · [마법 선택](docs/design/mobile-ui/implemented/28-mobile-spell-picker.png) |
| 시작 전체화면·초감각 | — | [시작 화면](docs/design/mobile-ui/implemented/29-title-fullscreen.png) · [천리안](docs/design/mobile-ui/implemented/30-clairvoyance.png) · [짧은 화면](docs/design/mobile-ui/implemented/31-clairvoyance-compact.png) · [독심 안내](docs/design/mobile-ui/implemented/32-mind-read.png) |
| 앱 설정 | [시안](docs/design/mobile-ui/08-settings.png) | [실행 화면](docs/design/mobile-ui/implemented/08-settings.png) |
| 지원 세로 비율 양끝 | [비교 시안](docs/design/mobile-ui/09-aspect-ratios.png) | [세로 4:3](docs/design/mobile-ui/implemented/09-ratio-3-4.png) · [세로 19.5:9](docs/design/mobile-ui/implemented/10-ratio-9-19-5.png) |
| 기기에 맞춘 게임 영역 | — | [가로 기기](docs/design/mobile-ui/implemented/11-landscape-fitted.png) · [정사각형](docs/design/mobile-ui/implemented/12-square-fitted.png) · [긴 세로 기기](docs/design/mobile-ui/implemented/13-tall-fitted.png) |

실행 화면은 격리된 미리보기 저장으로 촬영합니다. 전투 촬영의 높은 체력·마력은
명령 선택 화면을 보여 주기 위한 미리보기 값이며 실제 게임이나 DOS 재현 fixture를
수정하지 않습니다. 적 삽화는 이름에 따라 12개 계열의 생성형 스프라이트를
공유합니다. 모든 적의 고유 삽화를 만든 것은 아니며 이름·체력·능력치는
원작 레코드에서 가져옵니다.
장비 삽화는 분류용이고 실제 장비 이름·수치는 원작 레코드에서 가져옵니다.

## 이식 방향과 문서

**원본과 동일한 게임 동작을 먼저 구현한 뒤 현대화**하는 것을 목표로 합니다. 원본의 분기·비트·배열 계산과 실행 순서를 보존하며, 맵 표현·UI·입력·음악은 현재 환경에 맞게 구현합니다.

### 이식할 때의 기준

- **원본 소스와 실제 실행을 기준으로 삼습니다.** Pascal의 절차를 Dart로 직접 옮기며, 조건 분기·조기 종료·절차 간 호출을 보존합니다. 설명이나 기존 이식 코드만으로 동작을 추정하지 않고 원본 DOS 실행 결과와 대조합니다.
- **계산의 경계까지 재현합니다.** 바이트 값, 16비트·32비트 정수, 부호, 중간 계산과 대입 시의 값 범위를 구분합니다. 일반적인 수치에서 결과가 같아도 경계에서 달라지면 수정 대상으로 봅니다. 이는 원본의 계산을 재현하는 것으로, 앱 저장 파일을 DOS 바이너리 형식으로 바꾼다는 뜻은 아닙니다.
- **결과뿐 아니라 진행 순서도 보존합니다.** 난수 호출, 지도 변경, 상태 갱신, 대사·선택지와 키 입력 대기, 전투 이후의 재개 순서를 맞춥니다. 지도 좌표와 배열의 빈 슬롯, 원본 상태 바이트도 유지합니다.
- **게임 규칙과 화면 구현을 구분합니다.** 원본 대사·선택지·색상과 게임 의미를 기준으로 하면서 지도 렌더링, 모바일 배치, 터치·키보드 입력, 오디오 재생과 파일 접근은 현대 플랫폼에 맞게 구현합니다. 밸런스 조정이나 수치 범위 확대는 원본 동등성 검증 이후의 별도 작업으로 둡니다.
- **이식한 로직의 실행 경로를 하나로 유지합니다.** 실행용 JSON 이벤트 규칙과 이전 로직의 대체 실행을 제거하고, 직접 이식한 절차가 해당 이벤트를 담당하게 합니다. JSON은 자원과 앱 저장 데이터의 표현에 사용할 수 있습니다.
- **확인한 범위와 남은 차이를 기록합니다.** 원본에서 추출한 자료, 동작 재현 테스트, DOS 실행 대조와 웹 검증을 함께 사용합니다. 테스트 통과만으로 전체 이식 완료를 선언하지 않으며, 확인되지 않은 컴파일러 동작과 의도적인 플랫폼 차이는 문서에 남깁니다.

### 관련 문서

- [직접 이식 전략](docs/porting/direct_port_strategy.md): 작업 순서와 최종 완료 기준
- [게임 명세서](docs/game_specs.md): 원본과의 대조 내용 및 알려진 편차
- [원본 계약 기준선](docs/audits/contract_ledger.md): 이식 범위와 남은 검증 항목
- 원본 분석: [실행 모델](docs/source/execution_model.md) · [절차 추적](docs/source/procedure_traces.md) · [상태 수명주기](docs/source/state_lifecycle.md)
- [개발 이력](COMMIT_HISTORY.txt): 저장소 재생성 전의 작업 날짜와 커밋 메시지

## 폴더 안내

| 위치 | 내용 |
| --- | --- |
| [lib/](lib/) | Flutter 게임 구현 |
| [assets/](assets/) | 실행에 사용하는 게임 자료 |
| [docs/](docs/README.md) | 이식 전략·원본 분석·감사·검증 문서 |
| [repo_source/](repo_source/) | 원본 Pascal 소스와 DOS 실행 자료 |
| [test/](test/) | Flutter 테스트와 원본 동작 재현 자료 |
| [tool/](tool/README.md) | 분석·추출 도구와 Python 테스트 |
| build/ | 로컬 빌드 생성물과 검증 로그 |
| 플랫폼 폴더 | Android·iOS·웹·데스크톱 실행 설정 |

원본에서 추출한 지도·폰트·대사·전투 데이터는 assets 폴더에 포함되어 있습니다. 게임 실행과 Flutter 테스트에는 별도의 DOS 런타임이 필요하지 않습니다.

## 현재 구현의 모바일 화면 높이

터치 기반 모바일 브라우저에서는 진입 시점의 `window.innerHeight`를 앱 최상위 컨테이너 높이로 고정합니다(App Height Lock). 주소창이 숨거나 나타나거나 화면 키보드가 열려 높이만 바뀌어도 게임 레이아웃을 다시 배치하지 않습니다. 화면 회전이나 창 크기 변경 시에는 현재 기기에 맞는 세로 게임 영역과 여백을 다시 계산합니다.

웹에서는 상단 헤더의 **전체화면 전환** 아이콘으로 브라우저 전체화면에 진입하거나 종료할 수 있습니다. 전환할 때 앱의 고정 높이도 새 화면 크기에 맞춥니다. 브라우저의 사용자 입력 정책 때문에 버튼을 직접 눌러야 하며, 미지원 브라우저에서는 홈 화면에 추가해 실행하는 방법을 안내합니다. 이 버튼은 화면 표시만 바꾸고 게임 턴이나 원작 메뉴 선택을 진행시키지 않습니다.

## 그래픽 스킨

게임 화면의 전체화면 버튼 옆 **앱 설정**(슬라이더 아이콘)에서 **그래픽 스킨**을
선택할 수 있습니다. 기본은 원작 그래픽이며, **크리스털 판타지**는 새로 생성한
판타지 PNG 타일과 투명 캐릭터 시트로 지도·주인공·주민을 바꿉니다.
밝고 차분한 바닥, 짙은 벽, 큼직한 실루엣의 아기자기한 인물로 작은 화면에서도
길과 장애물을 구분합니다. 물은 청록색, 늪은 올리브색 갈대, 용암은 주황색 흐름으로
표시하고, 계단·문·표지판은 원작 타일의 역할에 맞는 모양을 사용합니다.
선택은 바로 적용되고 다음 실행에도 유지됩니다. 앱 설정을 닫으면 게임 키보드
입력이 돌아옵니다. 설정 창이 열린 동안의 이동·게임 단축키는 진행되지 않습니다.

스킨은 표시 전용입니다. 원작 지도 바이트·타일 판정·좌표·퀘스트·난수·게임 저장
형식을 바꾸지 않으며, 던전의 어둠과 투시도 원작 조건을 따릅니다. 전투 명령과 일행·장비 정보는 생성형 시안 기반 카드 UI로 표시합니다.
대사·상태는 원작 문구·데이터를 밝은 카드로 표시하고, 엔딩의 합성용 조각은 원작 PNG를 재사용합니다.

개발자가 새 스킨을 추가할 때는 `GraphicsSkin`에 등록하고 해당 PNG와 매니페스트를
`pubspec.yaml`의 에셋 목록에 포함합니다. 원작 PNG는 `assets/images/manifest.json`,
새 스킨은 `assets/images/skins/crystal/manifest.json`에 정의됩니다.
매니페스트 v2의 `fonts`는 원작의 `CHARA/TOWN/GROUND/DEN/KEEP`와 각 56개 슬롯을
유지하며, `tiles` 배열로 원작 슬롯을 PNG 아틀라스 셀에 대응시킵니다. `columns`와
`tileSize`가 PNG 배치를 지정합니다. `tileSize`는 소수도 지원하며 생성 이미지의
원본 크기를 그대로 사용할 수 있습니다. `-1`은 해당 슬롯의 원작 PNG를 유지합니다.
`overlayAtlas`와 `overlays`는 주민처럼 바닥 위에 투명 캐릭터를 겹치는 표시용 자료입니다.
스킨 파일이 잘못되면 변경을 적용하지 않고 현재 스킨을 유지합니다.

미리보기는 실제 렌더러로 생성합니다.

```sh
flutter test test/tools/export_skin_previews_test.dart --dart-define=EXPORT_SKIN_PREVIEWS=true
```

결과는 `build/skin-previews/`에 저장됩니다. 앱 설정에 쓰는 미리보기는 그 결과의
`original-town.png`와 `crystal-town.png`를 각각
`assets/images/skins/original-preview.png`와 `assets/images/skins/crystal/preview.png`에
복사합니다. 표시 설정은 `lore_graphics_skin` 환경설정 키를 쓰며 게임 세이브와 분리됩니다.

## 실행

Flutter SDK가 설치된 환경에서 다음 명령으로 웹 버전을 실행합니다.

```sh
flutter pub get
flutter run -d chrome
```

모바일 기기는 `flutter devices`로 확인한 뒤 `flutter run -d <기기>`로 실행합니다.
위 Chrome 명령은 개발용이며, 제품 UI는 지원 비율에 해당하는 모바일 세로
뷰포트에서 확인합니다.

## 검증

```sh
flutter analyze
flutter test
flutter build web --release
python3 tool/audit_lorespec.py repo_source/LORE_1993_src/LORESPEC.PAS --coverage
python3 tool/audit_messages.py
python3 tool/audit_source_memory.py --check
python3 tool/source_map25_guardian.py --check
python3 tool/source_map26_final.py --check
python3 tool/source_map23_keep3.py --check
python3 tool/build_port_contract_ledger.py --check
```

Windows에서 Python 도구의 이전 UTF-8 자료를 읽을 때는 `python -X utf8`을
사용합니다. 도구 회귀 검사는 `python -X utf8 -m unittest discover -s tool`로 실행합니다.

숫자 호환성은 `dart run tool/verify_source_memory.dart`로 확인합니다. 웹의
JavaScript 연산도 확인하려면 아래처럼 같은 검증기를 컴파일해 실행합니다.

```sh
dart compile js -O2 tool/verify_source_memory.dart -o build/source-memory-verification.js
node build/source-memory-verification.js
```

## 정적 웹 페이지 배포

로컬에서 WASM과 JavaScript 대체 버전을 함께 빌드한 뒤 GitHub Pages에 게시합니다.

```sh
python3 tool/build_web_release.py
```

빌드 도구는 로더에 기록된 모든 WASM 해시를 실제 파일과 대조한 뒤 기존 문서를 보존하며 `docs/`를 갱신합니다. 이전 빌드의 해시가 남아 있으면 한 번 재빌드하여 검사합니다. SDK 경로를 지정하려면 `--flutter /경로/flutter/bin/flutter`을 사용합니다.

소스와 이 프로젝트의 `docs/` 결과물을 `main`에 커밋·푸시하면 GitHub Actions가
`/lore/remake/`에 게시합니다. 저장소의 Pages Source는 `GitHub Actions`입니다.
배포 단계에서 base path를 `/lore/remake/`로 조정하며, 각 프로젝트의
커밋된 빌드 결과물을 게시합니다. Actions 자체에서는 Flutter 빌드를 실행하지 않습니다.

정적 서버는 `.wasm` 파일을 `application/wasm` 형식으로 제공해야 합니다. WASM GC를 지원하지 않는 브라우저에는 같은 빌드의 `main.dart.js`가 사용됩니다.

## 원본 출처

이 프로젝트는 [smgal/LoreTrilogy_1993](https://github.com/smgal/LoreTrilogy_1993)의 원본 소스를 참고하여 AI를 활용해 포팅하고 있습니다.

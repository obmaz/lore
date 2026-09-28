# Hadar2026 구조 분석

조사 기준: [`smgal/Hadar2026`의 `9a7a88f` 커밋](https://github.com/smgal/Hadar2026/tree/9a7a88f), 2026-09-29. 이 문서는 **실행 중인 코드**와 **설계 문서의 목표**를 구분한다. Hadar2026은 1993년 LORE를 Flutter/Dart로 복각하지만, 저장소의 직접 참조 구현은 이후의 C++/Unity 코드도 포함한다. 우리 이식의 동작 기준은 계속 `repo_source/LORE_1993_src/`의 Pascal 원본이다.

## 현재 실행 구조

```text
Flutter 입력·화면
  → HDGameMain (싱글턴 파사드, 포트 바인딩)
  → HDGameSession (현재 맵·파티·옵션)
  → MapNavigation/TileEventDispatcher
      → Dart 네이티브 맵 스크립트 | cm2 스크립트 | JSON 대사
  → UiHost/PartyMovementHost/AssetSource → Flutter 구현

전투: cm2 Battle 명령 → HDCm2BattleAdapter
  → hd_bridge: World 상태를 BattleSetup으로 변환
  → hd_battle: 명령/결정/사건/결과 상태기계
  → hd_bridge: 결과를 World에 정산
```

- `hadar2026_app/lib`는 `domain`·`application`·`presentation`으로 나뉘고, `HDGameMain`이 파사드 겸 조립 지점이다. `HDHosts`는 UI·이동·에셋 포트를 바인딩한다. 따라서 애플리케이션 흐름을 가짜 호스트로 실행할 수 있다. [파사드](https://github.com/smgal/Hadar2026/blob/9a7a88f/hadar2026_app/lib/hd_game_main.dart), [호스트 바인딩](https://github.com/smgal/Hadar2026/blob/9a7a88f/hadar2026_app/lib/application/ports/host_binding.dart)
- `hd_world`는 인물·장비·아이템을 `World.apply(Command) → Event[]`로 변경한다. 최종 능력치와 통행 능력은 읽을 때 계산한다. `hd_battle`은 `BattleSetup`과 시드로 시작하고 `pendingDecision`/`applyCommand`/`advance`를 통해 UI 없이 진행한다. `hd_bridge`가 두 모델 사이의 스냅샷과 정산을 맡는다. [World](https://github.com/smgal/Hadar2026/blob/9a7a88f/packages/hd_world/lib/src/model/world.dart), [Battle](https://github.com/smgal/Hadar2026/blob/9a7a88f/packages/hd_battle/lib/src/model/battle.dart), [Bridge](https://github.com/smgal/Hadar2026/blob/9a7a88f/packages/hd_bridge/lib/src/to_battle.dart)
- 지도는 JSON을 읽고 타일 코드에서 통행/상호작용 종류를 판정한다. 이벤트 디스패처의 우선순위는 네이티브 Dart 맵 스크립트 → 짝지은 cm2 → 정적 JSON 대사다. 맵 로딩과 전환은 세션이 담당한다. [타일 규칙](https://github.com/smgal/Hadar2026/blob/9a7a88f/hadar2026_app/lib/domain/map/tile_properties.dart), [디스패처](https://github.com/smgal/Hadar2026/blob/9a7a88f/hadar2026_app/lib/application/tile_event_dispatcher.dart), [세션](https://github.com/smgal/Hadar2026/blob/9a7a88f/hadar2026_app/lib/application/game_session.dart)

## 게임팩 관점에서의 실제 상태

| 항목 | 현재 코드 | 판단 |
| --- | --- | --- |
| 맵 | JSON 에셋과 `MapInfos.json` | 데이터 분리의 시작점. 타일 의미와 이벤트 처리 일부는 Dart 코드에 남음 |
| 대화·이벤트 | cm2 DSL, 4개 네이티브 Dart 맵 스크립트, JSON 대사 | 여러 경로가 공존. 한 종류의 게임팩 규칙으로 통합되지는 않음 |
| 몬스터·아이템·직업 | `hd_battle`/`hd_world`의 Dart 테이블과 규칙 | 엔진과 데이터의 경계는 뚜렷하지만 외부 팩으로 교체하는 인터페이스는 미완성 |
| 저장 | `party`, `gameSystem`, `gameOption`, 현재 맵 JSON을 SharedPreferences에 저장 | 네이티브 스크립트의 별도 `flags`/`variables`는 이 봉투에 포함되지 않음 |
| 선언형 콘텐츠 팩 | `blueprint/21_content_pack_spec.md` 등에 상세 설계 | `assets/content/`와 콘텐츠 런타임은 현재 트리에 없음. 결정 기록상 보류 |

실측한 에셋은 최상위 `assets/*.cm2` 18개, `assets/maps/*.json` 15개(맵 외 `MapInfos.json`·`books.json` 포함), 네이티브 맵 스크립트 4개다. 수량은 조사 커밋의 파일 개수이며 플레이 가능한 맵·시나리오의 완성도 수치가 아니다. [에셋](https://github.com/smgal/Hadar2026/tree/9a7a88f/hadar2026_app/assets), [네이티브 맵 등록](https://github.com/smgal/Hadar2026/blob/9a7a88f/hadar2026_app/lib/application/scripting/native_script_runner.dart), [팩 설계](https://github.com/smgal/Hadar2026/blob/9a7a88f/blueprint/21_content_pack_spec.md), [노선 변경 기록](https://github.com/smgal/Hadar2026/blob/9a7a88f/issues/DECISION-LOG.md)

## 재사용할 설계와 피할 결합

1. **재사용할 설계:** `명령 → 사건`의 순수 월드 모델, UI와 분리된 전투 상태기계, 월드와 전투 사이의 명시적 변환기, 에셋·UI 포트를 통한 헤드리스 실행. 이는 우리 `GAME_PACK_ARCHITECTURE.md`의 방향과 맞는다.
2. **원작 이식에는 직접 채택하지 않을 것:** Hadar2026의 전투·아이템 규칙은 자체 복각 및 확장 판단을 포함한다. 1993 Pascal의 수치·분기·난수 순서와 동등하다는 증거가 아니므로, 우리 원본형 프로시저 코어의 정답으로 사용하지 않는다.
3. **구조상 경계 문제:** `HDGameMain`, `HDGameSession`, 스크립트 엔진, 네이티브 러너 등이 싱글턴이고 플래그가 `gameOption`과 네이티브 러너에 나뉜다. 네이티브 맵 스크립트 기본 클래스의 `isFlagSet`/`setFlag`는 현재 스텁이다. 세이브도 네이티브 플래그를 기록하지 않는다. 여러 게임을 동시에 로드하거나 정확히 재생하려면 게임 세션별 단일 상태 소유권이 필요하다. [맵 스크립트 기본 클래스](https://github.com/smgal/Hadar2026/blob/9a7a88f/hadar2026_app/lib/application/scripting/map_script.dart), [저장 관리자](https://github.com/smgal/Hadar2026/blob/9a7a88f/hadar2026_app/lib/application/save_manager.dart)
4. **남은 구현 격차:** `Map::SetEncounter`는 등록만 되고 실제 구현은 스텁이다. 전투 내부는 시드로 재현 가능하지만 개시 시드는 기본적으로 시계에서 만든다. 게임 전체의 결정적 재생 계약과는 구분해야 한다. [cm2 어댑터](https://github.com/smgal/Hadar2026/blob/9a7a88f/hadar2026_app/lib/application/scripting/script_engine_adapter.dart), [전투 연결](https://github.com/smgal/Hadar2026/blob/9a7a88f/hadar2026_app/lib/application/battle_bridge/cm2_battle_adapter.dart)
5. **문서 판독 주의:** `blueprint/`의 팩·퀘스트·빌드 파이프라인은 자세하지만 구현 현황이 아니다. `issues/DECISION-LOG.md`는 선언형 팩 노선을 보류하고 샘플/`cm2` 중심으로 바꾼 사실을 기록한다. 구형 `docs/architecture.md`나 패키지 README의 진행 상태도 현재 코드와 다를 수 있으므로 코드·에셋을 확인해야 한다.

## 우리 이식에 적용하는 순서

1. Pascal 프로시저의 입력·상태 변경·난수 소비·효과 순서를 기준선으로 확정한다.
2. Hadar2026의 `World`/`Battle`처럼 UI가 호출하지 않는 세션 코어를 만들되, 상태는 게임 인스턴스별로 소유하고 단일 저장 봉투로 왕복시킨다.
3. 검증된 반복 규칙만 공통 명령/사건으로 추출한다. 맵·몬스터·대사 데이터에는 출처와 원본 식별자를 유지한다.
4. 같은 초기 상태·입력·난수열에서 원본형 코어와 게임팩 런타임의 결과를 대조한 뒤 한 경로씩 전환한다. Hadar2026은 아키텍처 참조 및 해석 교차 검증 자료이지 원본 동등성의 판정 기준은 아니다.

공개 저장소에 명시적 `LICENSE` 파일이 확인되지 않았으므로 코드를 직접 복사하는 문제는 별도로 검토한다. 이 문서는 구조와 동작을 분석한 기록이다.

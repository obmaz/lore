# LoreUWP 게임 로직 분석

조사 기준: [`mg2000/LoreUWP` `6678a1d`](https://github.com/mg2000/LoreUWP/tree/6678a1d)와 이 저장소의 `repo_source/LORE_1993_src`, `repo_source/LORE_1993_runtime`. 화면 렌더링과 스타일은 분석 범위에서 제외했다. **입력·메뉴·애니메이션 콜백에 들어 있는 상태 변경은 게임 로직이므로 포함**했다.

## 결론

LoreUWP는 파스칼 프로그램의 게임 규칙을 새로운 엔진으로 분해한 구현이 아니다. 원본의 전역 상태와 절차 흐름을 대체로 C# `GamePage` 안으로 옮긴 포트다. 따라서 Pascal 코드의 좌표·플래그·사건 의미를 읽는 **교차 자료**로 매우 유용하다. 그러나 UI 콜백과 규칙이 섞여 있고 확인된 차이도 있으므로, 원본을 대신하는 정답이나 화면 코드만 제거하면 얻어지는 독립 게임 코어는 아니다.

## 로직의 실제 위치

| 영역 | UWP 구현 | Pascal 대응 |
| --- | --- | --- |
| 파티·인물·적 상태 | [`LorePlayer`, `Lore`, `EnemyData`, `BattleEnemyData`](https://github.com/mg2000/LoreUWP/tree/6678a1d/Lore) | `LORESUB`의 레코드·전역 배열 |
| 생성 | [`NewGamePage.xaml.cs`](https://github.com/mg2000/LoreUWP/blob/6678a1d/Lore/NewGamePage.xaml.cs) 입력 콜백의 질문·능력치·동료 선택 | `LORECRET` |
| 이동·지형·입구 판정 | [`GamePage.xaml.cs` 311~680행](https://github.com/mg2000/LoreUWP/blob/6678a1d/Lore/GamePage.xaml.cs#L311) 키 입력 내부 | `LOREMAIN.Main`, `Move_Mode`, 지형 루틴, `LOREENT.entermode` |
| 입구 수락 후 지도·타일 변경 | [같은 파일 4965행 이후](https://github.com/mg2000/LoreUWP/blob/6678a1d/Lore/GamePage.xaml.cs#L4965) 메뉴 응답 내부 | `LOREENT`와 일부 `LORESPEC` |
| 전투 결과에 따른 이야기 진행 | [같은 파일 770행 이후](https://github.com/mg2000/LoreUWP/blob/6678a1d/Lore/GamePage.xaml.cs#L770) `EndBattle` | `LOREBATT` + `LORESPEC`/`LOREENT`의 후속 |
| 전투 규칙·적 AI | [같은 파일 5738~7186행](https://github.com/mg2000/LoreUWP/blob/6678a1d/Lore/GamePage.xaml.cs#L5738) | `LOREBATT` |
| 특수 사건·대화 | [7444행 `InvokeSpecialEvent`](https://github.com/mg2000/LoreUWP/blob/6678a1d/Lore/GamePage.xaml.cs#L7444), [9119행 `TalkMode`](https://github.com/mg2000/LoreUWP/blob/6678a1d/Lore/GamePage.xaml.cs#L9119), 1291행 이후의 대화 계속 처리 | `LORESPEC`, `LORETALK` |
| 지형 피해·무작위 조우 | [10962행 이후](https://github.com/mg2000/LoreUWP/blob/6678a1d/Lore/GamePage.xaml.cs#L10962) | `LOREMAIN`, `LOREBATT.EncounterEnemy` |
| 저장 | [`SaveData`](https://github.com/mg2000/LoreUWP/blob/6678a1d/Lore/SaveData.cs), [저장](https://github.com/mg2000/LoreUWP/blob/6678a1d/Lore/GamePage.xaml.cs#L5647), [로드](https://github.com/mg2000/LoreUWP/blob/6678a1d/Lore/GamePage.xaml.cs#L10816) | `LORESUB.Save`/`Load` |

`GamePage.xaml.cs`는 11,858행이며 `mParty`, `mPlayerList`, `mMapLayer`, `mEncounterEnemyList`, `mBattleEvent`, `mSpecialEvent`, `mMenuMode`를 한 객체가 소유한다. 선택 대기와 사건 재개는 메뉴 모드·특수 사건 열거형·키 입력 후속 콜백으로 표현된다. 예를 들어 입구는 `ShowEnterMenu`가 수락을 기다리고, `MenuMode.AskEnter`에서 지도 번호와 좌표를 바꾼다. 대화 후속은 키를 다시 누를 때 `InvokeSpecialEventLaterPart`가 진행한다. `InvokeAnimation`도 파티 좌표·맵 타일·다음 전투 사건을 바꾸므로 단순 화면 함수가 아니다. [입구 후속](https://github.com/mg2000/LoreUWP/blob/6678a1d/Lore/GamePage.xaml.cs#L4965), [대화 후속](https://github.com/mg2000/LoreUWP/blob/6678a1d/Lore/GamePage.xaml.cs#L1291), [애니메이션 후속](https://github.com/mg2000/LoreUWP/blob/6678a1d/Lore/GamePage.xaml.cs#L9976)

## 원본과 직접 확인한 일치점

- UWP의 `.MAP` **25개 파일 전부**가 `repo_source/LORE_1993_runtime`의 동명 파일과 SHA-256까지 같다. 맵 ID 1~27 중 일부가 같은 파일을 공유하는 것도 Pascal `LORESUB.Load`의 표와 일치한다. [UWP 맵 에셋](https://github.com/mg2000/LoreUWP/tree/6678a1d/Lore/Assets), [맵 로더](https://github.com/mg2000/LoreUWP/blob/6678a1d/Lore/GamePage.xaml.cs#L10645)
- UWP의 `enemyData.dat` 75행을 원본 `FOEDATA.DAT`의 29바이트 레코드 75개와 대조했다. 각 행의 숫자 필드 12개, 총 **900값의 차이가 0개**였다. 이름 문자열 인코딩은 이 검사 대상이 아니다. [UWP 적 자료](https://github.com/mg2000/LoreUWP/blob/6678a1d/Lore/Assets/enemyData.dat)
- 이동 타일의 `town/ground/den/keep` 구분과 타일 번호별 통행·표지판·입구·대화 분류는 `LOREMAIN.Main`을 거의 같은 순서로 옮겼다. C#의 좌표·배열은 0부터, Pascal은 1부터 세므로 `(19,10)`과 `(20,11)`처럼 **1 차이**는 정상 변환이다. `Etc` 플래그도 C# 인덱스가 Pascal보다 1 작다. [C# 이동 분기](https://github.com/mg2000/LoreUWP/blob/6678a1d/Lore/GamePage.xaml.cs#L399)
- 저장은 파티·인물과 **현재 맵의 변경된 타일 배열**을 함께 기록한다. 이는 Pascal이 저장 슬롯에 현재 맵 한 장을 기록하는 방식과 맞는다. [UWP 저장 자료](https://github.com/mg2000/LoreUWP/blob/6678a1d/Lore/SaveData.cs)

## 확인된 차이와 사용 시 주의점

1. **13번 맵의 무작위 조우가 다르다.** Pascal `LOREBATT.randomenemy`는 13번을 표에 넣지 않아 적 번호 `0`을 반환하며 `EncounterEnemy`가 즉시 끝난다. UWP `EncounterEnemy`도 13번을 표에서 빠뜨렸지만 기본값 `range=0, init=0`으로 적 생성을 계속해 `mEnemyDataList[0]`(오크)를 만든다. .NET의 [`Random.Next(0)`은 0을 반환](https://learn.microsoft.com/en-us/dotnet/api/system.random.next)한다. `DEN4.MAP`에는 이동 가능한 비영(非零) 타일이 많아 조우 검사에 진입할 수 있다. [UWP 조우](https://github.com/mg2000/LoreUWP/blob/6678a1d/Lore/GamePage.xaml.cs#L11238), 원본 `LOREBATT.PAS:1183-1226`.
2. **난수열의 동일성은 보장되지 않는다.** UWP는 기본 생성된 `System.Random`을 사용한다. Pascal `Randomize`/`Random`과 같은 시드·소비열을 재현하는 포트가 아니므로 수식과 분기 구조를 참고해도 실행 결과를 그대로 오라클로 삼을 수 없다. [UWP 난수 필드](https://github.com/mg2000/LoreUWP/blob/6678a1d/Lore/GamePage.xaml.cs#L135)
3. **DEBUG 빌드의 게임 규칙이 다르다.** 전투 경험치를 50,000으로 고정하고, 단일 공격 마법의 비용을 1로 만드는 `#if DEBUG` 분기가 있다. 규칙 대조는 `#else`의 출시용 수식으로 해야 한다. [경험치](https://github.com/mg2000/LoreUWP/blob/6678a1d/Lore/GamePage.xaml.cs#L5948), [마법 비용](https://github.com/mg2000/LoreUWP/blob/6678a1d/Lore/GamePage.xaml.cs#L6066)
4. **이름이 화면 함수여도 상태를 바꿀 수 있다.** `InvokeAnimation`은 맵 타일을 바꾸고 파티를 이동시키며 후속 전투를 예약한다. `ShowBattleResult`는 결과 출력 후 승패를 판정한다. 단순히 XAML/Canvas/Animation 메서드를 모두 버리면 원본 절차의 후반부를 잃는다. [애니메이션 함수](https://github.com/mg2000/LoreUWP/blob/6678a1d/Lore/GamePage.xaml.cs#L9976), [전투 결과 함수](https://github.com/mg2000/LoreUWP/blob/6678a1d/Lore/GamePage.xaml.cs#L5816)

## 우리 이식에 쓰는 방법

1. UWP를 **두 번째 주석 달린 구현**으로 활용한다. Pascal의 좌표·플래그 인덱스를 `+1`로 역변환해 사건 의미와 한국어 대사를 확인한다.
2. `GamePage.xaml.cs`에서 UI 문장이 아닌 **상태 읽기·변경, 난수, 조건, 선택 후속**을 추출해 Pascal 프로시저 장부에 연결한다. 함수 단위보다 `입력 → 중단 → 선택/전투 결과 → 재개` 경로를 한 단위로 본다.
3. Pascal과 UWP가 같으면 근거를 강화한다. 다르면 Pascal이 우선이며, 위 13번 맵 조우처럼 별도 차이 목록에 남긴다. UWP를 그대로 Dart로 재포팅하지 않는다.
4. 검증된 로직만 우리 원본형 세션 코어의 명령·상태·효과로 옮긴다. 화면·저장·애니메이션은 어댑터로 분리하되, 원작이 그 시점에 수행하던 상태 변화의 순서는 유지한다.

공개 저장소에서 명시적 `LICENSE` 파일은 확인되지 않았다. 이 분석은 원본과의 비교 자료이며 UWP 소스 코드의 직접 복사 여부는 별도로 검토한다.

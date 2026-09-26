/// 1993년 원작 LORESUB.PAS 필드 공통 유틸리티 이식.
///
/// - `LORESUB.PAS:986  wantenter(name)`  성문/동굴 입구 진입 확인
/// - `LORESUB.PAS:999  wantexit`         마을에서 밖으로 나갈 때 확인
/// - `LORESUB.PAS:1012 findgold(money)`  금화 발견 연출/보상
library;

/// 원작 `party.etc[n]` 의 보조 마법/환경 상태를 스크립트 조건에서 쓸 수 있게
/// 이름을 붙인 것이다(`_scriptContext()`가 상황에 따라 넣어 준다).
class LoreFieldLogic {
  /// LORESPEC.PAS 맵 20: 횃불은 퀴즈 미로의 이 구역에서만 한 칸 소모된다.
  static bool consumesTorch(int mapId, int x, int y) =>
      mapId == 20 && x >= 8 && x <= 42 && y >= 19 && y <= 43;

  /// 원작 `party.etc[3] > 0` - 늪위를 걷는 마법.
  static const String scriptFlagSwampWalk = 'swampWalkActive';

  /// 원작 `party.etc[4] > 0` - 공중 부상(용암 통과).
  static const String scriptFlagLevitate = 'levitateActive';

  /// 원작 `party.etc[1] > 0` - 마법의 횃불.
  static const String scriptFlagTorch = 'torchActive';

  /// 원작 `party.etc[2] > 0` - 물위를 걷는 마법.
  static const String scriptFlagWaterWalk = 'waterWalkActive';

  /// 원작 `party.etc[N] > 0` 을 그대로 쓴 이름.
  ///
  /// 기계적으로 옮긴 좌표 스크립트는 원작 조건을 `etcN` 으로 적으므로
  /// (`allFlags: ["etc5"]`), 상황 플래그와 **함께** 이 이름도 넘겨야 한다.
  static String etcCounter(int n) => 'etc$n';

  /// 원작 `party.etc[1] > 0` - 마법의 횃불.
  static const String etcTorch = 'etc1';

  /// 원작 `party.etc[2] > 0` - 물위를 걷는 마법.
  static const String etcWaterWalk = 'etc2';

  /// 원작 `party.etc[3] > 0` - 늪위를 걷는 마법.
  static const String etcSwampWalk = 'etc3';

  /// 원작 `party.etc[4] > 0` - 공중 부상(용암 통과).
  static const String etcLevitate = 'etc4';

  /// 원작 `party.etc[5] > 0` - 독심술(마음을 읽는 능력) 활성.
  ///
  /// ESP 메뉴 `[3] 독심술` 로 켜지고(원작 `party.etc[5] := 3`), 걸음/대화마다
  /// 줄어든다. Draconian·Red Antares 영입 제안과 Spica 상담이 이 조건을 본다.
  static const String etcMindRead = 'etc5';

  LoreFieldLogic._();

  // ── 성문/동굴 입구 확인 (wantenter / wantexit) ──

  /// 원작: `Print(11, name + ' 에 들어가기를 원합니까 ?')`
  static const String enterPromptSuffix = ' 에 들어가기를 원합니까 ?';

  /// 원작 `wantexit`: `Print(11, '여기서 나가기를 원합니까 ?')`
  static const String exitPrompt = '여기서 나가기를 원합니까 ?';

  /// 원작 선택지 `m[1]`.
  static const String confirmYes = '예, 그렇습니다.';

  /// 원작 선택지 `m[2]`.
  static const String confirmNo = '아니오, 원하지 않습니다.';

  static String enterPrompt(String placeName) => '$placeName$enterPromptSuffix';

  // ── 금화 발견 (findgold) ──

  /// 원작: `Print(7, '당신은 금화 ' + account + '개를 발견했다.')`
  static String goldFoundMessage(int amount) => '당신은 금화 $amount개를 발견했다.';

  /// 원작 `party.gold := party.gold + money`.
  static int applyGoldFound(int gold, int amount) => gold + amount;

  // ── 원작 공통 메시지 (LORESUB.PAS:1027~1037) ──

  /// `asyouwish` - 사용자가 선택을 취소했을 때.
  static const String asYouWish = '당신이 바란다면 ...';

  /// `notenoughmoney` - 금화 부족.
  static const String notEnoughMoney = '당신은 충분한 돈이 없습니다.';

  /// `thankyou` - 거래 성사.
  static const String thankYou = '매우 고맙습니다.';
}

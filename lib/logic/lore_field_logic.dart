/// 1993년 원작 LORESUB.PAS 필드 공통 유틸리티 이식.
///
/// - `LORESUB.PAS:986  wantenter(name)`  성문/동굴 입구 진입 확인
/// - `LORESUB.PAS:999  wantexit`         마을에서 밖으로 나갈 때 확인
/// - `LORESUB.PAS:1012 findgold(money)`  금화 발견 연출/보상
library;

class LoreFieldLogic {
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

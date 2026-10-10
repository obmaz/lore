/// LOREBATT.PAS BattleMode manual CASE stores (byte fields how/what/whom).
/// Target selection is a modern adapter; canceled menus retain source j.
class LoreBattleCommands {
  const LoreBattleCommands._();
  static List<int> manual({
    required int how,
    required int result,
    required int maxsum,
    required int target,
    required int weapon,
    bool targetUnavailable = false,
  }) {
    switch (how) {
      case 1:
        return [target == 0 ? 0 : 1, weapon & 255, target & 255];
      case 2:
      case 4:
        final canceled = result == 0 || result == 1;
        return [
          canceled ? 0 : how,
          (result - 1) & 255,
          (canceled ? maxsum : target) & 255,
        ];
      case 3:
        return [result == 0 || result == 1 ? 0 : 3, (result - 1) & 255, 0];
      case 6:
        return [
          result == 0 || targetUnavailable ? 0 : 6,
          result & 255,
          (result == 0 ? 5 : target) & 255,
        ];
      default:
        throw ArgumentError.value(
          how,
          'how',
          'not a manual target/spell command',
        );
    }
  }
}

/// BattleMode's manual attack menu ranges (including m[1] = None).
class LoreBattleMenus {
  const LoreBattleMenus._();
  static int maxsum(int how, int level) => switch (how) {
    2 => switch (level) {
      <= 1 => 2,
      <= 3 => 3,
      <= 7 => 4,
      <= 11 => 5,
      <= 15 => 6,
      _ => 7,
    },
    3 => switch (level) {
      <= 1 => 1,
      2 => 2,
      <= 5 => 3,
      <= 9 => 4,
      <= 13 => 5,
      <= 17 => 6,
      _ => 7,
    },
    4 => switch (level) {
      <= 4 => 1,
      <= 9 => 2,
      <= 11 => 3,
      <= 13 => 4,
      <= 15 => 5,
      <= 17 => 6,
      _ => 7,
    },
    6 => 5,
    _ => throw ArgumentError.value(how, 'how'),
  };
}

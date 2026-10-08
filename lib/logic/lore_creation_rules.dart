import '../models/party_member.dart';

/// Gameplay rules from LORECRET.PAS First, independent of presentation assets.
class LoreCreationRules {
  const LoreCreationRules._();

  static int? quizChoice(int key) => key >= 49 && key <= 51 ? key - 49 : null;

  /// Fresh Third flags; caller data cannot retain earlier quiz counters.
  static List<int> classFlags(List<int> stats) => [
    0,
    for (var id = 1; id <= 8; id++) classEligible(id, stats) ? 1 : 0,
  ];

  static int? selectClass(int key, List<int> flags) {
    final id = key - 48;
    return id > 0 && id < 9 && flags[id] == 1 ? id : null;
  }

  /// Third drains the available ReadKey bytes before interpreting the LAST.
  /// An extended key contributes both its zero byte and its scan byte.
  static int? selectClassQueue(List<int> keys, List<int> flags) =>
      keys.isEmpty ? null : selectClass(keys.last & 255, flags);

  /// WhatClass differs from ReturnClass specifically at class10 ('반신').
  static String classLabel(int id) => switch (id) {
    1 => '기사',
    2 => '마법사',
    3 => '에스퍼',
    4 => '전사',
    5 => '전투승',
    6 => '닌자',
    7 => '사냥꾼',
    8 => '떠돌이',
    9 => '혼령',
    10 => '반신',
    _ => '불확실함',
  };

  // The ten Which calls, each followed by three inc(transdata[N]) branches.
  static const questionStats = [
    [1, 2, 3],
    [1, 2, 4],
    [1, 2, 5],
    [1, 3, 4],
    [1, 3, 5],
    [1, 4, 5],
    [2, 3, 4],
    [2, 3, 5],
    [2, 4, 5],
    [3, 4, 5],
  ];

  static int statValue(int count) => switch (count) {
    0 => 5,
    1 => 7,
    2 => 11,
    3 => 14,
    4 => 17,
    5 => 19,
    6 => 20,
    _ => 10,
  };

  /// Third's class gates. Values are strength, mentality, concentration,
  /// endurance, resistance, agility, accuracy[1], luck, in that order.
  static bool classEligible(int id, List<int> stats) {
    final [
      strength,
      mentality,
      concentration,
      endurance,
      resistance,
      agility,
      accuracy,
      luck,
    ] = stats;
    return switch (id) {
      1 => strength > 13 && endurance > 13 && agility > 11 && accuracy > 11,
      2 => mentality > 13 && accuracy > 14,
      3 => mentality > 10 && concentration > 13 && accuracy > 12,
      4 =>
        strength > 13 &&
            mentality > 10 &&
            endurance > 10 &&
            resistance > 10 &&
            accuracy > 13,
      5 => strength > 16 && agility > 13 && accuracy > 11,
      6 => resistance > 16 && agility > 16 && luck > 9,
      7 => accuracy > 18,
      8 => true,
      _ => false,
    };
  }

  /// 1-based transdata in; strength, mentality, concentration, endurance,
  /// resistance out. Preserve source overflow carry order for the sex bonus.
  static List<int> quizResult(List<int> transdata, Gender gender) {
    final stats = [for (var i = 1; i <= 5; i++) statValue(transdata[i])];
    var carry = 4;
    final indices = gender == Gender.male ? [0, 3] : [1, 2];
    for (final index in indices) {
      stats[index] += carry;
      if (stats[index] <= 20) {
        carry = 0;
      } else {
        carry = stats[index] - 20;
        stats[index] = 20;
      }
    }
    stats[4] += carry;
    if (stats[4] > 20) stats[4] = 20;
    return stats;
  }
}

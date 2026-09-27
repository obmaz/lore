/// Source-shaped procedures from `LOREMAIN.PAS`.
///
/// Effects are callbacks so the procedure keeps Pascal's mutation, display,
/// random, and encounter order without depending on Flutter or Flame.
class LoreMainProcedures {
  LoreMainProcedures._();

  /// `LOREMAIN.PAS:19-27`, including the no-spell `originposition` branch.
  static void enterWater({
    required int Function() waterWalkSteps,
    required void Function(int steps) setWaterWalkSteps,
    required void Function() scrollToParty,
    required int encounterFrequency,
    required int Function(int exclusiveUpperBound) random,
    required void Function() encounterEnemy,
    required void Function() restorePosition,
  }) {
    final steps = waterWalkSteps();
    if (steps > 0) {
      setWaterWalkSteps(steps - 1);
      scrollToParty();
      if (random(encounterFrequency * 30) == 0) encounterEnemy();
    } else {
      restorePosition();
    }
  }
}

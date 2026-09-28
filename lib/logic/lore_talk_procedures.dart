import '../data/lore_script.dart';

/// Gameplay branches from `LORETALK.PAS:talkmode`.
///
/// Dispatches dialogue/interaction sequences in Pascal source order.
/// Facilities are checked first (Weapon shop, Hospital, Train center, Grocery),
/// then map-specific procedures evaluate coordinates, conditions, dialogue,
/// selections, and flag/tile modifications.
class LoreTalkProcedures {
  LoreTalkProcedures._();

  /// `LORETALK.PAS:17-383`, map 6 (TOWN2 / LORE CASTLE / 시작의 성).
  ///
  /// Evaluates in Pascal source order:
  /// 1. `(9, 64)`: Guard talk (`Serpent, Insects, Python` poison warning).
  /// 2. `(72, 73)`: Villager (`Orc`).
  /// 3. `(51, 72)`: Sage talk (`party.etc[50]` bit5):
  ///    - If bit5 == 0: Pyramid info, sets bit5 (`menaceInfoGiven`).
  ///    - Else: MENACE monsters info.
  /// 4. `(58, 74)`: Villager (`Python`).
  /// 5. `(63, 27)`: Scholar (Lord Ahn & Necromancer).
  /// 6. `(90, 82)`: Resident (Ancient Evil & Lord Ahn).
  /// 7. `(94, 68)`: Hunter (Food tree in MENACE east).
  /// 8. `(19, 53)`: Ancient tablet (Creator tribute).
  /// 9. `(13, 27)` or `(18, 27)`: Bartender (Hero sex check / whisky).
  /// 10. `(21, 33)`: '...'
  /// 11. `(10, 30)`: Ghost rumor in cemetery.
  /// 12. `(13, 32)`: Drinker cheer.
  /// 13. `(15, 35)`: Drinker ranting about Lord Ahn.
  /// 14. `(18, 33)`: Villager complaint about Skeleton.
  /// 15. `(21, 36)`: '... zzz ...'
  /// 16. `(18, 38)`: Old villager legend of LORE.
  /// 17. `(72, 78)`: Gravedigger warning.
  /// 18. `(63, 76)`: Jr. Antares spirit (`party.etc[50]` bit1):
  ///     - If bit1 == 0: Secret path open (`map[62,79..81]:=44`, `62,82:=0`, `62,83:=14`), sets bit1.
  /// 19. `(24, 50)`: Friend encouragement (hero name).
  /// 20. `(24, 54)`: Villager info (weapons and food).
  /// 21. `(13, 55)`: Villager info (Polaris in LASTDITCH).
  /// 22. `(50, 11)`: Prison guard warning.
  /// 23. `(53, 11)`: Guard info (dissidents imprisoned).
  /// 24. `(41, 10)`: Imprisoned knight tale (Ancient Evil).
  /// 25. `(40, 15)`: Mad Joe recruit select (`party.etc[50]` bit2):
  ///     - If bit2 == 0: select accept -> join(1, 6), `map[40,15]:=47`, sets bit2.
  /// 26. `(63, 10)`: Imprisoned thief info (Golden Shield in MENACE).
  /// 27. `(60, 15)`: Prisoner warning about Joe.
  /// 28. `(42, 78)` or `(42, 80)`: Guard info (`party.etc[50]` bit4).
  /// 29. `(51, 14)`: Villager rumor.
  /// 30. `(83, 27)`: Villager info.
  /// 31. Facilities:
  ///     - Grocery at `(87, 73)`, `(91, 65)`
  ///     - Weapon shop at `(8, 71)`, `(14, 69)`, `(14, 73)`
  ///     - Hospital at `(87, 14)`, `(86, 12)`
  ///     - Training center at `(21, 12)`, `(25, 13)`
  /// 32. `(50, 51)` or `(52, 51)`: Challenge gate (`party.etc[30]` bit1, `party.etc[10] < 3` check):
  ///     - If bit1 == 1: already open greeting.
  ///     - Else if quest < 3: blocked.
  ///     - Else: Prompt (Y/n) -> open gate (`map[49..53, 52..53]`), sets bit1.
  /// 33. `(51, 87)`: Castle exit blessing (`party.etc[30]` bit2):
  ///     - If bit2 == 0: open outer gates (`map[49..53, 88]:=44`), sets bit2.
  ///     - Else: farewell.
  /// 34. `(x in 48..54, y in 31..37)`: Inner castle guards:
  ///     - If quest == 0: blocked.
  ///     - Else: allowed.
  /// 35. `(51, 28)`: Lord Ahn audience (`party.etc[10]` 0..6 step dialogue/progression).
  static ScriptRun? map6(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if (!scripts.usingJson) return null;

    // 1. (9, 64)
    if (x == 9 && y == 64) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-6-9-64'),
        context,
      );
    }

    // 2. (72, 73)
    if (x == 72 && y == 73) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-6-72-73'),
        context,
      );
    }

    // 3. (51, 72)
    if (x == 51 && y == 72) {
      final hasBit5 =
          context.flags.contains('menaceInfoGiven') ||
          context.flags.contains('etc50_bit5');
      final scriptId = hasBit5 ? 'talk-6-51-72-b' : 'talk-6-51-72';
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == scriptId),
        context,
      );
    }

    // 4. (58, 74)
    if (x == 58 && y == 74) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-6-58-74'),
        context,
      );
    }

    // 5. (63, 27)
    if (x == 63 && y == 27) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-6-63-27'),
        context,
      );
    }

    // 6. (90, 82)
    if (x == 90 && y == 82) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-6-90-82'),
        context,
      );
    }

    // 7. (94, 68)
    if (x == 94 && y == 68) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-6-94-68'),
        context,
      );
    }

    // 8. (19, 53)
    if (x == 19 && y == 53) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-6-19-53'),
        context,
      );
    }

    // 9. (13, 27) or (18, 27)
    if ((x == 13 || x == 18) && y == 27) {
      final scriptId = x == 13 ? 'talk-6-13-27' : 'talk-6-18-27';
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == scriptId),
        context,
      );
    }

    // 10. (21, 33)
    if (x == 21 && y == 33) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-6-21-33'),
        context,
      );
    }

    // 11. (10, 30)
    if (x == 10 && y == 30) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-6-10-30'),
        context,
      );
    }

    // 12. (13, 32)
    if (x == 13 && y == 32) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-6-13-32'),
        context,
      );
    }

    // 13. (15, 35)
    if (x == 15 && y == 35) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-6-15-35'),
        context,
      );
    }

    // 14. (18, 33)
    if (x == 18 && y == 33) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-6-18-33'),
        context,
      );
    }

    // 15. (21, 36)
    if (x == 21 && y == 36) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-6-21-36'),
        context,
      );
    }

    // 16. (18, 38)
    if (x == 18 && y == 38) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-6-18-38'),
        context,
      );
    }

    // 17. (72, 78)
    if (x == 72 && y == 78) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-6-72-78'),
        context,
      );
    }

    // 18. (63, 76)
    if (x == 63 && y == 76) {
      final hasBit1 =
          context.flags.contains('jrAntaresSecretFound') ||
          context.flags.contains('etc50_bit1');
      if (!hasBit1) {
        return scripts.startProcedure(
          scripts.scripts.singleWhere((s) => s.id == 'talk-6-63-76'),
          context,
        );
      }
      return null; // 이미 통로를 연 후에는 재방문 대화(dialogues.json)로 위임
    }

    // 19. (24, 50)
    if (x == 24 && y == 50) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-6-24-50'),
        context,
      );
    }

    // 20. (24, 54)
    if (x == 24 && y == 54) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-6-24-54'),
        context,
      );
    }

    // 21. (13, 55)
    if (x == 13 && y == 55) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-6-13-55'),
        context,
      );
    }

    // 22. (50, 11)
    if (x == 50 && y == 11) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-6-50-11'),
        context,
      );
    }

    // 23. (53, 11)
    if (x == 53 && y == 11) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-6-53-11'),
        context,
      );
    }

    // 24. (41, 10)
    if (x == 41 && y == 10) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-6-41-10'),
        context,
      );
    }

    // 25. (40, 15)
    if (x == 40 && y == 15) {
      final hasJoe =
          context.flags.contains('madJoeJoined') ||
          context.flags.contains('etc50_bit2');
      if (!hasJoe) {
        return scripts.startProcedure(
          scripts.scripts.singleWhere((s) => s.id == 'madjoe-join'),
          context,
        );
      }
      return null; // 영입 후에는 재방문 대화(dialogues.json)로 위임
    }

    // 26. (63, 10)
    if (x == 63 && y == 10) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-6-63-10'),
        context,
      );
    }

    // 27. (60, 15)
    if (x == 60 && y == 15) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-6-60-15'),
        context,
      );
    }

    // 28. (42, 78) or (42, 80)
    if ((x == 42 && y == 78) || (x == 42 && y == 80)) {
      final hasBit4 =
          context.flags.contains('weaponRoomVisited') ||
          context.flags.contains('etc50_bit4');
      final scriptId = (x == 42 && y == 78)
          ? (hasBit4 ? 'talk-6-42-78-b' : 'talk-6-42-78')
          : (hasBit4 ? 'talk-6-42-80-b' : 'talk-6-42-80');
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == scriptId),
        context,
      );
    }

    // 29. (51, 14)
    if (x == 51 && y == 14) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-6-51-14'),
        context,
      );
    }

    // 30. (83, 27)
    if (x == 83 && y == 27) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-6-83-27'),
        context,
      );
    }

    // 32. (50, 51) or (52, 51)
    if ((x == 50 || x == 52) && y == 51) {
      final hasBit1 =
          context.flags.contains('loreChallengeAccepted') ||
          context.flags.contains('etc30_bit1');
      if (hasBit1) {
        final scriptId = x == 50 ? 'talk-6-50-51-a' : 'talk-6-52-51-a';
        return scripts.startProcedure(
          scripts.scripts.singleWhere((s) => s.id == scriptId),
          context,
        );
      }
      final lordAhnStep = context.questSteps['lordahn'] ?? 0;
      if (lordAhnStep < 3) {
        final scriptId = x == 50 ? 'talk-6-50-51-b' : 'talk-6-52-51-b';
        return scripts.startProcedure(
          scripts.scripts.singleWhere((s) => s.id == scriptId),
          context,
        );
      }
      final scriptId = x == 50 ? 'talk-6-50-51-c' : 'talk-6-52-51-c';
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == scriptId),
        context,
      );
    }

    // 33. (51, 87)
    if (x == 51 && y == 87) {
      final hasBit2 =
          context.flags.contains('loreChallengeBlessed') ||
          context.flags.contains('etc30_bit2');
      final scriptId = hasBit2 ? 'talk-6-51-87-b' : 'talk-6-51-87';
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == scriptId),
        context,
      );
    }

    // 34. x in 48..54 and y in 31..37
    if (x >= 48 && x <= 54 && y >= 31 && y <= 37) {
      final lordAhnStep = context.questSteps['lordahn'] ?? 0;
      final scriptId = lordAhnStep == 0 ? 'talk-6-gate-a' : 'talk-6-gate-b';
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == scriptId),
        context,
      );
    }

    // 35. (51, 28) - Lord Ahn
    if (x == 51 && y == 28) {
      final step = context.questSteps['lordahn'] ?? 0;
      final clamped = step.clamp(0, 6);
      final scriptId = 'talk-6-51-28-q$clamped';
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == scriptId),
        context,
      );
    }

    return null;
  }
}

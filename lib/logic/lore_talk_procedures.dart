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
      return null; // 원본 `at(63,76) and (etc[50] and bit1 = 0)`: 이미 열었으면 아무것도 찍지 않는다
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
      return null; // 원본 `at(37,41) and (etc[13] < 2)`: 영입 뒤에는 아무것도 찍지 않는다
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

  /// `LORETALK.PAS:384-480`, map 7 (TOWN3 / LASTDITCH / 최후의 요새).
  ///
  /// Evaluates in Pascal source order:
  /// 1. `(51, 55)`: Villager (LASTDITCH & VALIANT PEOPLES resemblance).
  /// 2. `(8, 44)`: Resident (Five continents).
  /// 3. `(68, 35)`: Resident (Southern continent frozen).
  /// 4. `(43, 9)`: Villager (PYRAMID monsters undead).
  /// 5. `(65, 10)`: Resident (GROUND GATE east).
  /// 6. `(14, 68)`: Resident (LORE continent hunter).
  /// 7. `(57, 42)`: Resident (Major Mummy & Sphinx).
  /// 8. `(44, 34)`: Resident (GROUND GATE connects to other continents).
  /// 9. `(32, 56)`: Resident (LORE continent Lord Ahn).
  /// 10. `(36,19)`, `(36,21)`, `(41,18)`, `(41,20)`, `(41,22)`, `(40,41)`:
  ///     Inner gates guarded by `party.etc[13]` (lastditch quest):
  ///     - If etc[13] == 0: blocked.
  ///     - Else: allowed.
  /// 11. `(37, 41)`: Polaris recruit select (`party.etc[13] < 2`):
  ///     - If etc[13] < 2: select accept -> join(9, ReturnJoinMember), `map[37,41]:=44`.
  ///     - Else: prints nothing (the source has no else branch).
  /// 12. Facilities:
  ///     - Training center at `(18,19)`, `(24,19)`, `(21,21)`, `(16,24)`
  ///     - Grocery at `(57,17)`, `(54,20)`, `(58,22)`, `(59,25)`
  ///     - Weapon shop at `(59,56)`, `(59,58)`, `(59,60)`
  ///     - Hospital at `(17,56)`, `(17,58)`, `(17,60)`
  /// 13. `(38, 17)`: LASTDITCH Lord audience (`party.etc[13]` 0..3 step dialogue/progression):
  ///     - Step 0: Major Mummy request, inc etc[13].
  ///     - Step 1: Reminder about Major Mummy.
  ///     - Step 2: Victory reward (EXP + 10000), inc etc[13].
  ///     - Step 3: GROUND GATE / VALIANT PEOPLES info.
  static ScriptRun? map7(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if (!scripts.usingJson) return null;

    // 1. (51, 55)
    if (x == 51 && y == 55) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-7-51-55'),
        context,
      );
    }

    // 2. (8, 44)
    if (x == 8 && y == 44) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-7-8-44'),
        context,
      );
    }

    // 3. (68, 35)
    if (x == 68 && y == 35) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-7-68-35'),
        context,
      );
    }

    // 4. (43, 9)
    if (x == 43 && y == 9) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-7-43-9'),
        context,
      );
    }

    // 5. (65, 10)
    if (x == 65 && y == 10) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-7-65-10'),
        context,
      );
    }

    // 6. (14, 68)
    if (x == 14 && y == 68) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-7-14-68'),
        context,
      );
    }

    // 7. (57, 42)
    if (x == 57 && y == 42) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-7-57-42'),
        context,
      );
    }

    // 8. (44, 34)
    if (x == 44 && y == 34) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-7-44-34'),
        context,
      );
    }

    // 9. (32, 56)
    if (x == 32 && y == 56) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-7-32-56'),
        context,
      );
    }

    // 10. (36,19), (36,21), (41,18), (41,20), (41,22), (40,41)
    if ((x == 36 && (y == 19 || y == 21)) ||
        (x == 41 && (y == 18 || y == 20 || y == 22)) ||
        (x == 40 && y == 41)) {
      final step = context.questSteps['lastditch'] ?? 0;
      final suffix = step == 0 ? 'a' : 'b';
      final scriptId = 'talk-7-$x-$y-$suffix';
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == scriptId),
        context,
      );
    }

    // 11. (37, 41) - Polaris
    if (x == 37 && y == 41) {
      final step = context.questSteps['lastditch'] ?? 0;
      final hasPolaris = context.flags.contains('polarisJoined') || step >= 2;
      if (!hasPolaris) {
        return scripts.startProcedure(
          scripts.scripts.singleWhere((s) => s.id == 'polaris-join'),
          context,
        );
      }
      return null;
    }

    // 13. (38, 17) - LASTDITCH 성주
    if (x == 38 && y == 17) {
      final step = context.questSteps['lastditch'] ?? 0;
      final clamped = step.clamp(0, 3);
      final scriptId = 'talk-7-38-17-q$clamped';
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == scriptId),
        context,
      );
    }

    return null;
  }

  /// `LORETALK.PAS:481-580`, map 9 (TOWN4 / GAIA TERRA / 대지의 마을).
  ///
  /// Evaluates in Pascal source order:
  /// 1. Facilities:
  ///    - Training center at `(12,11)`, `(15,12)`, `(12,15)`
  ///    - Grocery at `(40,37)`, `(37,39)`, `(41,41)`
  ///    - Weapon shop at `(37,10)`, `(40,12)`, `(41,15)`
  ///    - Hospital at `(9,39)`, `(12,41)`, `(16,40)`
  /// 2. `(24, 38)`: Villager (EVIL SEAL Golden Seal).
  /// 3. `(23, 12)`: Villager (Golden Seal in QUAKE).
  /// 4. `(28, 18)`: Villager (VALIANT PEOPLES & Necromancer).
  /// 5. `(30, 31)`: Villager (Rigel went to EVIL SEAL).
  /// 6. `(34, 38)`: Villager (Way to SWAMP).
  /// 7. `(38, 14)`: Villager (Monsters in QUAKE).
  /// 8. `(15, 42)`: Villager (Wivern in WATER FIELD).
  /// 9. `(26, 7)`: Villager (SWAMP continent).
  /// 10. `(34,24)`, `(37,24)`, `(41,24)`, `(35,27)`, `(38,27)`, `(41,27)`:
  ///     Inner gates guarded by `party.etc[14]` (gaia quest):
  ///     - If etc[14] == 0: blocked.
  ///     - Else: allowed.
  /// 11. `(42, 25)`: GAIA TERRA Lord audience (`party.etc[14]` 0..6 step dialogue/progression):
  ///     - Step 0: Golden Seal request, inc etc[14].
  ///     - Step 1: Reminder about Golden Seal.
  ///     - Step 2: Victory reward (EXP + 10000), inc etc[14].
  ///     - Step 3: QUAKE / ArchiGagoyle request, inc etc[14].
  ///     - Step 4: Reminder about ArchiGagoyle.
  ///     - Step 5: Victory reward (EXP + 40000, Water Key), inc etc[14].
  ///     - Step 6: Guidance to WATER FIELD.
  static ScriptRun? map9(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if (!scripts.usingJson) return null;

    if (x == 24 && y == 38) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-9-24-38'),
        context,
      );
    }
    if (x == 23 && y == 12) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-9-23-12'),
        context,
      );
    }
    if (x == 28 && y == 18) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-9-28-18'),
        context,
      );
    }
    if (x == 30 && y == 31) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-9-30-31'),
        context,
      );
    }
    if (x == 34 && y == 38) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-9-34-38'),
        context,
      );
    }
    if (x == 38 && y == 14) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-9-38-14'),
        context,
      );
    }
    if (x == 15 && y == 42) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-9-15-42'),
        context,
      );
    }
    if (x == 26 && y == 7) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-9-26-7'),
        context,
      );
    }

    // 10. Inner gates
    if ((x == 34 && y == 24) ||
        (x == 37 && y == 24) ||
        (x == 41 && y == 24) ||
        (x == 35 && y == 27) ||
        (x == 38 && y == 27) ||
        (x == 41 && y == 27)) {
      final step = context.questSteps['gaia'] ?? 0;
      final suffix = step == 0 ? 'a' : 'b';
      final scriptId = 'talk-9-$x-$y-$suffix';
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == scriptId),
        context,
      );
    }

    // 11. (42, 25) - GAIA TERRA Lord
    if (x == 42 && y == 25) {
      final step = context.questSteps['gaia'] ?? 0;
      final clamped = step.clamp(0, 6);
      final scriptId = 'talk-9-42-25-q$clamped';
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == scriptId),
        context,
      );
    }

    return null;
  }

  /// `LORETALK.PAS:581-705`, map 10 (TOWN1 / WATER FIELD / 수도 로어).
  ///
  /// Evaluates in Pascal source order:
  /// 1. Facilities:
  ///    - Training center at `(36,32)`, `(38,33)`, `(39,35)`
  ///    - Grocery at `(17,57)`, `(12,59)`, `(11,55)`
  ///    - Weapon shop at `(11,30)`, `(11,32)`, `(13,34)`
  ///    - Hospital at `(33,60)`, `(35,54)`, `(41,58)`
  /// 2. `(11, 16)`: Villager (Hidra in NOTICE).
  /// 3. `(14, 18)`: Villager (NOTICE maze).
  /// 4. `(24, 22)`: Villager (Minotaur in LOCKUP).
  /// 5. `(27, 22)`: Villager (Minotaur Necromancer servant).
  /// 6. `(24, 69)`: Villager (Huge Dragon in LOCKUP).
  /// 7. `(37, 16)`: Villager (Necromancer curse).
  /// 8. `(40, 18)`: Villager (Stheno & Euryale).
  /// 9. `(40, 56)`: Lore Hunter recruit select:
  ///    - select accept -> join(39, ReturnJoinMember), `map[40,56]:=44`, sets `etc38_bit4`.
  /// 10. `(25, 18)`: WATER FIELD Lord audience (`party.etc[15]` 0..5 step dialogue/progression):
  ///     - Step 0: Hidra request, inc etc[15].
  ///     - Step 1: Reminder about Hidra.
  ///     - Step 2: Victory reward (EXP + 150000), inc etc[15].
  ///     - Step 3: Huge Dragon request, inc etc[15].
  ///     - Step 4: Victory reward (EXP + 300000, Swamp Key), inc etc[15].
  ///     - Step 5: Guidance to GAIA TERRA / SWAMP.
  static ScriptRun? map10(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if (!scripts.usingJson) return null;

    if (x == 11 && y == 16) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-10-11-16'),
        context,
      );
    }
    if (x == 14 && y == 18) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-10-14-18'),
        context,
      );
    }
    if (x == 24 && y == 22) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-10-24-22'),
        context,
      );
    }
    if (x == 27 && y == 22) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-10-27-22'),
        context,
      );
    }
    if (x == 24 && y == 69) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-10-24-69'),
        context,
      );
    }
    if (x == 37 && y == 16) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-10-37-16'),
        context,
      );
    }
    if (x == 40 && y == 18) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-10-40-18'),
        context,
      );
    }

    // 9. (40, 56) - Lore Hunter
    if (x == 40 && y == 56) {
      final hasHunter =
          context.flags.contains('loreHunterJoined') ||
          context.flags.contains('etc38_bit4');
      if (!hasHunter) {
        return scripts.startProcedure(
          scripts.scripts.singleWhere((s) => s.id == 'lorehunter-join'),
          context,
        );
      }
      return null;
    }

    // 10. (25, 18) - WATER FIELD Lord
    if (x == 25 && y == 18) {
      final step = context.questSteps['water'] ?? 0;
      final clamped = step.clamp(0, 5);
      final scriptId = 'talk-10-25-18-q$clamped';
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == scriptId),
        context,
      );
    }

    return null;
  }

  /// `LORETALK.PAS:706-740`, map 24 (K_DEN1 / LAST SHELTER / 피난처).
  ///
  /// Evaluates in Pascal source order:
  /// 1. Facilities:
  ///    - Training center at `(11,22)`, `(14,24)`
  ///    - Grocery at `(33,35)`, `(35,37)`, `(41,38)`
  ///    - Weapon shop at `(33,21)`, `(37,24)`, `(40,23)`
  ///    - Hospital at `(15,36)`, `(11,38)`, `(14,40)`
  /// 2. `(17, 15)`: Ancient Evil disappeared.
  /// 3. `(18, 10)`: Resident advice.
  /// 4. `(20, 13)`: Ancient Evil protected us.
  /// 5. `(27, 8)`: Ancient Evil went to last dungeon.
  /// 6. `(31, 13)`: Monsters gathered in darkness.
  /// 7. `(33, 10)`: Creator Ahn Young-gi talk:
  ///    - sets `etc43_bit4` (`programmerMet`), `map[33,10]:=47`.
  static ScriptRun? map24(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if (!scripts.usingJson) return null;

    if (x == 17 && y == 15) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-24-17-15'),
        context,
      );
    }
    if (x == 18 && y == 10) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-24-18-10'),
        context,
      );
    }
    if (x == 20 && y == 13) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-24-20-13'),
        context,
      );
    }
    if (x == 27 && y == 8) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-24-27-8'),
        context,
      );
    }
    if (x == 31 && y == 13) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-24-31-13'),
        context,
      );
    }

    // 7. (33, 10) - Creator Ahn Young-gi
    if (x == 33 && y == 10) {
      return scripts.startProcedure(
        scripts.scripts.singleWhere((s) => s.id == 'talk-24-33-10'),
        context,
      );
    }

    return null;
  }

  /// `LORETALK.PAS:741-1062`, map 27 (PYRAMID1 / ANOTHER LORE / 운명의 피라미드).
  ///
  /// Evaluates in Pascal source order:
  /// 1. `(15, 6)`: Hero spirit dialogue, sets target tile to 52.
  /// 2. `(10, 14)`: Red Antares spirit dialogue, sets target tile to 35.
  /// 3. `(10, 18)`: Albireo spirit dialogue, sets target tile to 35.
  /// 4. `(10, 30)`: Deneb spirit dialogue, sets target tile to 35.
  /// 5. `(21, 32)`: Canopus spirit dialogue, sets target tile to 35.
  /// 6. `(21, 22)`: Arcturus spirit dialogue, sets target tile to 35.
  /// 7. `(21, 12)`: Parchment reading choice:
  ///    - Option 1: Read prophecy, sets target tile to 35.
  ///    - Option 2: Pass through.
  /// 8. Default fallback: other bones turn to ash, sets target tile to 35.
  static ScriptRun? map27(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if (!scripts.usingJson) return null;

    final scriptId = switch ((x, y)) {
      (15, 6) => 'talk-27-15-6',
      (10, 14) => 'talk-27-10-14',
      (10, 18) => 'talk-27-10-18',
      (10, 30) => 'talk-27-10-30',
      (21, 32) => 'talk-27-21-32',
      (21, 22) => 'talk-27-21-22',
      (21, 12) => 'talk-27-21-12',
      _ => 'talk-27-any',
    };

    return scripts.startProcedure(
      scripts.scripts.singleWhere((s) => s.id == scriptId),
      context,
    );
  }
}

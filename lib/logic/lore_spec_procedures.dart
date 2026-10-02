import '../data/lore_script.dart';
import 'lore_source_memory.dart';

/// Gameplay branches from `LORESPEC.specialevent_part1`.
///
/// Each branch returns ordered effects for the shared script interpreter. The
/// visual `scroll`/`Clear` calls remain with the field presentation adapter.
class LoreSpecProcedures {
  LoreSpecProcedures._();

  /// `LORESPEC.PAS:190-305`, map 6 (Castle LORE).
  ///
  /// The ordered guards evaluate:
  /// 1. `(62, 82)`: treasure chest (gold 1000, tile 44).
  /// 2. `(51, 12)` or `(52, 12)`: prison guard battle.
  ///    - Guarded by `etc50_bit2` / `madJoeJoined`.
  ///    - Return encounter: `prison-battle-return` (7 soldiers).
  ///    - First encounter: `prison-battle-first` (2 soldiers).
  /// 3. `(41, 79)`: weapon room.
  ///    - Guarded by not `etc50_bit4` / `weaponRoomVisited`.
  ///    - Nudges player west 3 times, sets tile 44, gives basic weapons.
  /// 4. Exit branch:
  ///    - Evaluated at castle exit portal (`castle-exit-skeleton`) via
  ///      [LorePortalSession].
  static ScriptRun? map6(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if (!scripts.usingJson || context.tileAtPlayer != 0) return null;

    // 1. on(62,82) - 상자
    if (x == 62 && y == 82) {
      final content = scripts.scripts.singleWhere(
        (script) => script.id == 'spec-6-L190',
      );
      return scripts.startProcedure(content, context);
    }

    // 2. on(51,12) or on(52,12) - 감옥 전투
    if ((x == 51 || x == 52) && y == 12) {
      final hasMadJoe =
          context.flags.contains('madJoeJoined') ||
          context.flags.contains('etc50_bit2');
      if (!hasMadJoe || context.flags.contains('prisonBattleDone')) {
        return null;
      }
      final isReturn =
          context.flags.contains('prisonBattleStarted') ||
          context.flags.contains('etc50_bit3');
      final scriptId = isReturn
          ? 'prison-battle-return'
          : 'prison-battle-first';
      final content = scripts.scripts.singleWhere(
        (script) => script.id == scriptId,
      );
      return scripts.startProcedure(content, context);
    }

    // 3. on(41,79) - 무기실
    if (x == 41 && y == 79) {
      final visited =
          context.flags.contains('weaponRoomVisited') ||
          context.flags.contains('etc50_bit4');
      if (visited) return null;
      final content = scripts.scripts.singleWhere(
        (script) => script.id == 'lore-weapon-room',
      );
      return scripts.startProcedure(content, context);
    }

    return null;
  }

  /// `LORESPEC.PAS:306-331`, map 7 (LASTDITCH).
  ///
  /// The ordered guards evaluate:
  /// 1. `x == 50`: GROUND GATE portal to map 8 (handled via portal session).
  /// 2. `x == 30` or `x == 32`: secret passage wall at `(31, y)` opens (tile 45).
  /// 3. `y == 71`: exit to map 1 (handled via portal session).
  static ScriptRun? map7(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if (context.tileAtPlayer != 0) return null;

    if (x == 30 || x == 32) {
      return scripts.startProcedure(
        LoreScript(
          id: x == 30 ? 'lastditch-passwall-left' : 'lastditch-passwall-right',
          trigger: 'step',
          map: 7,
          once: false,
          require: const ScriptRequire(),
          steps: const [
            ScriptStep(
              kind: 'setTileArea',
              tileX: 31,
              tileY: 1,
              tileAtPlayerY: true,
              tileValue: 45,
            ),
          ],
        ),
        context,
      );
    }

    return null;
  }

  /// `LORESPEC.PAS:332-353`, map 8 (WATER FIELD).
  ///
  /// The ordered guards evaluate:
  /// 1. `x == 50`: GROUND GATE portal to map 7 (handled via portal session).
  /// 2. `y == 71`: exit to map 2 (handled via portal session).
  static ScriptRun? map8(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if (!scripts.usingJson || context.tileAtPlayer != 0) return null;
    return null;
  }

  /// `LORESPEC.PAS:354-443`, map 9 (TOWN4 / GAIA TERRA).
  ///
  /// The ordered guards evaluate:
  /// 1. Gold finds (5000 gold each):
  ///    - `(10, 24)`: `etc35_bit1`
  ///    - `(12, 26)`: `etc35_bit2`
  ///    - `(15, 25)`: `etc35_bit3`
  ///    - `(16, 23)`: `etc35_bit4`
  ///    - `(18, 27)`: `etc35_bit5`
  /// 2. Barrier at `y == 10`:
  ///    - `party.etc[15] < 5` (water quest): message "알수없는 힘이 당신을 배척합니다." and nudge dy = 1.
  /// 3. Northern SWAMP GATE (`y == 5`):
  ///    - Enter portal to map 13 `(81, 95)` handled via portal session.
  /// 4. Southern exit (`y == 46`):
  ///    - Exit to map 2 `(32, 82)` handled via portal session.
  static ScriptRun? map9(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if (!scripts.usingJson ||
        (context.tileAtPlayer != null && context.tileAtPlayer != 0)) {
      return null;
    }

    final goldId = switch ((x, y)) {
      (10, 24) => !context.flags.contains('etc35_bit1') ? 'spec-9-L354' : null,
      (12, 26) => !context.flags.contains('etc35_bit2') ? 'spec-9-L354x' : null,
      (15, 25) =>
        !context.flags.contains('etc35_bit3') ? 'spec-9-L354xx' : null,
      (16, 23) =>
        !context.flags.contains('etc35_bit4') ? 'spec-9-L354xxx' : null,
      (18, 27) =>
        !context.flags.contains('etc35_bit5') ? 'spec-9-L354xxxx' : null,
      _ => null,
    };
    if (goldId != null) {
      final content = scripts.scripts.singleWhere(
        (script) => script.id == goldId,
      );
      return scripts.startProcedure(content, context);
    }

    if (y == 10) {
      final waterQuest = context.questSteps['water'] ?? 0;
      final blocked = waterQuest < 5 && !context.flags.contains('etc15_gte5');
      if (blocked) {
        final content = scripts.scripts.singleWhere(
          (script) => script.id == 'spec-9-L354xxxxx',
        );
        return scripts.startProcedure(content, context);
      }
    }

    return null;
  }

  /// `LORESPEC.PAS:444-464`, map 10 (WATER DEN).
  ///
  /// The ordered guards evaluate:
  /// 1. `y == 46`: jump to `y = 50` (`spec-10-L444`).
  /// 2. `y == 49`: jump to `y = 45` (`spec-10-L444x`).
  /// 3. Southern exit (`y == 71`):
  ///    - Exit to map 3 `(74, 20)` handled via portal session.
  static ScriptRun? map10(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if (!scripts.usingJson ||
        (context.tileAtPlayer != null && context.tileAtPlayer != 0)) {
      return null;
    }

    if (y == 46) {
      final content = scripts.scripts.singleWhere(
        (script) => script.id == 'spec-10-L444',
      );
      return scripts.startProcedure(content, context);
    }

    if (y == 49) {
      final content = scripts.scripts.singleWhere(
        (script) => script.id == 'spec-10-L444x',
      );
      return scripts.startProcedure(content, context);
    }

    return null;
  }

  /// `LORESPEC.PAS:465-559`, map 11 (TOWN5 / LORE KEEP).
  ///
  /// The ordered guards evaluate:
  /// 1. Gold finds (5000 gold each):
  ///    - `(20, 30)`: `etc33_bit1`
  ///    - `(18, 36)`: `etc33_bit2`
  ///    - `(35, 32)`: `etc33_bit3`
  ///    - `(33, 36)`: `etc33_bit4`
  ///    - `(35, 14)`: `etc33_bit5`
  ///    - `(14, 16)`: `etc33_bit6`
  ///    - `(37, 12)`: `etc33_bit7`
  /// 2. Oedipus Spear at `y == 44`:
  ///    - `party.etc[33] and bit8 == 0` (`etc33_bit8` / `oedipusSpearTaken`).
  /// 3. Mummy Room at `y == 24`:
  ///    - `party.etc[13] == 1` (`lastditch` quest == 1).
  /// 4. Southern exit at `y == 46`:
  ///    - Handled via portal session.
  static ScriptRun? map11(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if (!scripts.usingJson ||
        (context.tileAtPlayer != null && context.tileAtPlayer != 0)) {
      return null;
    }

    final goldId = switch ((x, y)) {
      (20, 30) => !context.flags.contains('etc33_bit1') ? 'spec-11-L465' : null,
      (18, 36) =>
        !context.flags.contains('etc33_bit2') ? 'spec-11-L465x' : null,
      (35, 32) =>
        !context.flags.contains('etc33_bit3') ? 'spec-11-L465xx' : null,
      (33, 36) =>
        !context.flags.contains('etc33_bit4') ? 'spec-11-L465xxx' : null,
      (35, 14) =>
        !context.flags.contains('etc33_bit5') ? 'spec-11-L465xxxx' : null,
      (14, 16) =>
        !context.flags.contains('etc33_bit6') ? 'spec-11-L465xxxxx' : null,
      (37, 12) =>
        !context.flags.contains('etc33_bit7') ? 'spec-11-L465xxxxxx' : null,
      _ => null,
    };
    if (goldId != null) {
      final content = scripts.scripts.singleWhere(
        (script) => script.id == goldId,
      );
      return scripts.startProcedure(content, context);
    }

    if (y == 44) {
      final hasSpear =
          context.flags.contains('oedipusSpearTaken') ||
          context.flags.contains('etc33_bit8');
      if (!hasSpear) {
        final content = scripts.scripts.singleWhere(
          (script) => script.id == 'oedipus-spear',
        );
        return scripts.startProcedure(content, context);
      }
    }

    if (y == 24) {
      final questState = context.questSteps['lastditch'] ?? 0;
      if (questState == 1) {
        final content = scripts.scripts.singleWhere(
          (script) => script.id == 'spec-11-L465-1x',
        );
        return scripts.startProcedure(content, context);
      }
    }

    return null;
  }

  /// `LORESPEC.PAS:560-668`, map 12 (T_DEN2 / GAIA DEN).
  ///
  /// The ordered guards evaluate:
  /// 1. Southern exit at `y == 71` handled via portal session.
  /// 2. Riddle doors at `y == 50` (when not moving south, `moveDy != 1`):
  ///    - `x == 33`: correct door (`puzzle-door-right`).
  ///    - `x != 33`: wrong door (`puzzle-door-wrong`).
  /// 3. Golden seal / trap at `y == 10` (when `party.etc[14] < 2` / `gaia < 2`):
  ///    - `x == 18`: golden seal (`golden-seal-12-18-10`).
  ///    - `x != 18`: mud trap (`t_den2-trap-y10`).
  /// 4. Rigel encounter at `(12, 48)`:
  ///    - `party.etc[31] and bit2 == 0` (`rigel-join`).
  static ScriptRun? map12(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if (!scripts.usingJson ||
        (context.tileAtPlayer != null && context.tileAtPlayer != 0)) {
      return null;
    }

    if (y == 50 && context.moveDy != 1) {
      final scriptId = x == 33 ? 'puzzle-door-right' : 'puzzle-door-wrong';
      final content = scripts.scripts.singleWhere(
        (script) => script.id == scriptId,
      );
      return scripts.startProcedure(content, context);
    }

    if (y == 10) {
      final gaiaQuest = context.questSteps['gaia'] ?? 0;
      if (gaiaQuest < 2) {
        final scriptId = x == 18 ? 'golden-seal-12-18-10' : 't_den2-trap-y10';
        final content = scripts.scripts.singleWhere(
          (script) => script.id == scriptId,
        );
        return scripts.startProcedure(content, context);
      }
    }

    if (x == 12 && y == 48) {
      final hasMet =
          context.flags.contains('rigelMet') ||
          context.flags.contains('etc31_bit2');
      if (!hasMet) {
        final content = scripts.scripts.singleWhere(
          (script) => script.id == 'rigel-join',
        );
        return scripts.startProcedure(content, context);
      }
    }

    return null;
  }

  /// `LORESPEC.PAS:669-813`, map 13 (SWAMP FIELD).
  ///
  /// The ordered guards evaluate:
  /// 1. Southern exit at `y == 96` handled via portal session.
  /// 2. Pyramid sequence at `(76..86, 71..81)`:
  ///    - `den4-pyramid-chapters` (requires special tile 52).
  /// 3. Gorgon battle at `y == 68`:
  ///    - `party.etc[38] and bit5 == 0` (`den4-gorgon`).
  static ScriptRun? map13(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if (!scripts.usingJson) return null;
    if (context.tileAtPlayer != null &&
        context.tileAtPlayer != 52 &&
        context.tileAtPlayer != 0) {
      return null;
    }

    if (x >= 76 && x <= 86 && y >= 71 && y <= 81) {
      final content = scripts.scripts.singleWhere(
        (script) => script.id == 'den4-pyramid-chapters',
      );
      return scripts.startProcedure(content, context);
    }

    if (y == 68 && x >= 80 && x <= 82) {
      final defeated = context.flags.contains('etc38_bit5');
      if (!defeated) {
        final content = scripts.scripts.singleWhere(
          (script) => script.id == 'den4-gorgon',
        );
        return scripts.startProcedure(content, context);
      }
    }

    return null;
  }

  /// `LORESPEC.PAS:814-878`, map 14 (DEN1 / SWAMP DEN / MENACE).
  ///
  /// The ordered guards evaluate:
  /// 1. Southern exit at `y == 46` handled via portal session.
  /// 2. MENACE center at `(25, 8)` or `(26, 8)` when `party.etc[10] == 3`:
  ///    - `spec-14-L814-1-1` / `spec-14-L814-2-1` increments `lordahn` quest step to 4.
  /// 3. Gold finds:
  ///    - `(6, 6)`: 1000 gold, `etc32_bit1`
  ///    - `(18, 10)`: 2500 gold, `etc32_bit2`
  ///    - `(6, 44)`: 400 gold, `etc32_bit3`
  ///    - `(31, 30)`: 600 gold, `etc32_bit4`
  ///    - `(31, 8)`: 1500 gold, `etc32_bit5`
  ///    - `(14, 28)`: 1000 gold, `etc32_bit6`
  /// 4. Golden Shield at `(16, 20)`:
  ///    - `party.etc[32] and bit7 == 0` (`etc32_bit7` / `goldenShieldMenaceTaken`).
  static ScriptRun? map14(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if (!scripts.usingJson) return null;
    if (context.tileAtPlayer != null &&
        context.tileAtPlayer != 52 &&
        context.tileAtPlayer != 0) {
      return null;
    }

    if ((x == 25 || x == 26) && y == 8) {
      final quest = context.questSteps['lordahn'] ?? 0;
      if (quest == 3) {
        final scriptId = x == 25 ? 'spec-14-L814-1-1' : 'spec-14-L814-2-1';
        final content = scripts.scripts.singleWhere(
          (script) => script.id == scriptId,
        );
        return scripts.startProcedure(content, context);
      }
    }

    final goldId = switch ((x, y)) {
      (6, 6) => !context.flags.contains('etc32_bit1') ? 'spec-14-L814' : null,
      (18, 10) =>
        !context.flags.contains('etc32_bit2') ? 'spec-14-L814x' : null,
      (6, 44) =>
        !context.flags.contains('etc32_bit3') ? 'spec-14-L814xx' : null,
      (31, 30) =>
        !context.flags.contains('etc32_bit4') ? 'spec-14-L814xxx' : null,
      (31, 8) =>
        !context.flags.contains('etc32_bit5') ? 'spec-14-L814xxxx' : null,
      (14, 28) =>
        !context.flags.contains('etc32_bit6') ? 'spec-14-L814xxxxx' : null,
      _ => null,
    };
    if (goldId != null) {
      final content = scripts.scripts.singleWhere(
        (script) => script.id == goldId,
      );
      return scripts.startProcedure(content, context);
    }

    if (x == 16 && y == 20) {
      final hasTaken =
          context.flags.contains('etc32_bit7') ||
          context.flags.contains('goldenShieldMenaceTaken');
      if (!hasTaken) {
        final content = scripts.scripts.singleWhere(
          (script) => script.id == 'spec-14-L814xxxxxx',
        );
        return scripts.startProcedure(content, context);
      }
    }

    return null;
  }

  /// `LORESPEC.PAS:879-965`, map 15 (T_DEN3 / QUAKE DEN).
  ///
  /// The ordered guards evaluate:
  /// 1. Southern exit at `y == 71` handled via portal session.
  /// 2. Gold chests at `y == 48` and `x in [10, 11, 40, 41]`:
  ///    - First chest gives 6000 gold and sets `etc36_bit1`.
  ///    - Second chest gives 4000 gold and sets `etc36_bit2`.
  ///    - Sets tiles `(x, 48)` and `(x, 47)` to 44.
  /// 3. Golden Shield at `(14, 7)`:
  ///    - `party.etc[36] and bit3 == 0` (`etc36_bit3` / `goldenShieldQuakeTaken`).
  /// 4. Golden Armor at `(45, 19)`:
  ///    - `party.etc[36] and bit4 == 0` (`etc36_bit4` / `goldenArmorQuakeTaken`).
  /// 5. ArchiGagoyle boss battle at `y == 27`:
  ///    - `party.etc[14] == 4` (`gaia` quest step 4 -> 5).
  static ScriptRun? map15(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if (!scripts.usingJson) return null;
    if (context.tileAtPlayer != null &&
        context.tileAtPlayer != 52 &&
        context.tileAtPlayer != 0) {
      return null;
    }

    if (y == 48 && (x == 10 || x == 11 || x == 40 || x == 41)) {
      if (!context.flags.contains('etc36_bit2')) {
        final isFirst = !context.flags.contains('etc36_bit1');
        final scriptId = isFirst ? 'spec-15-L879-1xx' : 'spec-15-L879-2xx';
        final content = scripts.scripts.singleWhere(
          (script) => script.id == scriptId,
        );
        final procedure = LoreScript(
          id: 'lorespec-map15-gold-$x-$y',
          trigger: 'step',
          map: 15,
          once: false,
          require: const ScriptRequire(),
          steps: [
            ...content.steps,
            ScriptStep(kind: 'setTile', tileX: x, tileY: 48, tileValue: 44),
            ScriptStep(kind: 'setTile', tileX: x, tileY: 47, tileValue: 44),
          ],
        );
        return scripts.startProcedure(procedure, context);
      }
    }

    if (x == 14 && y == 7) {
      final hasTaken =
          context.flags.contains('etc36_bit3') ||
          context.flags.contains('goldenShieldQuakeTaken');
      if (!hasTaken) {
        final content = scripts.scripts.singleWhere(
          (script) => script.id == 'spec-15-L879',
        );
        return scripts.startProcedure(content, context);
      }
    }

    if (x == 45 && y == 19) {
      final hasTaken =
          context.flags.contains('etc36_bit4') ||
          context.flags.contains('goldenArmorQuakeTaken');
      if (!hasTaken) {
        final content = scripts.scripts.singleWhere(
          (script) => script.id == 'spec-15-L879x',
        );
        return scripts.startProcedure(content, context);
      }
    }

    if (y == 27) {
      final quest = context.questSteps['gaia'] ?? 0;
      if (quest == 4) {
        final content = scripts.scripts.singleWhere(
          (script) => script.id == 'spec-15-L879-1xxxx',
        );
        return scripts.startProcedure(content, context);
      }
    }

    return null;
  }

  /// `LORESPEC.PAS:966-1004`, map 16 (DEN2 / TYPHOON DEN).
  ///
  /// The ordered guards evaluate:
  /// 1. Southern exit at `y == 36` handled via portal session.
  /// 2. Wivern encounter at `y == 10`:
  ///    - If `party.etc[37] < 3`:
  ///      - 0 defeated: 3 Wiverns (`wivern-3-remaining`)
  ///      - 1 defeated: 2 Wiverns (`wivern-2-remaining`)
  ///      - 2 defeated: 1 Wivern (`wivern-1-remaining`)
  ///    - If `party.etc[37] >= 3`:
  ///      - Corpse message (`wivern-cleared`).
  static ScriptRun? map16(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if (!scripts.usingJson) return null;
    if (context.tileAtPlayer != null &&
        context.tileAtPlayer != 52 &&
        context.tileAtPlayer != 0) {
      return null;
    }

    if (y == 10) {
      final wivernQuest = context.questSteps['wivern'] ?? 0;
      final scriptId = switch (wivernQuest) {
        0 => 'wivern-3-remaining',
        1 => 'wivern-2-remaining',
        2 => 'wivern-1-remaining',
        _ => 'wivern-cleared',
      };
      final content = scripts.scripts.singleWhere(
        (script) => script.id == scriptId,
      );
      return scripts.startProcedure(content, context);
    }

    return null;
  }

  /// `LORESPEC.PAS:1006-1173`, map 17 (DEN3 / DRAGON DEN).
  ///
  /// The ordered guards evaluate:
  /// 1. Southern exit at `y == 95` handled via portal session.
  /// 2. Vertical wrap at `y == 80`:
  ///    - `y := 6` (`spec-17-L1010`).
  /// 3. Passage toggle at `y == 44`:
  ///    - `map[67..69, 44] := 44`, `map[67..69, 38] := 52` (`map17-passage-44`).
  /// 4. Red Antares meeting at `(75, 52)`:
  ///    - `party.etc[38] and bit2 == 1` -> null (이미 합류/결정 완료).
  ///    - `party.etc[38] and bit1 == 1` and `mindRead`:
  ///      - `redantares-join` (합류 선택지).
  ///    - `party.etc[38] and bit1 == 1` and not `mindRead`:
  ///      - `redantares-wait-for-mindread`.
  ///    - `party.etc[38] and bit1 == 0`:
  ///      - `redantares-teach` (용암 변형 및 간접 마법 전수).
  /// 5. Secret shortcut at `x == 72`:
  ///    - `map[72, 19..21] := 44`, `y := y - 7` (`map17-shortcut-72`).
  /// 6. Passage return at `y == 38`:
  ///    - `map[67..69, 38] := 44`, `map[67..69, 44] := 52`, teleport `(56, 93)` (`map17-passage-38`).
  /// 7. Hidra boss battle at `x == 22`:
  ///    - `party.etc[15] < 2`:
  ///      - `map17-hidra` (보스 전투, 승리 시 `swamp` 퀘스트 2, 워프 `(56, 93)`).
  static ScriptRun? map17(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if (!scripts.usingJson) return null;
    if (context.tileAtPlayer != null &&
        context.tileAtPlayer != 52 &&
        context.tileAtPlayer != 0) {
      return null;
    }

    if (y == 80) {
      final content = scripts.scripts.singleWhere(
        (script) => script.id == 'spec-17-L1010',
      );
      return scripts.startProcedure(content, context);
    }

    if (y == 44) {
      final content = scripts.scripts.singleWhere(
        (script) => script.id == 'map17-passage-44',
      );
      return scripts.startProcedure(content, context);
    }

    if (x == 75 && y == 52) {
      final hasJoinedOrRefused = context.flags.contains('etc38_bit2');
      if (hasJoinedOrRefused) return null;

      final hasLearned =
          context.flags.contains('etc38_bit1') ||
          context.flags.contains('specialMagicLearned');
      if (hasLearned) {
        final hasMindRead = context.mindReadActive;
        final scriptId = hasMindRead
            ? 'redantares-join'
            : 'redantares-wait-for-mindread';
        final content = scripts.scripts.singleWhere(
          (script) => script.id == scriptId,
        );
        return scripts.startProcedure(content, context);
      } else {
        final content = scripts.scripts.singleWhere(
          (script) => script.id == 'redantares-teach',
        );
        return scripts.startProcedure(content, context);
      }
    }

    if (x == 72) {
      final content = scripts.scripts.singleWhere(
        (script) => script.id == 'map17-shortcut-72',
      );
      return scripts.startProcedure(content, context);
    }

    if (y == 38) {
      final content = scripts.scripts.singleWhere(
        (script) => script.id == 'map17-passage-38',
      );
      return scripts.startProcedure(content, context);
    }

    if (x == 22) {
      final swampQuest = context.questSteps['swamp'] ?? 0;
      if (swampQuest < 2) {
        final content = scripts.scripts.singleWhere(
          (script) => script.id == 'map17-hidra',
        );
        return scripts.startProcedure(content, context);
      }
    }

    return null;
  }

  /// `LORESPEC.PAS:1174-1365`, map 18 (T_DEN4 / LOCKUP).
  ///
  /// The ordered guards evaluate:
  /// 1. Southern exit at `y == 95` handled via portal session.
  /// 2. Passage at `(22, 41)`:
  ///    - `map[22, 41] := 44; map[21, 41] := 52;` (`lockup-passage-22-41`).
  /// 3. Guardian battle at `(21, 41)`:
  ///    - `party.etc[39] and bit3 == 0`: Minotaur battle (`lockup-guardian-21-41`).
  /// 4. Spica at `(37, 31)`:
  ///    - `party.etc[39] and bit2 > 0`: null (이미 합류/결정 완료).
  ///    - `party.etc[39] and bit1 > 0`:
  ///      - if not `context.mindReadActive`: `spica-mind-read-inactive`.
  ///      - if `context.maxEspLevel < 5`: `spica-cannot-read`.
  ///      - if `context.maxEspLevel >= 5`: `spica-join` (합류 제의).
  ///    - `party.etc[39] and bit1 == 0`:
  ///      - `spica-first-meeting` (초자연력 설명, `etc39_bit1` 설정).
  /// 5. Huge Dragon boss battle at `x == 31`:
  ///    - `party.etc[15] < 4`: Huge Dragon battle (`map18-huge-dragon`).
  static ScriptRun? map18(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if (!scripts.usingJson) return null;
    if (context.tileAtPlayer != null &&
        context.tileAtPlayer != 52 &&
        context.tileAtPlayer != 0) {
      return null;
    }

    if (x == 22 && y == 41) {
      final content = scripts.scripts.singleWhere(
        (script) => script.id == 'lockup-passage-22-41',
      );
      return scripts.startProcedure(content, context);
    }

    if (x == 21 && y == 41) {
      final hasDefeated =
          context.flags.contains('etc39_bit3') ||
          context.flags.contains('lockupGuardianDefeated');
      if (!hasDefeated) {
        final content = scripts.scripts.singleWhere(
          (script) => script.id == 'lockup-guardian-21-41',
        );
        return scripts.startProcedure(content, context);
      }
    }

    if (x == 37 && y == 31) {
      final hasDecided = context.flags.contains('etc39_bit2');
      if (hasDecided) return null;

      final hasMet = context.flags.contains('etc39_bit1');
      if (hasMet) {
        if (!context.mindReadActive) {
          final content = scripts.scripts.singleWhere(
            (script) => script.id == 'spica-mind-read-inactive',
          );
          return scripts.startProcedure(content, context);
        }
        if (context.maxEspLevel < 5) {
          final content = scripts.scripts.singleWhere(
            (script) => script.id == 'spica-cannot-read',
          );
          return scripts.startProcedure(content, context);
        }
        final content = scripts.scripts.singleWhere(
          (script) => script.id == 'spica-join',
        );
        return scripts.startProcedure(content, context);
      } else {
        final content = scripts.scripts.singleWhere(
          (script) => script.id == 'spica-first-meeting',
        );
        return scripts.startProcedure(content, context);
      }
    }

    if (x == 31) {
      final swampQuest = context.questSteps['swamp'] ?? 0;
      if (swampQuest < 4) {
        final content = scripts.scripts.singleWhere(
          (script) => script.id == 'map18-huge-dragon',
        );
        return scripts.startProcedure(content, context);
      }
    }

    return null;
  }

  /// `LORESPEC.PAS:1378-1473`, map 19 (DEN6 / EVIL DEN).
  /// Direct, closed internal branches; the southern exit remains in the portal
  /// session. Preserve etc[3], odd/shr/div, random calls and battle exits.
  static ScriptRun? map19(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if (context.tileAtPlayer != null &&
        context.tileAtPlayer != 52 &&
        context.tileAtPlayer != 0) {
      return null;
    }

    ScriptRun start(String id, List<ScriptStep> steps) =>
        scripts.startProcedure(
          LoreScript(
            id: id,
            trigger: 'step',
            map: 19,
            once: false,
            require: const ScriptRequire(),
            steps: steps,
          ),
          context,
        );
    ScriptStep tile(int tx, int ty, int value) =>
        ScriptStep(kind: 'setTile', tileX: tx, tileY: ty, tileValue: value);
    Map<String, Object?> guardOverride(int slot) => {
      'index': slot,
      'eNumber': 25,
      'hp': 210,
      'level': 7,
    };

    var sealByte = context.etcValue(40, bitAliases: {1: 'evilSealRoomCleared'});
    // Transition adapter for old JSON snapshots. Raw byte zero wins.
    if (!context.sourceEtc.containsKey(40)) {
      for (var room = 1; room <= 7; room++) {
        if (context.flags.contains('evilSealRoom$room')) {
          sealByte = (room << 1) | (sealByte & 1);
        }
      }
    }
    final sealCleared = (sealByte & 1) != 0;

    if ((x == 11 && y == 40) || (x == 41 && y == 39)) {
      final lever = x == 11 ? 'a' : 'b';
      final swampWalk =
          context.etcValue(3) > 0 ||
          (!context.sourceEtc.containsKey(3) &&
              context.flags.contains('swampWalkActive'));
      if (swampWalk) {
        return start('evil-seal-lever-$lever-blocked', const [
          ScriptStep(kind: 'say', text: ' 늪 아래를 보니 무언가 반짝이는 물체가 있었'),
          ScriptStep(kind: 'say', text: '다. 하지만 늪위를 걷는 마법 때문에 늪속으로'),
          ScriptStep(kind: 'say', text: '들어갈수가 없다.'),
        ]);
      }
      if (x == 11) {
        return start('evil-seal-lever-a', [
          const ScriptStep(kind: 'say', text: ' 일행은 독을 무릅쓰고  늪속에 빠져있는 레버'),
          const ScriptStep(kind: 'say', text: '를 당겼다. 순간 동굴 중심부에서 굉음이 들렸'),
          const ScriptStep(kind: 'say', text: '다.'),
          tile(11, 40, 49),
          tile(41, 39, 0),
        ]);
      }
      return start('evil-seal-lever-b', [
        const ScriptStep(kind: 'say', text: ' 일행은 독을 무릅쓰고  늪속에 빠져있는 레버'),
        const ScriptStep(kind: 'say', text: '를 당겼다. 순간 동굴 중심부에서 조금전 보다'),
        const ScriptStep(kind: 'say', text: '더 큰 굉음이 들렸다.'),
        tile(41, 39, 49),
        if (!sealCleared) ...[
          for (var j = 27; j <= 36; j++) ...[tile(24, j, 25), tile(28, j, 23)],
          tile(24, 37, 17),
          tile(28, 37, 19),
          for (var j = 27; j <= 37; j++)
            for (var i = 25; i <= 27; i++) tile(i, j, 44),
          ScriptStep(
            kind: 'sourceEtc',
            sourceEtcIndex: 40,
            sourceEtcValue: (scripts.roll(7) + 1) << 1,
          ),
        ],
      ]);
    }

    if (!sealCleared && y >= 8 && y <= 12) {
      final count = scripts.roll(3) + 3;
      final closeTile = tile(x, y, 49);
      return start('evil-seal-guardians', [
        ScriptStep(
          kind: 'battle',
          monsters: List.filled(count, 59),
          battleOverrides: [for (var i = 1; i <= count; i++) guardOverride(i)],
          // BattleMode(TRUE); map[x,y] := 49 on every battle result.
          battleRunAwaySteps: [closeTile],
          battleDefeatSteps: [closeTile],
        ),
        closeTile,
      ]);
    }

    if (!sealCleared && y == 6) {
      final room = LorePascal.div(x - 10, 4);
      if ((sealByte >> 1) != room) {
        return start('evil-seal-room-wrong-$room', [
          tile(x, y - 1, 49),
          const ScriptStep(kind: 'say', text: ' 여기에는 봉인이 발견되지 않았다'),
          tile(x, y, 49),
        ]);
      }
      return start('evil-seal-room-$room', [
        tile(x, y - 1, 49),
        const ScriptStep(kind: 'say', text: '나는 EVIL GOD의 봉인을 지키고 있는 CRAB GOD'),
        const ScriptStep(kind: 'say', text: '의 왕이다. CRAB GOD 족의 명예를 걸고 절대로'),
        const ScriptStep(kind: 'say', text: '너희 같은 자들에게 봉인을 넘겨주지 않겠다!!'),
        ScriptStep(
          kind: 'battle',
          monsters: List.filled(7, 59),
          battleEnemyFirst: true,
          battleOverrides: [for (var i = 4; i <= 7; i++) guardOverride(i)],
          battleRunAwaySteps: const [ScriptStep(kind: 'nudge', nudgeDy: 1)],
        ),
        const ScriptStep(kind: 'say', text: ' 당신은 이 동굴에 보관되어 있는 봉인을 발견'),
        const ScriptStep(kind: 'say', text: '했다.  그리고는 봉쇄 되었던 봉인을 풀어버렸'),
        const ScriptStep(kind: 'say', text: '다.'),
        ScriptStep(
          kind: 'sourceEtc',
          sourceEtcIndex: 40,
          sourceEtcValue: sealByte | LorePascal.bit(1),
        ),
      ]);
    }
    return null;
  }

  /// `LORESPEC.PAS:1475-1759`, map 20 (DEN5 / MUD DEN / ASTRAL DEN).
  ///
  /// The ordered guards evaluate:
  /// 1. Southern exit at `y == 96` handled via portal session.
  /// 2. Quiz 1 door check at `y == 88`:
  ///    - If tile at player == 0: `y := 80` (`den7-passage-y88`).
  ///    - Else: eject to map 4 `(82, 17)` (`den7-exit-y88`).
  /// 3. Quiz 2 door check at `y == 71`:
  ///    - If tile at player == 0: `y := 63` (`den7-passage-y71`).
  ///    - Else: eject to map 4 `(82, 17)` (`den7-exit-y71`).
  /// 4. Quiz 1 at `y == 91`: `den7-quiz-y91`.
  /// 5. Quiz 2 at `y == 75`: `den7-quiz-y75`.
  /// 6. Quiz 3 at `y == 54`: `den7-quiz-y54`.
  /// 7. Guardian Minotaur at `y == 48`:
  ///    - If `party.etc[41] and bit4 == 0`: `den7-minotaur-y48`.
  /// 8. Final boss sequence at `y == 13`:
  ///    - If `party.etc[41] and bit2 == 0`: `den7-dragons-y13`.
  ///    - Else if `party.etc[41] and bit3 == 0`: `den7-mudmen-y13`.
  ///    - Else if `party.etc[41] and bit1 == 0`: `den7-master-y13`.
  static ScriptRun? map20(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if (!scripts.usingJson) return null;
    if (context.tileAtPlayer != null &&
        context.tileAtPlayer != 52 &&
        context.tileAtPlayer != 0) {
      return null;
    }

    if (y == 88) {
      final scriptId = context.tileAtPlayer == 0
          ? 'den7-passage-y88'
          : 'den7-exit-y88';
      final content = scripts.scripts.singleWhere(
        (script) => script.id == scriptId,
      );
      return scripts.startProcedure(content, context);
    }

    if (y == 71) {
      final scriptId = context.tileAtPlayer == 0
          ? 'den7-passage-y71'
          : 'den7-exit-y71';
      final content = scripts.scripts.singleWhere(
        (script) => script.id == scriptId,
      );
      return scripts.startProcedure(content, context);
    }

    if (y == 91) {
      final content = scripts.scripts.singleWhere(
        (script) => script.id == 'den7-quiz-y91',
      );
      return scripts.startProcedure(content, context);
    }

    if (y == 75) {
      final content = scripts.scripts.singleWhere(
        (script) => script.id == 'den7-quiz-y75',
      );
      return scripts.startProcedure(content, context);
    }

    if (y == 54) {
      final content = scripts.scripts.singleWhere(
        (script) => script.id == 'den7-quiz-y54',
      );
      return scripts.startProcedure(content, context);
    }

    if (y == 48) {
      final hasDefeated =
          context.flags.contains('etc41_bit4') ||
          context.flags.contains('den7MinotaurCleared');
      if (!hasDefeated) {
        final content = scripts.scripts.singleWhere(
          (script) => script.id == 'den7-minotaur-y48',
        );
        return scripts.startProcedure(content, context);
      }
    }

    if (y == 13) {
      final hasDefeatedDragons =
          context.flags.contains('etc41_bit2') ||
          context.flags.contains('den7DragonsCleared');
      final hasDefeatedMudmen =
          context.flags.contains('etc41_bit3') ||
          context.flags.contains('den7MudmenCleared');
      final hasDefeatedMaster =
          context.flags.contains('etc41_bit1') ||
          context.flags.contains('den7MazeCleared');

      if (!hasDefeatedDragons) {
        final content = scripts.scripts.singleWhere(
          (script) => script.id == 'den7-dragons-y13',
        );
        return scripts.startProcedure(content, context);
      }
      if (!hasDefeatedMudmen) {
        final content = scripts.scripts.singleWhere(
          (script) => script.id == 'den7-mudmen-y13',
        );
        return scripts.startProcedure(content, context);
      }
      if (!hasDefeatedMaster) {
        final content = scripts.scripts.singleWhere(
          (script) => script.id == 'den7-master-y13',
        );
        return scripts.startProcedure(content, context);
      }
    }

    return null;
  }

  /// `LORESPEC.PAS:1760-1815`, map 21 (KEEP1 / SWAMP KEEP).
  ///
  /// The ordered guards evaluate:
  /// 1. Exit at `y == 46` handled via portal session (`keep1-exit-guard`).
  /// 2. Gate check at `(25, 20)`:
  ///    - If not (odd(party.etc[40]) and odd(party.etc[41])):
  ///      - Gate closed message, nudge dy: 1 (`keep1-seal-gate-a`).
  /// 3. Other tiles (ambush in Keep 1):
  ///    - Handled via `keep1-special-ambush`.
  static ScriptRun? map21(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if (!scripts.usingJson) return null;
    if (context.tileAtPlayer != null &&
        context.tileAtPlayer != 52 &&
        context.tileAtPlayer != 0) {
      return null;
    }

    if (x == 25 && y == 20) {
      final seal1Unlocked =
          context.flags.contains('etc40_bit1') ||
          context.flags.contains('evilSealRoomCleared') ||
          context.flags.contains('sealPuzzleA');
      final seal2Unlocked =
          context.flags.contains('etc41_bit1') ||
          context.flags.contains('den7MazeCleared') ||
          context.flags.contains('sealPuzzleB');

      if (!seal1Unlocked || !seal2Unlocked) {
        final content = scripts.scripts.firstWhere(
          (script) => script.id == 'keep1-seal-gate-a',
        );
        return scripts.startProcedure(content, context);
      }
    }

    return null;
  }

  /// `LORESPEC.PAS:1816-1879`, map 22 (KEEP2 / IMPERIUM MINOR).
  ///
  /// The ordered guards evaluate:
  /// 1. Southern exit at `y == 46` handled via portal session (`keep2-exit-guard`).
  /// 2. Death Knight ambush at `(25, 18)`:
  ///    - `party.etc[43] and bit2 == 0` -> `keep2-ambush-25-18`.
  /// 3. Fortress guards ambush at `y == 25` and `x in [24..26]`:
  ///    - `party.etc[43] and bit1 == 0` -> `keep2-guards-y25`.
  /// 4. Other tiles (Wraith ambush if `party.etc[43] and bit2 == 0`):
  ///    - Handled via `keep2-ambush-zone-a` / `keep2-ambush-zone-b`.
  static ScriptRun? map22(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if (!scripts.usingJson) return null;
    if (context.tileAtPlayer != null &&
        context.tileAtPlayer != 52 &&
        context.tileAtPlayer != 0) {
      return null;
    }

    if (x == 25 && y == 18) {
      final hasDefeatedKnight =
          context.flags.contains('etc43_bit2') ||
          context.flags.contains('keep2AmbushCleared');
      if (!hasDefeatedKnight) {
        final content = scripts.scripts.singleWhere(
          (script) => script.id == 'keep2-ambush-25-18',
        );
        return scripts.startProcedure(content, context);
      }
    }

    if (y == 25 && (x >= 24 && x <= 26)) {
      final hasDefeatedGuards =
          context.flags.contains('etc43_bit1') ||
          context.flags.contains('keep2GuardsCleared');
      if (!hasDefeatedGuards) {
        final content = scripts.scripts.singleWhere(
          (script) => script.id == 'keep2-guards-y25',
        );
        return scripts.startProcedure(content, context);
      }
    }

    return null;
  }

  /// `LORESPEC.PAS:1880-1979`, map 23 (KEEP3 / DUNGEON OF EVIL).
  ///
  /// The ordered guards evaluate:
  /// 1. Southern exit at `y == 46` handled via portal session.
  /// 2. Fake Necromancer and doppelganger battle at `y == 26`:
  ///    - `keep3-necromancer-y26` (Doppelganger -> Necromancer 2-stage battle, tile changes).
  /// 3. Lever at `(25, 27)`:
  ///    - `keep3-trap-25-27` (castle floating effect, tile transformations).
  static ScriptRun? map23(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if (!scripts.usingJson) return null;
    if (context.tileAtPlayer != null &&
        context.tileAtPlayer != 52 &&
        context.tileAtPlayer != 0) {
      return null;
    }

    if (y == 26) {
      final hasCleared = context.flags.contains('keep3NecromancerCleared');
      if (!hasCleared) {
        final content = scripts.scripts.singleWhere(
          (script) => script.id == 'keep3-necromancer-y26',
        );
        return scripts.startProcedure(content, context);
      }
    }

    if (x == 25 && y == 27) {
      final hasTriggeredTrap = context.flags.contains('keep3TrapCleared');
      if (!hasTriggeredTrap) {
        final content = scripts.scripts.singleWhere(
          (script) => script.id == 'keep3-trap-25-27',
        );
        return scripts.startProcedure(content, context);
      }
    }

    return null;
  }

  /// `LORESPEC.PAS:1980-1994`, map 24 (K_DEN1 / LAST SHELTER).
  ///
  /// The single exit at `y == 46` is handled via portal session.
  /// No other internal special tiles exist on map 24.
  static ScriptRun? map24(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    return null;
  }

  /// `LORESPEC.PAS:1995-2103`, map 25 (K_DEN2 / DUNGEON OF EVIL DEEP / CASTLE KEEP).
  ///
  /// The ordered guards evaluate:
  /// 1. Southern exit at `y == 46` handled via portal session.
  /// 2. Metal Guardian encounter at `y == 43`:
  ///    - Torch ignition (`party.etc[1] := 1`), battle with metal enemy + 4 soldiers,
  ///    - set corridor tile `(24..27, 43) := 41`, dialogue and class promotion (`class := 10`).
  /// 3. Hidden passage at `(15, 34)`:
  ///    - `keep25-corridor-15-34`.
  /// 4. Hidden passage at `(36, 34)`:
  ///    - `keep25-corridor-36-34`.
  /// 5. Lever A at `(5, 34)`:
  ///    - Sets `etc45_bit7`. If both bit7 & bit8 set -> opens portal doors `map[25..26, 27] := 54`.
  /// 6. Lever B at `(46, 34)`:
  ///    - Sets `etc45_bit8`. If both bit7 & bit8 set -> opens portal doors `map[25..26, 27] := 54`.
  static ScriptRun? map25(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if (context.tileAtPlayer != null &&
        context.tileAtPlayer != 52 &&
        context.tileAtPlayer != 0) {
      return null;
    }

    if (y == 43 && scripts.usingJson) {
      final hasDefeatedMetalGuardian = context.flags.contains(
        'keep3MetalGuardianCleared',
      );
      if (!hasDefeatedMetalGuardian) {
        final content = scripts.scripts.singleWhere(
          (script) => script.id == 'keep3-metal-guardian-y43',
        );
        return scripts.startProcedure(content, context);
      }
    }

    // LORESPEC.PAS:2067-2079. Preserve the loop order and its final overwrites.
    if ((x == 15 || x == 36) && y == 34) {
      final left = x == 15;
      final steps = <ScriptStep>[
        ScriptStep(kind: 'setTile', tileX: x, tileY: 34, tileValue: 41),
        for (var i = left ? 11 : 37; i <= (left ? 14 : 40); i++) ...[
          ScriptStep(kind: 'setTile', tileX: i, tileY: 33, tileValue: 24),
          ScriptStep(kind: 'setTile', tileX: i, tileY: 35, tileValue: 26),
          ScriptStep(kind: 'setTile', tileX: i, tileY: 34, tileValue: 42),
        ],
        ScriptStep(
          kind: 'setTile',
          tileX: left ? 14 : 37,
          tileY: 33,
          tileValue: left ? 17 : 19,
        ),
        ScriptStep(
          kind: 'setTile',
          tileX: left ? 14 : 37,
          tileY: 35,
          tileValue: left ? 18 : 22,
        ),
      ];
      return scripts.startProcedure(
        LoreScript(
          id: 'keep25-corridor-$x-34',
          trigger: 'step',
          map: 25,
          once: false,
          require: const ScriptRequire(),
          steps: steps,
        ),
        context,
      );
    }

    // LORESPEC.PAS:2081-2101: write our bit before testing BOTH lever bits.
    // Raw etc[45], including a stored zero, takes precedence over old aliases.
    if ((x == 5 || x == 46) && y == 34) {
      final bit = x == 5 ? 7 : 8;
      final after =
          context.etcValue(
            45,
            bitAliases: const {7: 'keep3KeyA', 8: 'keep3KeyB'},
          ) |
          LorePascal.bit(bit);
      final opened = (after & 0xc0) == 0xc0;
      return scripts.startProcedure(
        LoreScript(
          id: 'keep3-key-${x == 5 ? 'a' : 'b'}-${opened ? 'second' : 'first'}',
          trigger: 'step',
          map: 25,
          once: false,
          require: const ScriptRequire(),
          steps: [
            ScriptStep(kind: 'flag', key: 'etc45_bit$bit'),
            // Compatibility name for old UI/saves; not a second source state.
            ScriptStep(kind: 'flag', key: x == 5 ? 'keep3KeyA' : 'keep3KeyB'),
            const ScriptStep(kind: 'say', text: ' 당신이 레버를 당기자  철컥하는 소리가 동굴'),
            const ScriptStep(kind: 'say', text: '에 울려 퍼졌다.'),
            if (opened) ...const [
              ScriptStep(kind: 'setTile', tileX: 25, tileY: 27, tileValue: 54),
              ScriptStep(kind: 'setTile', tileX: 26, tileY: 27, tileValue: 54),
              ScriptStep(kind: 'say', text: ' 곧 이어 기계 작동하는 큰 소리가 들렸다.'),
            ],
          ],
        ),
        context,
      );
    }

    return null;
  }

  /// `LORESPEC.PAS:2104-2201`, map 26 (CHAMBER OF NECROMANCER / 결전의 방).
  ///
  /// Final showdown cutscene and battle sequence with Neo-Necromancer, ArchiMonk, and ArchiMage:
  ///    - Triggered on empty floor (tile == 0).
  ///    - `spec-26-L2104-seq`.
  static ScriptRun? map26(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if (!scripts.usingJson) return null;
    if (context.tileAtPlayer != 0) return null;

    final hasDefeatedBoss = context.flags.contains('bossNecromancerDefeated');
    if (hasDefeatedBoss) return null;

    final content = scripts.scripts.singleWhere(
      (script) => script.id == 'spec-26-L2104-seq',
    );
    return scripts.startProcedure(content, context);
  }

  /// `LORESPEC.PAS:2202-2213`, map 27 (PYRAMID1 / ANOTHER LORE / 또 다른 지식의 성전).
  ///
  /// The ordered guards evaluate:
  /// 1. Exit check via `wantexit`:
  ///    - Exit is handled via portal session.
  /// 2. If rejected exit / stepping on special boundary tiles:
  ///    - `y < 25` -> `inc(y)` (`map27-special-upper`).
  ///    - `y >= 25` -> `dec(y)` (`map27-special-lower`).
  static ScriptRun? map27(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if (!scripts.usingJson) return null;

    final scriptId = y < 25 ? 'map27-special-upper' : 'map27-special-lower';
    final content = scripts.scripts.singleWhere(
      (script) => script.id == scriptId,
    );
    return scripts.startProcedure(content, context);
  }

  /// `LORESPEC.PAS:190-196`: the chest is a special tile until its tile is
  /// replaced with floor. Keep the reward and tile effect in JSON data.
  static ScriptRun? map6Chest(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if (x != 62 || y != 82) return null;
    return map6(x, y, context, scripts);
  }

  /// `LORESPEC.PAS:37-189`, map 4. The ordered Pascal guards select one
  /// event; the existing JSON records provide its dialogue and effects.
  static ScriptRun? map4(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if (!scripts.usingJson) return null;
    final flags = context.flags;
    final id = switch ((x, y)) {
      (40, 18) => 'spec-4-L37',
      (26, 16) =>
        flags.contains('draconianMet')
            ? 'spec-4-L37-3'
            : flags.contains('etc5')
            ? 'spec-4-L37-2'
            : 'spec-4-L37-1',
      (20, 39) =>
        flags.contains('ancientEvilMet')
            ? 'ancient-evil-later'
            : 'ancient-evil-first',
      _ => null,
    };
    if (id == null) return null;
    final content = scripts.scripts.where((script) => script.id == id).single;
    return scripts.startProcedure(content, context);
  }

  /// `LORESPEC.PAS:23-34`, map 1: every special tile gives food once, then
  /// moves the party back from the trigger tile on both first and later visits.
  static ScriptRun? map1Food(ScriptContext context, LoreScriptEngine scripts) {
    if (context.tileAtPlayer != 0) return null;
    final visited = context.etcValue(32) & LorePascal.bit(8) != 0;
    final procedure = LoreScript(
      id: 'lorespec-map1-food',
      trigger: 'step',
      map: 1,
      once: false,
      require: const ScriptRequire(),
      steps: [
        ScriptStep(
          kind: 'say',
          text: visited ? '우리들은 아무것도 발견할수 없었다.' : '일행들은 100 인분의 식량을 발견했다.',
        ),
        if (!visited) ...const [
          ScriptStep(kind: 'food', amount: 100),
          ScriptStep(kind: 'flag', key: 'etc32_bit8'),
        ],
        const ScriptStep(kind: 'stepBack'),
      ],
    );
    return scripts.startProcedure(procedure, context);
  }
}

import '../data/lore_script.dart';

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
    if (!scripts.usingJson || context.tileAtPlayer != 0) return null;

    if (x == 30 || x == 32) {
      final scriptId = x == 30
          ? 'lastditch-passwall-left'
          : 'lastditch-passwall-right';
      final content = scripts.scripts.singleWhere(
        (script) => script.id == scriptId,
      );
      return scripts.startProcedure(content, context);
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
    final visited = context.flags.contains('etc32_bit8');
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

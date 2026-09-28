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
      final hasMadJoe = context.flags.contains('madJoeJoined') ||
          context.flags.contains('etc50_bit2');
      if (!hasMadJoe || context.flags.contains('prisonBattleDone')) {
        return null;
      }
      final isReturn = context.flags.contains('prisonBattleStarted') ||
          context.flags.contains('etc50_bit3');
      final scriptId = isReturn ? 'prison-battle-return' : 'prison-battle-first';
      final content = scripts.scripts.singleWhere(
        (script) => script.id == scriptId,
      );
      return scripts.startProcedure(content, context);
    }

    // 3. on(41,79) - 무기실
    if (x == 41 && y == 79) {
      final visited = context.flags.contains('weaponRoomVisited') ||
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

import '../data/lore_script.dart';

/// Gameplay branches from `LORESPEC.specialevent_part1`.
///
/// Each branch returns ordered effects for the shared script interpreter. The
/// visual `scroll`/`Clear` calls remain with the field presentation adapter.
class LoreSpecProcedures {
  LoreSpecProcedures._();

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
          text: visited
              ? '우리들은 아무것도 발견할수 없었다.'
              : '일행들은 100 인분의 식량을 발견했다.',
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

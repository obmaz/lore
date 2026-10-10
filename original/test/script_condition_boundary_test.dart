import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/logic/lore_spec_procedures.dart';

// LORESPEC.PAS:638,656,875,922,942: Display_Condition precedes done bits.
void main() {
  test('equipment commit cannot consume an event before condition refresh', () {
    final engine = LoreScriptEngine();
    final run = engine.startProcedure(
      const LoreScript(
        id: 'condition-order',
        trigger: 'step',
        map: 14,
        once: true,
        require: ScriptRequire(),
        steps: [
          ScriptStep(
            kind: 'equip',
            equipKind: 'shield',
            equipIndex: 5,
            equipPower: 5,
            equipPrompt: true,
          ),
          ScriptStep(kind: 'displayCondition'),
          ScriptStep(kind: 'flag', key: 'etc32_bit7'),
        ],
      ),
      const ScriptContext(tileAtPlayer: 0),
    );
    expect(run.pendingConditionRefresh, isTrue);
    expect(run.outcome.equips, hasLength(1));
    expect(run.outcome.setFlags, isEmpty);
    run.completeEquipment();
    expect(engine.consumedScripts, isEmpty);
    final next = run.acknowledgeConditionRefresh();
    expect(next.outcome.since(run.outcome).equips, isEmpty);
    expect(next.outcome.since(run.outcome).setFlags, ['etc32_bit7']);
    expect(next.pendingConditionRefresh, isFalse);
    expect(engine.consumedScripts, isEmpty);
    next.completeEquipment();
    expect(engine.consumedScripts, {'condition-order'});
  });

  test(
    'Rigel join and blessing refresh before completion; refusal does not',
    () {
      ScriptRun offer() => LoreSpecProcedures.map12(
        12,
        48,
        const ScriptContext(tileAtPlayer: 52),
        LoreScriptEngine(),
      )!;
      final initial = offer();
      var run = initial;
      while (run.hasPendingScene) {
        run = run.acknowledgeScene();
      }
      final joined = run.choose(0);
      expect(joined.pendingConditionRefresh, isTrue);
      expect(joined.outcome.recruits.single.key, 'rigel');
      expect(joined.outcome.setFlags, isEmpty);
      expect(
        joined.acknowledgeConditionRefresh().outcome.setFlags,
        contains('etc31_bit2'),
      );
      var blessed = run.choose(1);
      while (blessed.hasPendingScene) {
        blessed = blessed.acknowledgeScene();
      }
      expect(blessed.pendingConditionRefresh, isTrue);
      expect(blessed.outcome.rigelBlessing, isTrue);
      expect(blessed.outcome.foodDelta, -5);
      expect(blessed.outcome.setFlags, isEmpty);
      expect(
        blessed.acknowledgeConditionRefresh().outcome.setFlags,
        contains('etc31_bit2'),
      );
      expect(run.choose(2).pendingConditionRefresh, isFalse);
    },
  );
}

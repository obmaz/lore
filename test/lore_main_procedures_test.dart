import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_main_procedures.dart';

void main() {
  test('enter_water consumes spell, scrolls, then rolls and enters battle', () {
    var steps = 2;
    final trace = <String>[];

    LoreMainProcedures.enterWater(
      waterWalkSteps: () => steps,
      setWaterWalkSteps: (value) {
        steps = value;
        trace.add('steps:$value');
      },
      scrollToParty: () => trace.add('scroll'),
      encounterFrequency: 2,
      random: (bound) {
        trace.add('random:$bound');
        return 0;
      },
      encounterEnemy: () => trace.add('encounter'),
      restorePosition: () => trace.add('restore'),
    );

    expect(steps, 1);
    expect(trace, ['steps:1', 'scroll', 'random:60', 'encounter']);
  });

  test('enter_water restores position without consuming random when dry', () {
    var steps = 0;
    final trace = <String>[];

    LoreMainProcedures.enterWater(
      waterWalkSteps: () => steps,
      setWaterWalkSteps: (value) {
        steps = value;
        trace.add('steps:$value');
      },
      scrollToParty: () => trace.add('scroll'),
      encounterFrequency: 3,
      random: (bound) {
        trace.add('random:$bound');
        return 0;
      },
      encounterEnemy: () => trace.add('encounter'),
      restorePosition: () => trace.add('restore'),
    );

    expect(steps, 0);
    expect(trace, ['restore']);
  });

  test('enter_water does not request battle on a nonzero roll', () {
    var steps = 1;
    final trace = <String>[];

    LoreMainProcedures.enterWater(
      waterWalkSteps: () => steps,
      setWaterWalkSteps: (value) {
        steps = value;
        trace.add('steps:$value');
      },
      scrollToParty: () => trace.add('scroll'),
      encounterFrequency: 1,
      random: (bound) {
        trace.add('random:$bound');
        return 29;
      },
      encounterEnemy: () => trace.add('encounter'),
      restorePosition: () => trace.add('restore'),
    );

    expect(steps, 0);
    expect(trace, ['steps:0', 'scroll', 'random:30']);
  });
}

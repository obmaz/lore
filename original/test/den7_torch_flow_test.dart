import 'support/legacy_json_fixture_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('DEN7 y13의 네 진행 단계 모두 입장 시 횃불을 켠다', () async {
    final engine = LegacyJsonFixtureEngine();
    await engine.load();
    final scenarios = [
      (flags: <String>{}, id: 'den7-dragons-y13', monsters: [54, 54, 54]),
      (
        flags: <String>{'den7DragonsCleared'},
        id: 'den7-mudmen-y13',
        monsters: [31, 31, 31, 31, 31, 31, 31],
      ),
      (
        flags: <String>{'den7DragonsCleared', 'den7MudmenCleared'},
        id: 'den7-master-y13',
        monsters: <int>[],
      ),
      (
        flags: <String>{
          'den7DragonsCleared',
          'den7MudmenCleared',
          'den7MazeCleared',
        },
        id: 'den7-return-y13',
        monsters: <int>[],
      ),
    ];

    for (final scenario in scenarios) {
      final run = engine.startStep(
        20,
        25,
        13,
        ScriptContext(flags: scenario.flags),
      )!;
      expect(run.script.id, scenario.id);
      expect(run.outcome.torchLit, isTrue, reason: scenario.id);
      if (scenario.monsters.isNotEmpty) {
        expect(run.outcome.battleMonsters, scenario.monsters);
        expect(
          run.continueAfterBattle().outcome.since(run.outcome).torchLit,
          scenario.id == 'den7-master-y13' ? isFalse : isTrue,
        );
      }
      if (scenario.id == 'den7-return-y13') {
        expect(
          (
            run.outcome.teleportMap,
            run.outcome.teleportX,
            run.outcome.teleportY,
          ),
          (4, 82, 17),
        );
      }
    }
  });

  test('DEN7 y48 전투는 횃불이 꺼져 있으면 원본처럼 켠다', () async {
    final engine = LegacyJsonFixtureEngine();
    await engine.load();
    final dark = engine.startStep(20, 25, 48, const ScriptContext())!;
    expect(dark.outcome.torchLit, isTrue);
    expect(dark.outcome.battleMonsters, [53]);
    expect(
      dark.continueAfterRunAway().outcome.setFlags,
      contains('den7MinotaurCleared'),
    );

    final lit = engine.startStep(
      20,
      25,
      48,
      const ScriptContext(flags: {'etc1'}),
    )!;
    expect(lit.outcome.torchLit, isFalse);
    expect(lit.outcome.battleMonsters, [53]);
    expect(
      lit.continueAfterRunAway().outcome.setFlags,
      contains('den7MinotaurCleared'),
    );
    expect(
      engine.startStep(
        20,
        25,
        48,
        const ScriptContext(flags: {'den7MinotaurCleared'}),
      ),
      isNull,
    );
  });
}

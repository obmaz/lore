import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';

void main() {
  final scripts = LoreScriptEngine()
    ..loadFromJson(File('assets/data/scripts.json').readAsStringSync());

  test('LOREENT post-load tile writes execute for each source condition', () {
    final castle = scripts.startEnter(
      6,
      const ScriptContext(enteredFromMap: 1),
    );
    expect(castle, isNotNull);
    expect(castle!.outcome.tileChanges.length, 10);
    expect(castle.outcome.tileAreas.single, (
      map: 6,
      xMin: 49,
      yMin: 88,
      xMax: 53,
      yMax: 88,
      tile: 44,
      ifZero: null,
      onlyIf: null,
      atPlayerX: false,
      atPlayerY: false,
    ));

    final polaris = scripts.startEnter(
      7,
      const ScriptContext(enteredFromMap: 1, partyNames: {'Polaris'}),
    );
    expect(polaris?.outcome.tileChanges.single.x, 37);
    expect(polaris?.outcome.tileChanges.single.y, 41);
    expect(
      scripts.startEnter(
        7,
        const ScriptContext(enteredFromMap: 8, partyNames: {'Polaris'}),
      ),
      isNull,
    );
    expect(
      scripts.startEnter(
        7,
        const ScriptContext(enteredFromMap: 11, partyNames: {'Polaris'}),
      ),
      isNull,
    );
    expect(
      scripts.startEnter(7, const ScriptContext(enteredFromMap: 1)),
      isNull,
    );

    final hunter = scripts.startEnter(
      10,
      const ScriptContext(flags: {'loreHunterJoined'}),
    );
    expect(hunter?.outcome.tileChanges.single.tile, 44);
    expect(scripts.startEnter(10, const ScriptContext()), isNull);

    final pyramid = scripts.startEnter(
      11,
      const ScriptContext(questSteps: {'lastditch': 2}),
    );
    expect(pyramid?.outcome.tileChanges.map((tile) => tile.x), [25, 26]);
    expect(scripts.startEnter(11, const ScriptContext()), isNull);

    final seal = scripts.startEnter(
      12,
      const ScriptContext(questSteps: {'gaia': 2}),
    );
    expect(seal?.outcome.tileChanges.single, (
      map: 12,
      x: 18,
      y: 9,
      tile: 0,
      ifZero: null,
    ));

    final shelter = scripts.startEnter(
      24,
      const ScriptContext(flags: {'programmerMet'}),
    );
    expect(shelter?.outcome.tileChanges.single.tile, 47);

    final chamber = scripts.startEnter(
      26,
      const ScriptContext(enteredFromMap: 25),
    );
    expect(chamber?.outcome.tileAreas.single.tile, 16);
    expect(chamber?.outcome.tileAreas.single.xMin, 24);
    expect(chamber?.outcome.tileAreas.single.yMin, 16);
    expect(chamber?.outcome.tileAreas.single.xMax, 26);
    expect(chamber?.outcome.tileAreas.single.yMax, 19);
  });
}

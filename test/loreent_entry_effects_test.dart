import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/logic/lore_ent_procedures.dart';

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

  test('직접 이식한 load 후 지도 변경은 출발지와 조건을 보존한다', () {
    List<(int, int, int)> changes(
      int fromMap,
      int toMap, {
      Set<String> partyNames = const {},
      Set<String> flags = const {},
      Map<String, int> questSteps = const {},
    }) {
      final writes = <(int, int, int)>[];
      LoreEntProcedures.afterMapLoadTiles(
        fromMap: fromMap,
        toMap: toMap,
        partyNames: partyNames,
        flags: flags,
        questSteps: questSteps,
        setTile: (x, y, tile) => writes.add((x, y, tile)),
      );
      return writes;
    }

    expect(changes(1, 6), hasLength(15));
    expect(changes(1, 7, partyNames: {'Polaris'}), [(37, 41, 44)]);
    expect(changes(8, 7, partyNames: {'Polaris'}), isEmpty);
    expect(changes(11, 7, partyNames: {'Polaris'}), isEmpty);
    expect(changes(3, 10, flags: {'loreHunterJoined'}), [(40, 56, 44)]);
    expect(changes(16, 10, flags: {'loreHunterJoined'}), [(40, 56, 44)]);
    expect(changes(7, 11, questSteps: {'lastditch': 2}), [
      (25, 44, 50),
      (26, 44, 50),
    ]);
    expect(changes(7, 11, questSteps: {'lastditch': 1}), isEmpty);
    expect(changes(8, 12, questSteps: {'gaia': 2}), [(18, 9, 0)]);
    expect(changes(22, 24, flags: {'programmerMet'}), [(33, 10, 47)]);
    expect(changes(25, 26), hasLength(12));
    expect(changes(25, 26).first, (24, 16, 16));
    expect(changes(25, 26).last, (26, 19, 16));
  });
}

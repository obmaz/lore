import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dungeon_event_manager.dart';
import 'package:lore/logic/lore_spec_procedures.dart';
import 'package:lore/logic/lore_special_event_dispatcher.dart';
import 'package:lore/logic/lore_tile_protocol.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LoreScriptEngine scripts;

  setUp(() {
    scripts = LoreScriptEngine()
      ..loadFromJson(File('assets/data/scripts.json').readAsStringSync());
  });

  ScriptRun? dispatchSpecial({
    required int mapId,
    required int x,
    required int y,
    int tile = 0,
    Set<String> flags = const {},
    Map<String, int> questSteps = const {},
  }) {
    final result = LoreSpecialEventDispatcher.resolve(
      action: LoreTileAction.special,
      mapId: mapId,
      x: x,
      y: y,
      context: ScriptContext(
        tileAtPlayer: tile,
        flags: flags,
        questSteps: questSteps,
      ),
      party: const [],
      scripts: scripts,
      legacy: LoreDungeonEventManager.instance,
    );
    expect(result.legacy, isNull);
    return result.script;
  }

  group('LORESPEC 맵 27 PYRAMID1 / ANOTHER LORE 분기 검증 (LORESPEC.PAS:2202-2213)', () {
    test('y < 25 이면 아래로 밀어내고 (inc y / nudge dy: 1), y >= 25 이면 위로 밀어낸다 (dec y / nudge dy: -1)', () {
      final runUpper = LoreSpecProcedures.map27(
        15,
        10,
        const ScriptContext(tileAtPlayer: 0),
        scripts,
      )!;
      expect(runUpper.outcome.nudges.first.dy, 1);

      final runDispatcherUpper = dispatchSpecial(
        mapId: 27,
        x: 15,
        y: 10,
        tile: 0,
      )!;
      expect(runDispatcherUpper.outcome.nudges.first.dy, 1);

      final runLower = LoreSpecProcedures.map27(
        15,
        30,
        const ScriptContext(tileAtPlayer: 0),
        scripts,
      )!;
      expect(runLower.outcome.nudges.first.dy, -1);

      final runDispatcherLower = dispatchSpecial(
        mapId: 27,
        x: 15,
        y: 30,
        tile: 0,
      )!;
      expect(runDispatcherLower.outcome.nudges.first.dy, -1);
    });
  });
}

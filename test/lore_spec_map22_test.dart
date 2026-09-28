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

  group('LORESPEC 맵 22 KEEP2 / IMPERIUM MINOR 분기 검증 (LORESPEC.PAS:1816-1879)', () {
    test('(25, 18) Death Knight 기습 분기는 etc43_bit2 미설정 시 발동하고 대사와 전투를 발생시킨다', () {
      final runDirect = LoreSpecProcedures.map22(
        25,
        18,
        const ScriptContext(tileAtPlayer: 0),
        scripts,
      )!;
      expect(
        runDirect.outcome.messages,
        contains(' 나는 이 요새의 Wraith를 조종하는 죽음의 기'),
      );
      expect(runDirect.awaitingBattle, isTrue);
      expect(runDirect.outcome.battleTitle, 'Death Knight');

      final runDispatcher = dispatchSpecial(
        mapId: 22,
        x: 25,
        y: 18,
        tile: 0,
      )!;
      expect(
        runDispatcher.outcome.messages,
        contains(' 나는 이 요새의 Wraith를 조종하는 죽음의 기'),
      );
      expect(runDispatcher.awaitingBattle, isTrue);

      final defeated = LoreSpecProcedures.map22(
        25,
        18,
        const ScriptContext(tileAtPlayer: 0, flags: {'etc43_bit2'}),
        scripts,
      );
      expect(defeated, isNull);
    });

    test('y=25 and x in 24..26 요새 수비대 기습 분기는 etc43_bit1 미설정 시 발동한다', () {
      for (final px in [24, 25, 26]) {
        final runGuards = LoreSpecProcedures.map22(
          px,
          25,
          const ScriptContext(tileAtPlayer: 0),
          scripts,
        )!;
        expect(runGuards.awaitingBattle, isTrue);
        expect(runGuards.outcome.battleMonsters, [61, 58, 56, 55, 60]);

        final runDispatcher = dispatchSpecial(
          mapId: 22,
          x: px,
          y: 25,
          tile: 0,
        )!;
        expect(runDispatcher.awaitingBattle, isTrue);
      }

      final defeated = LoreSpecProcedures.map22(
        25,
        25,
        const ScriptContext(tileAtPlayer: 0, flags: {'etc43_bit1'}),
        scripts,
      );
      expect(defeated, isNull);
    });
  });
}

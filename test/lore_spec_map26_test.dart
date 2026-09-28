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

  group('LORESPEC 맵 26 CHAMBER OF NECROMANCER 분기 검증 (LORESPEC.PAS:2104-2201)', () {
    test('타일 0에서 최종 보스 연출 및 Neo-Necromancer 전투 시퀀스 검증', () {
      final runDirect = LoreSpecProcedures.map26(
        25,
        15,
        const ScriptContext(tileAtPlayer: 0),
        scripts,
      )!;
      expect(
        runDirect.outcome.messages,
        contains(' 당신들이 나를 없에겠다고 온자들인가?'),
      );
      expect(runDirect.awaitingBattle, isTrue);
      expect(runDirect.outcome.battleMonsters, [69, 70, 71, 72, 73, 74, 75]);

      final runDispatcher = dispatchSpecial(
        mapId: 26,
        x: 25,
        y: 15,
        tile: 0,
      )!;
      expect(runDispatcher.awaitingBattle, isTrue);

      final defeated = LoreSpecProcedures.map26(
        25,
        15,
        const ScriptContext(tileAtPlayer: 0, flags: {'bossNecromancerDefeated'}),
        scripts,
      );
      expect(defeated, isNull);
    });

    test('타일이 0이 아니면 최종 연출이 발동하지 않는다', () {
      final runNonZero = LoreSpecProcedures.map26(
        25,
        15,
        const ScriptContext(tileAtPlayer: 16),
        scripts,
      );
      expect(runNonZero, isNull);

      final runDispatcherNonZero = dispatchSpecial(
        mapId: 26,
        x: 25,
        y: 15,
        tile: 16,
      );
      expect(runDispatcherNonZero, isNull);
    });
  });
}

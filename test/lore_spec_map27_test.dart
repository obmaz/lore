import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dungeon_event_manager.dart';
import 'package:lore/game/lore_world_manager.dart';
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

  group(
    'LORESPEC 맵 27 PYRAMID1 / ANOTHER LORE 분기 검증 (LORESPEC.PAS:2202-2212)',
    () {
      test('특수 칸은 모두 wantexit 경계이며 사건 처리기나 JSON 밀기를 실행하지 않는다', () {
        for (final y in [5, 24, 25, 46]) {
          expect(
            LoreSpecProcedures.map27(
              15,
              y,
              const ScriptContext(tileAtPlayer: 0),
              scripts,
            ),
            isNull,
          );
          expect(dispatchSpecial(mapId: 27, x: 15, y: y), isNull);
        }
      });

      test('수락은 맵 1 (20,8), 거절은 y < 25면 y+1, 아니면 y-1', () {
        final world = LoreWorldManager.instance;
        for (final y in [5, 24, 25, 46]) {
          final portal = world.findPortal(27, 15, y)!;
          expect(
            [portal.targetMapId, portal.targetX, portal.targetY],
            [1, 20, 8],
          );
          expect(
            LoreWorldManager.sourceExitRejectY(27, y),
            y < 25 ? y + 1 : y - 1,
          );
        }
        for (final map in [23, 24, 25]) {
          expect(LoreWorldManager.sourceExitRejectY(map, 46), 45);
          expect(LoreWorldManager.sourceExitRejectY(map, 45), isNull);
          expect(world.findPortal(map, 25, 47), isNull);
        }
        expect(LoreWorldManager.sourceExitRejectY(6, 46), isNull);
      });
    },
  );
}

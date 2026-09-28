import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dungeon_event_manager.dart';
import 'package:lore/game/lore_world_manager.dart';
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
  }) {
    final result = LoreSpecialEventDispatcher.resolve(
      action: LoreTileAction.special,
      mapId: mapId,
      x: x,
      y: y,
      context: ScriptContext(tileAtPlayer: tile, flags: flags),
      party: const [],
      scripts: scripts,
      legacy: LoreDungeonEventManager.instance,
    );
    expect(result.legacy, isNull);
    return result.script;
  }

  group('LORESPEC 맵 7 LASTDITCH & 맵 8 WATER FIELD 분기 검증 (LORESPEC.PAS:306-353)', () {
    test('맵 7 비밀벽 특수 타일은 범용 startStep과 중복 실행되지 않는다', () {
      for (final x in const [30, 32]) {
        for (var y = 8; y <= 11; y++) {
          expect(
            scripts.startStep(7, x, y, const ScriptContext(tileAtPlayer: 0)),
            isNull,
            reason: '($x, $y)는 LoreSpecProcedures.map7에서 단일 관리되어야 한다',
          );
        }
      }
    });

    test('맵 7: x=30 또는 x=32에서 비밀벽 타일 (31, y)를 45로 연다', () {
      for (final x in [30, 32]) {
        final run = dispatchSpecial(mapId: 7, x: x, y: 9, tile: 0);
        expect(run, isNotNull);
        expect(
          run!.script.id,
          x == 30 ? 'lastditch-passwall-left' : 'lastditch-passwall-right',
        );
        final area = run.outcome.tileAreas.single;
        expect((area.xMin, area.xMax, area.tile), (31, 31, 45));
        expect(area.atPlayerY, isTrue);

        // 일반 바닥 타일(0이 아닌 타일)에서는 비밀벽 이벤트 미발생
        expect(
          dispatchSpecial(mapId: 7, x: x, y: 9, tile: 45),
          isNull,
        );
      }
    });

    test('맵 7: 비밀벽 이외의 특수 타일 좌표는 스텝 사건을 발생시키지 않는다', () {
      expect(
        dispatchSpecial(mapId: 7, x: 20, y: 20, tile: 0),
        isNull,
      );
    });

    test('맵 8: 특수 타일 스텝 사건은 정의되어 있지 않다', () {
      for (final (x, y) in const [(50, 10), (30, 30), (51, 71)]) {
        expect(
          dispatchSpecial(mapId: 8, x: x, y: y, tile: 0),
          isNull,
        );
      }
    });

    test('맵 7 & 맵 8: GROUND GATE 및 남쪽 출구 포털이 원본 목적지와 일치한다', () async {
      final world = LoreWorldManager.instance;
      world.resetRulesForTest();
      await world.loadData();

      // 맵 7 x=50: GROUND GATE -> 맵 8 (50, 10)
      final gate7 = world.findPortal(7, 50, 10);
      expect(gate7, isNotNull);
      expect((gate7!.targetMapId, gate7.targetX, gate7.targetY), (8, 50, 10));

      // 맵 7 y=71: wantexit -> 맵 1 (77, 57)
      final exit7 = world.findPortal(7, 51, 71);
      expect(exit7, isNotNull);
      expect((exit7!.targetMapId, exit7.targetX, exit7.targetY), (1, 77, 57));

      // 맵 8 x=50: GROUND GATE -> 맵 7 (50, 10)
      final gate8 = world.findPortal(8, 50, 10);
      expect(gate8, isNotNull);
      expect((gate8!.targetMapId, gate8.targetX, gate8.targetY), (7, 50, 10));

      // 맵 8 y=71: wantexit -> 맵 2 (19, 27)
      final exit8 = world.findPortal(8, 51, 71);
      expect(exit8, isNotNull);
      expect((exit8!.targetMapId, exit8.targetX, exit8.targetY), (2, 19, 27));

      world.resetRulesForTest();
    });
  });
}

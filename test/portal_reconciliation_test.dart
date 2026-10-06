import 'support/legacy_json_fixture_engine.dart';

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/game/lore_world_manager.dart';
import 'package:lore/logic/script_world_reducer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('맵 26은 입장 직후 face 5, 방향키 뒤에는 추가 4 오프셋을 쓴다', () async {
    final map = await LoreMapData.loadFromAsset('K_DEN2', category: 'den');
    final game =
        LoreGame(initialMapId: 26, initialPlayerX: 25, initialPlayerY: 15)
          ..currentMap = map
          ..currentMapName = 'K_DEN2'
          ..playerDirection = 1;
    expect(game.playerSpriteIndex, 5);
    game.tryMove(1, 0);
    expect(game.playerSpriteIndex, 10);
  });

  test('LOREMAIN sign 호출 전에 originposition으로 시야를 되돌린다', () async {
    final map = await LoreMapData.loadFromAsset('GROUND2', category: 'ground');
    final game = LoreGame(
      initialMapId: 2,
      initialPlayerX: 30,
      initialPlayerY: 44,
    )..currentMap = map;
    game.peekAt(40, 44);
    expect(map.getTile(31, 44), 22);
    game.tryMove(1, 0);
    expect(game.isPeeking, isFalse);
    expect((game.playerX, game.playerY), (30, 44));
  });

  test(
    'LORESPEC.PAS map 8 special gate enters (50,10) before confirmation',
    () async {
      LoreWorldManager.instance.resetRulesForTest();
      final map = await LoreMapData.loadFromAsset('TOWN3', category: 'town');
      PortalInfo? requested;
      final game = LoreGame(
        initialMapId: 8,
        initialPlayerX: 51,
        initialPlayerY: 10,
        onPortalRequested: (portal, _, _) => requested = portal,
      )..currentMap = map;

      expect(map.getTile(50, 10), 0);
      expect(game.tryMove(-1, 0), isTrue);
      expect((game.playerX, game.playerY), (50, 10));
      expect(requested?.targetMapId, 7);
      expect((requested?.targetX, requested?.targetY), (50, 10));
    },
  );

  test('원본 entermode에 좌표 규칙이 없는 진입 타일은 지도를 바꾸지 않는다', () async {
    LoreWorldManager.instance.resetRulesForTest();
    for (final site in [
      (mapId: 2, name: 'GROUND2', category: 'ground', x: 80, y: 47),
      (mapId: 2, name: 'GROUND2', category: 'ground', x: 84, y: 47),
      (mapId: 2, name: 'GROUND2', category: 'ground', x: 81, y: 49),
      (mapId: 2, name: 'GROUND2', category: 'ground', x: 83, y: 49),
      (mapId: 4, name: 'SWAMP', category: 'ground', x: 26, y: 15),
      (mapId: 4, name: 'SWAMP', category: 'ground', x: 25, y: 16),
      (mapId: 4, name: 'SWAMP', category: 'ground', x: 27, y: 16),
      (mapId: 17, name: 'DEN4', category: 'den', x: 80, y: 67),
      (mapId: 17, name: 'DEN4', category: 'den', x: 81, y: 67),
      (mapId: 17, name: 'DEN4', category: 'den', x: 82, y: 67),
      (mapId: 26, name: 'K_DEN2', category: 'town', x: 28, y: 43),
    ]) {
      final map = await LoreMapData.loadFromAsset(
        site.name,
        category: site.category,
      );
      var requests = 0;
      final game = LoreGame(
        initialMapId: site.mapId,
        initialPlayerX: site.x - 1,
        initialPlayerY: site.y,
        onPortalRequested: (_, _, _) => requests++,
      )..currentMap = map;
      game.peekAt(site.x, site.y);

      expect(
        game.tryMove(1, 0),
        isFalse,
        reason: '${site.mapId} (${site.x},${site.y})',
      );
      expect((game.playerX, game.playerY), (site.x - 1, site.y));
      expect(game.currentMapId, site.mapId);
      expect(game.isPeeking, isFalse);
      expect(requests, 0);
    }
  });

  test('원본 사건이 동적으로 연 입구는 등록된 목적지로 연결된다', () async {
    final manager = LoreWorldManager.instance;
    manager.resetRulesForTest();
    await manager.loadData();
    final scripts = LegacyJsonFixtureEngine()
      ..loadFromJson(
        File('test/fixtures/legacy_rules/scripts.json').readAsStringSync(),
      );
    for (final site in [
      (
        mapId: 23,
        name: 'KEEP3',
        category: 'keep',
        eventX: 25,
        eventY: 27,
        portalX: 25,
        portalY: 12,
        fromY: 13,
        context: const ScriptContext(tileAtPlayer: 52),
        targetMapId: 25,
      ),
      (
        mapId: 25,
        name: 'K_DEN2',
        category: 'den',
        eventX: 5,
        eventY: 34,
        portalX: 25,
        portalY: 27,
        fromY: 28,
        context: const ScriptContext(flags: {'keep3KeyA', 'keep3KeyB'}),
        targetMapId: 26,
      ),
    ]) {
      final sourceMap = await LoreMapData.loadFromAsset(
        site.name,
        category: site.category,
      );
      final run = scripts.startStep(
        site.mapId,
        site.eventX,
        site.eventY,
        site.context,
      );
      expect(run, isNotNull, reason: 'map ${site.mapId}');
      final changed = ScriptWorldReducer.applyMap(
        ScriptMapState(
          mapId: site.mapId,
          x: site.eventX,
          y: site.eventY,
          direction: 0,
          grid: sourceMap.grid,
        ),
        run!.outcome,
      );
      final map = LoreMapData(
        name: site.name,
        category: site.category,
        xmax: sourceMap.xmax,
        ymax: sourceMap.ymax,
        grid: changed.grid,
      );
      expect(map.getTile(site.portalX, site.portalY), 54);
      PortalInfo? requested;
      final game = LoreGame(
        initialMapId: site.mapId,
        initialPlayerX: site.portalX,
        initialPlayerY: site.fromY,
        onPortalRequested: (portal, _, _) => requested = portal,
      )..currentMap = map;
      expect(game.tryMove(0, -1), isFalse);
      expect(requested?.targetMapId, site.targetMapId);
      expect((game.playerX, game.playerY), (site.portalX, site.fromY));
    }
    manager.resetRulesForTest();
  });

  test('맵 21 출구의 수문장 분기는 남은 적과 완료 상태에 따라 바뀐다', () async {
    final engine = LegacyJsonFixtureEngine();
    await engine.load();

    final bothAlive = engine.startById(
      'keep1-exit-guard',
      const ScriptContext(),
    )!;
    expect(bothAlive.outcome.battleMonsters, [55, 56, 35, 35, 35, 35, 35]);

    final oneAlive = engine.startById(
      'keep1-exit-guard',
      const ScriptContext(flags: {'keep1LeftGuardianDefeated'}),
    )!;
    expect(oneAlive.outcome.battleMonsters, [56, 35, 35, 35, 35, 35]);

    final bothDead = engine.startById(
      'keep1-exit-guard',
      const ScriptContext(
        flags: {'keep1LeftGuardianDefeated', 'keep1RightGuardianDefeated'},
      ),
    )!;
    expect(bothDead.awaitingBattle, isFalse);
    expect(bothDead.outcome.blockMove, isTrue);
    expect(bothDead.outcome.setFlags, contains('swampKeepBossDefeated'));

    expect(
      engine.startById(
        'keep1-exit-guard',
        const ScriptContext(
          flags: {
            'keep1LeftGuardianDefeated',
            'keep1RightGuardianDefeated',
            'swampKeepBossDefeated',
          },
        ),
      ),
      isNull,
    );
  });
}

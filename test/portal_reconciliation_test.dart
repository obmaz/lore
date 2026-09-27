import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/game/lore_world_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('맵 8 포털 확인 전에는 위치가 그대로이고 목적지는 원본과 같다', () async {
    LoreWorldManager.instance.resetRulesForTest();
    final map = await LoreMapData.loadFromAsset('TOWN3', category: 'town');
    PortalInfo? requested;
    final game = LoreGame(
      initialMapId: 8,
      initialPlayerX: 51,
      initialPlayerY: 10,
      onPortalRequested: (portal, _, _) => requested = portal,
    )..currentMap = map;

    expect(game.tryMove(-1, 0), isFalse);
    expect((game.playerX, game.playerY), (51, 10));
    expect(requested?.targetMapId, 7);
    expect((requested?.targetX, requested?.targetY), (50, 10));
  });

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

      expect(
        game.tryMove(1, 0),
        isFalse,
        reason: '${site.mapId} (${site.x},${site.y})',
      );
      expect((game.playerX, game.playerY), (site.x - 1, site.y));
      expect(game.currentMapId, site.mapId);
      expect(requests, 0);
    }
  });

  test('맵 21 출구의 수문장 분기는 남은 적과 완료 상태에 따라 바뀐다', () async {
    final engine = LoreScriptEngine();
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

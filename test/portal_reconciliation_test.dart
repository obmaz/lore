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

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/game/lore_world_manager.dart';
import 'package:lore/logic/lore_sub_text.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/services/save_manager.dart';
import 'package:lore/widgets/battle_viewport_view.dart';
import 'package:lore/widgets/game_over_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// LORESPEC.PAS:1870-1876 (KEEP2 Wraith ambush) through GameOver: after the
/// defeat is reloaded, `map[x,y] := 40` runs at the loaded position.
void main() {
  testWidgets('a reloaded Wraith defeat writes tile 40 at the loaded x, y', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      LoreDialogueManager.instance.loadFlags({});
      LoreScriptEngine.instance.resetForTest();
      LoreWorldManager.instance.resetRulesForTest();
    });
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    void silence(String channel) => messenger.setMockStreamHandler(
      EventChannel(channel),
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
    silence('xyz.luan/audioplayers.global/events');
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (_) async => 1,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async {
        if (call.method == 'create') {
          silence(
            'xyz.luan/audioplayers/events/${(call.arguments as Map)['playerId']}',
          );
        }
        return 1;
      },
    );
    final map = await LoreMapData.loadFromAsset('KEEP2', category: 'keep');
    expect([map.getTile(18, 6), map.getTile(33, 6)], [0, 0]);
    SaveData save(int x, int y, {int hp = 30000}) => SaveData(
      slot: 1,
      slotName: SaveManager.slotNames.first,
      timestamp: DateTime.utc(1993),
      mapId: 22,
      mapTitle: 'KEEP2',
      playerX: x,
      playerY: y,
      gold: 100,
      food: 20,
      party: [PartyMember.createPreset(1)..hp = hp],
      flags: const {'etc43': 0, 'etc1': 3},
      mapTiles: map.tileSnapshot(),
    );
    SharedPreferences.setMockInitialValues({});
    await SaveManager.instance.saveGame(save(33, 6, hp: 100));
    await tester.pumpWidget(
      MaterialApp(home: MainGameScreen(initialSaveData: save(18, 7))),
    );
    final finder = find.byType(GameWidget<LoreGame>);
    final game = tester.widget<GameWidget<LoreGame>>(finder).game!;
    await tester.runAsync(
      () => tester.state<GameWidgetState<LoreGame>>(finder).loaderFuture,
    );
    await tester.pump();

    game.tryMove(0, -1); // onto the tile-0 special cell (18,6)
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    // BattleMode(FALSE): the enemy phase runs first.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 200));
    final battle = tester.widget<BattleViewportView>(
      find.byType(BattleViewportView),
    );
    expect(battle.enemies.map((e) => e.eNumber), [60, 60, 60, 60, 60]);
    battle.onDefeat();
    await tester.pump();
    await tester.pump();
    expect(find.text(LoreSubText.battleLost), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lore-select-1')).last);
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('lore-select-2')).last);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(GameOverView), findsNothing);
    expect([game.currentMapId, game.playerX, game.playerY], [22, 33, 6]);
    expect(LoreDialogueManager.instance.lastBattleResult, 255);
    // The loaded map: the battle cell is untouched, the loaded cell is 40.
    expect(game.currentMap!.getTile(18, 6), 0);
    expect(game.currentMap!.getTile(33, 6), 40);
  });
}

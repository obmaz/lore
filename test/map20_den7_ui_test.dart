import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/game/lore_world_manager.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/services/save_manager.dart';
import 'package:lore/widgets/battle_viewport_view.dart';
import 'package:lore/widgets/script_scene_dialog.dart';

/// LORESPEC.PAS map 20 (1475-1759) events through the real screen.
void main() {
  Future<LoreGame> open(
    WidgetTester tester,
    int id,
    String file,
    String category,
    int x,
    int y, {
    Map<String, dynamic> flags = const {},
  }) async {
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
    // Each player listens on its own event channel, named by its playerId.
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
    final map = await LoreMapData.loadFromAsset(file, category: category);
    await tester.pumpWidget(
      MaterialApp(
        home: MainGameScreen(
          initialSaveData: SaveData(
            slot: 1,
            slotName: '출구',
            timestamp: DateTime.utc(1993),
            mapId: id,
            mapTitle: file,
            playerX: x,
            playerY: y,
            gold: 100,
            food: 20,
            party: [PartyMember.createPreset(1)],
            flags: flags,
            mapTiles: map.tileSnapshot(),
          ),
        ),
      ),
    );
    final finder = find.byType(GameWidget<LoreGame>);
    final game = tester.widget<GameWidget<LoreGame>>(finder).game!;
    await tester.runAsync(
      () => tester.state<GameWidgetState<LoreGame>>(finder).loaderFuture,
    );
    await tester.pump();
    return game;
  }

  Future<void> tick(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
  }

  testWidgets('y=54 quiz Escape moves the party to y=55 without writes', (
    tester,
  ) async {
    final game = await open(tester, 20, 'DEN7', 'den', 24, 53);
    expect(game.currentMap!.getTile(24, 54), 0);
    game.tryMove(0, 1);
    await tick(tester);
    expect(find.text('위의 말은 옳다'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('dialog-cancel')));
    await tick(tester);
    expect([game.currentMapId, game.playerX, game.playerY], [20, 24, 55]);
    expect(game.currentMap!.getTile(23, 54), 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Escape key cancels the select dialog like the cancel icon', (
    tester,
  ) async {
    final game = await open(tester, 20, 'DEN7', 'den', 24, 53);
    expect(game.currentMap!.getTile(24, 54), 0);
    game.tryMove(0, 1);
    await tick(tester);
    expect(find.text('위의 말은 옳다'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tick(tester);
    expect([game.currentMapId, game.playerX, game.playerY], [20, 24, 55]);
    expect(game.currentMap!.getTile(23, 54), 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Astral Mud: enemy 7 dead on escape sets bit1, loads map 4, then the seal text',
    (tester) async {
      final game = await open(
        tester,
        20,
        'DEN7',
        'den',
        24,
        14,
        flags: {'etc41': 6, 'etc1': 3},
      );
      game.tryMove(0, -1);
      await tick(tester);
      expect(
        tester
            .widget<ScriptSceneDialog>(find.byType(ScriptSceneDialog).last)
            .scene
            .title,
        'Astral Mud',
      );
      await tester.tap(
        find.byKey(const ValueKey('script-scene-continue')).last,
      );
      await tick(tester);
      final battle = tester.widget<BattleViewportView>(
        find.byType(BattleViewportView),
      );
      expect(battle.enemies.map((e) => e.eNumber), [
        31,
        31,
        31,
        31,
        31,
        31,
        57,
      ]);
      battle.enemies.last.isDead = true;
      battle.onRunAway();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tick(tester);
      expect([game.currentMapId, game.playerX, game.playerY], [4, 82, 17]);
      expect(
        tester
            .widget<ScriptSceneDialog>(find.byType(ScriptSceneDialog).last)
            .scene
            .lines
            .first,
        ' 당신은 이 동굴에 보관되어 있는 봉인을 발견',
      );
      expect(LoreDialogueManager.instance.partyEtc.read(41) & 1, 1);
      await tester.tap(
        find.byKey(const ValueKey('script-scene-continue')).last,
      );
      await tick(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );
}

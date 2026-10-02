import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/game/lore_world_manager.dart';
import 'package:lore/logic/lore_field_logic.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/services/save_manager.dart';
import 'package:lore/widgets/battle_viewport_view.dart';
import 'package:lore/widgets/script_scene_dialog.dart';

/// LORESPEC.PAS map 21 (1762-1795), map 22 (1818-1839), map 24 (1980-1994) and map 27 (2202-2212) `wantexit` arms
/// through the real screen: refusal position and accepted destination.
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

  for (final c in [
    (
      id: 24,
      file: 'K_DEN1',
      cat: 'town',
      x: 24,
      from: 45,
      to: 46,
      back: 45,
      dest: [22, 25, 24],
    ),
    (
      id: 27,
      file: 'PYRAMID1',
      cat: 'town',
      x: 15,
      from: 6,
      to: 5,
      back: 6,
      dest: [1, 20, 8],
    ),
    (
      id: 27,
      file: 'PYRAMID1',
      cat: 'town',
      x: 15,
      from: 45,
      to: 46,
      back: 45,
      dest: [1, 20, 8],
    ),
  ]) {
    testWidgets(
      'map ${c.id} y=${c.to}: refusal leaves y=${c.back}, acceptance loads ${c.dest}',
      (tester) async {
        final game = await open(tester, c.id, c.file, c.cat, c.x, c.from);
        expect(game.currentMap!.getTile(c.x, c.to), 0);
        game.tryMove(0, c.to - c.from);
        await tick(tester);
        expect(find.text(LoreFieldLogic.exitPrompt), findsOneWidget);
        await tester.tap(find.text(LoreFieldLogic.confirmNo));
        await tick(tester);
        expect(
          [game.currentMapId, game.playerX, game.playerY],
          [c.id, c.x, c.back],
        );
        game.tryMove(0, c.to - c.back);
        await tick(tester);
        await tester.tap(find.text(LoreFieldLogic.confirmYes));
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tick(tester);
        expect([game.currentMapId, game.playerX, game.playerY], c.dest);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'map 22 exit: accepted guard fight, enemy 7 dead then escape still exits',
    (tester) async {
      final game = await open(
        tester,
        22,
        'KEEP2',
        'keep',
        25,
        45,
        flags: {'etc43': 0},
      );
      expect(game.currentMap!.getTile(25, 46), anyOf(0, 52));
      game.tryMove(0, 1);
      await tick(tester);
      await tester.tap(find.text(LoreFieldLogic.confirmYes));
      await tick(tester);
      final scene = tester.widget<ScriptSceneDialog>(
        find.byType(ScriptSceneDialog).last,
      );
      expect(
        scene.scene.lines.single,
        '${game.partyProvider!().first.name}, 나의 힘을 보여주겠다.',
      );
      await tester.tap(
        find.byKey(const ValueKey('script-scene-continue')).last,
      );
      await tick(tester);
      final battle = tester.widget<BattleViewportView>(
        find.byType(BattleViewportView),
      );
      expect(battle.enemies.length, 7);
      expect(battle.enemies.last.eNumber, 66);
      expect(battle.enemyFirst, isTrue);
      expect(game.currentMapId, 22);
      battle.enemies.last.isDead = true;
      battle.onRunAway();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tick(tester);
      expect([game.currentMapId, game.playerX, game.playerY], [5, 15, 32]);
      expect(LoreDialogueManager.instance.partyEtc.read(43) & 4, 4);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'map 21 exit with both bosses gone sets bit1 and stays on the exit cell',
    (tester) async {
      final game = await open(
        tester,
        21,
        'KEEP1',
        'keep',
        25,
        45,
        flags: {'etc42': 12},
      );
      game.tryMove(0, 1);
      await tick(tester);
      await tester.tap(find.text(LoreFieldLogic.confirmYes));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tick(tester);
      expect([game.currentMapId, game.playerX, game.playerY], [21, 25, 46]);
      expect(LoreDialogueManager.instance.partyEtc.read(42), 13);
      expect(find.byType(BattleViewportView), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'map 21 exit guard: slot 1 dead on escape sets bit3 and still leaves',
    (tester) async {
      final game = await open(
        tester,
        21,
        'KEEP1',
        'keep',
        25,
        45,
        flags: {'etc42': 0},
      );
      game.tryMove(0, 1);
      await tick(tester);
      await tester.tap(find.text(LoreFieldLogic.confirmYes));
      await tick(tester);
      final battle = tester.widget<BattleViewportView>(
        find.byType(BattleViewportView),
      );
      expect(battle.enemies.map((e) => e.eNumber), [
        55,
        56,
        35,
        35,
        35,
        35,
        35,
      ]);
      battle.enemies.first.isDead = true;
      battle.onRunAway();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tick(tester);
      expect([game.currentMapId, game.playerX, game.playerY], [4, 48, 36]);
      expect(LoreDialogueManager.instance.partyEtc.read(42), 4);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );
}

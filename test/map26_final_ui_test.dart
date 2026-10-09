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
import 'package:lore/widgets/ending_view.dart';
import 'package:lore/widgets/script_scene_dialog.dart';

/// LORESPEC.PAS final arm and map25 exit; LOREENT.PAS chamber continuation.
void main() {
  Future<LoreGame> open(WidgetTester tester, int id, int x, int y) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      LoreDialogueManager.instance.loadFlags({});
      LoreScriptEngine.instance.resetForTest();
      LoreWorldManager.instance.resetRulesForTest();
    });
    for (final channel in [
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers.global',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), (_) async => 1);
    }
    final map = await LoreMapData.loadFromAsset(
      'K_DEN2',
      category: id == 26 ? 'town' : 'den',
    );
    map.setTile(x, y, 0);
    await tester.pumpWidget(
      MaterialApp(
        home: MainGameScreen(
          initialSaveData: SaveData(
            slot: 1,
            slotName: '최종 결전',
            timestamp: DateTime.utc(1993),
            mapId: id,
            mapTitle: 'K_DEN2',
            playerX: x,
            playerY: y,
            gold: 100,
            food: 20,
            party: [PartyMember.createPreset(1), PartyMember.createPreset(3)],
            flags: const {'etc1': 255},
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

  Future<void> acknowledge(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('script-scene-continue')).last);
    await tick(tester);
  }

  testWidgets(
    'final UI retains damaged/dead enemy slots on retry and awaits farewell before End_Demo',
    (tester) async {
      final game = await open(tester, 26, 25, 15);
      expect(game.onStepTaken!(), isTrue);
      await tick(tester);
      expect([game.playerX, game.playerY, game.playerSpriteIndex], [25, 15, 5]);
      expect(find.byType(ScriptSceneDialog), findsNothing);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 1500));
      }
      expect([game.playerX, game.playerY, game.playerSpriteIndex], [26, 12, 5]);
      expect(game.specialArrivalDraws.last.index, 26);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 2));
      }
      await tick(tester);
      expect([game.playerX, game.playerY, game.playerSpriteIndex], [26, 12, 5]);
      expect(find.byType(BattleViewportView), findsNothing);
      expect(find.byType(EndingView), findsNothing);
      await acknowledge(tester);
      final first = tester.widget<BattleViewportView>(
        find.byType(BattleViewportView),
      );
      expect(first.enemies.map((e) => e.eNumber), [69, 70, 71, 72, 73, 74, 75]);
      expect(first.enemyFirst, isTrue);
      expect(LoreDialogueManager.instance.partyEtc.read(6), 1);
      first.enemies[0].isDead = true;
      first.enemies[3].hp = 23;
      first.onRunAway();
      await tick(tester);
      expect(LoreDialogueManager.instance.partyEtc.read(6), 2);
      expect(
        tester
            .widget<ScriptSceneDialog>(find.byType(ScriptSceneDialog).last)
            .scene
            .title,
        '도주 불가',
      );
      expect(find.byType(BattleViewportView), findsNothing);
      expect(find.byType(EndingView), findsNothing);
      await acknowledge(tester);
      final retry = tester.widget<BattleViewportView>(
        find.byType(BattleViewportView),
      );
      expect(identical(retry.enemies, first.enemies), isTrue);
      expect(retry.enemies[0].isDead, isTrue);
      expect(retry.enemies[3].hp, 23);
      expect(LoreDialogueManager.instance.partyEtc.read(6), 1);
      expect([game.playerX, game.playerY], [26, 12]);
      retry.enemies[6].isDead = true;
      retry.onRunAway();
      await tick(tester);
      expect(LoreDialogueManager.instance.partyEtc.read(6), 2);
      expect(
        tester
            .widget<ScriptSceneDialog>(find.byType(ScriptSceneDialog).last)
            .scene
            .title,
        '최후의 대사',
      );
      expect(find.byType(EndingView), findsNothing);
      expect(find.byType(BattleViewportView), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tick(tester);
      expect(find.byType(EndingView), findsOneWidget);
      expect(
        tester.widget<EndingView>(find.byType(EndingView)).initialKeyWasEscape,
        isTrue,
      );
      expect(
        LoreDialogueManager.instance.getFlagsCopy()['bossNecromancerDefeated'],
        isNot(true),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'map25 exit uses source confirmation, cancellation y45 and destination map23',
    (tester) async {
      final game = await open(tester, 25, 26, 45);
      final portal = LoreWorldManager.instance.findPortal(25, 26, 46)!;
      game.onPortalRequested!(portal, 26, 46);
      await tick(tester);
      expect(find.text(LoreFieldLogic.exitPrompt), findsOneWidget);
      await tester.tap(find.text(LoreFieldLogic.confirmNo));
      await tick(tester);
      expect([game.currentMapId, game.playerX, game.playerY], [25, 26, 45]);
      game.onPortalRequested!(portal, 26, 46);
      await tick(tester);
      await tester.tap(find.text(LoreFieldLogic.confirmYes));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tick(tester);
      expect([game.currentMapId, game.playerX, game.playerY], [23, 25, 45]);
      expect(find.byType(BattleViewportView), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'chamber entry resumes from speech to battle and loads map26 only after victory',
    (tester) async {
      final game = await open(tester, 25, 25, 28);
      final portal = LoreWorldManager.instance.findPortal(25, 25, 27)!;
      game.onPortalRequested!(portal, 25, 27);
      await tick(tester);
      await tester.tap(find.text(LoreFieldLogic.confirmYes));
      await tick(tester);
      expect(LoreDialogueManager.instance.partyEtc.read(1), 1);
      for (var frame = 0; frame < 10; frame++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tick(tester);
      expect(game.currentMapId, 25);
      expect(find.byType(ScriptSceneDialog), findsOneWidget);
      expect(find.byType(BattleViewportView), findsNothing);
      await acknowledge(tester);
      final battle = tester.widget<BattleViewportView>(
        find.byType(BattleViewportView),
      );
      expect(battle.enemies.map((e) => e.eNumber), [63, 63, 63, 63, 63, 72]);
      expect(battle.enemyFirst, isFalse);
      expect(game.currentMapId, 25);
      for (final enemy in battle.enemies) {
        enemy.isDead = true;
      }
      battle.onVictory(0);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tick(tester);
      for (var frame = 0; frame < 5; frame++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tick(tester);
      expect(
        [game.currentMapId, game.playerX, game.playerY, game.playerSpriteIndex],
        [26, 25, 15, 5],
      );
      for (var y = 16; y <= 19; y++) {
        for (var x = 24; x <= 26; x++) {
          expect(game.currentMap!.getTile(x, y), 16);
        }
      }
      expect(find.byType(BattleViewportView), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );
}

import 'support/source_audio_platform.dart';
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

/// LORESPEC.PAS `case 23` through the real screen: impostor scenes, retained
/// mirror enemies, duel escape/victory map writes and the y = 46 exit.
void main() {
  setUp(installSourceAudioPlatform);
  final party = [PartyMember.createPreset(1), PartyMember.createPreset(3)];

  Future<LoreGame> open(WidgetTester tester, int x, int y) async {
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
    final map = await LoreMapData.loadFromAsset('KEEP3', category: 'keep');
    await tester.pumpWidget(
      MaterialApp(
        home: MainGameScreen(
          initialSaveData: SaveData(
            slot: 1,
            slotName: '가짜 Necromancer',
            timestamp: DateTime.utc(1993),
            mapId: 23,
            mapTitle: 'KEEP3',
            playerX: x,
            playerY: y,
            gold: 100,
            food: 20,
            party: party,
            flags: const {},
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

  ScriptScene scene(WidgetTester tester) => tester
      .widget<ScriptSceneDialog>(find.byType(ScriptSceneDialog).last)
      .scene;

  BattleViewportView battle(WidgetTester tester) =>
      tester.widget<BattleViewportView>(find.byType(BattleViewportView));

  /// Intro and illusion scenes, up to the first mirror fight.
  Future<BattleViewportView> reachMirror(
    WidgetTester tester,
    LoreGame game,
  ) async {
    expect(game.onStepTaken!(), isTrue);
    await tick(tester);
    expect(scene(tester).title, 'Necromancer');
    expect(scene(tester).lines.first, ' 잘도 여기까지 찾아왔구나 ${party.first.name}.');
    expect(find.byType(BattleViewportView), findsNothing);
    await acknowledge(tester);
    expect(scene(tester).title, '환상');
    await acknowledge(tester);
    return battle(tester);
  }

  testWidgets(
    'impostor flow keeps mirror enemies on escape and writes the map before the last key',
    (tester) async {
      final game = await open(tester, 25, 26);
      expect(game.currentMap!.getTile(25, 26), 52);
      final first = await reachMirror(tester, game);
      expect(first.enemies.length, 6);
      expect(first.enemies.map((e) => e.name).take(2), [
        party[0].name,
        party[1].name,
      ]);
      expect(first.enemies.skip(2).map((e) => e.name), everyElement('Wraith'));
      expect(first.enemies.map((e) => e.eNumber), everyElement(1));
      expect(first.enemyFirst, isTrue);
      expect(LoreDialogueManager.instance.partyEtc.read(6), 1);

      first.enemies[0].hp = 7;
      first.enemies[2].isDead = true;
      first.onRunAway();
      await tick(tester);
      expect(LoreDialogueManager.instance.partyEtc.read(6), 2);
      expect(scene(tester).title, '환상');
      expect(find.byType(BattleViewportView), findsNothing);
      await acknowledge(tester);
      final retry = battle(tester);
      expect(identical(retry.enemies, first.enemies), isTrue);
      expect(retry.enemies[0].hp, 7);
      expect(retry.enemies[2].isDead, isTrue);
      expect(LoreDialogueManager.instance.partyEtc.read(6), 1);
      expect([game.playerX, game.playerY], [25, 26]);

      for (final enemy in retry.enemies) {
        enemy.isDead = true;
      }
      retry.onVictory(0);
      await tick(tester);
      expect(scene(tester).title, 'Necromancer');
      expect(scene(tester).lines.first, ' 환상에서 벗어나다니 대단한 의지력이군.');
      await acknowledge(tester);
      final duel = battle(tester);
      expect(duel.enemies.length, 1);
      expect(duel.enemies.single.name, 'Necromancer');
      expect(duel.enemies.single.eNumber, 1);
      expect(duel.enemyFirst, isTrue);
      expect(identical(duel.enemies, first.enemies), isFalse);

      duel.enemies.single.isDead = true;
      duel.onVictory(0);
      await tick(tester);
      expect(scene(tester).lines.first, ' 욱! 너의 힘은 대단하구나. 나는 너에게 졌다');
      expect(game.currentMap!.getTile(25, 26), 52);
      expect(game.currentMap!.getTile(29, 43), 44);
      await acknowledge(tester);
      expect(scene(tester).lines.first, ' 그는 숨이 끊어졌고 주위의 기둥도 그와 함께');
      expect(game.currentMap!.getTile(29, 43), 53);
      for (var y = 25; y <= 27; y++) {
        for (var x = 24; x <= 27; x++) {
          expect(game.currentMap!.getTile(x, y), 46, reason: '($x,$y)');
        }
      }
      await acknowledge(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ScriptSceneDialog), findsNothing);
      expect(find.byType(BattleViewportView), findsNothing);
      final flags = LoreDialogueManager.instance.getFlagsCopy();
      expect(flags['keep3NecromancerCleared'], isNot(true));
      expect([game.playerX, game.playerY], [25, 26]);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('duel escape moves the party to y + 1 without map writes', (
    tester,
  ) async {
    final game = await open(tester, 26, 26);
    final mirror = await reachMirror(tester, game);
    for (final enemy in mirror.enemies) {
      enemy.isDead = true;
    }
    mirror.onVictory(0);
    await tick(tester);
    await acknowledge(tester);
    battle(tester).onRunAway();
    await tick(tester);
    expect(LoreDialogueManager.instance.partyEtc.read(6), 2);
    expect([game.playerX, game.playerY], [26, 27]);
    expect(find.byType(ScriptSceneDialog), findsNothing);
    expect(find.byType(BattleViewportView), findsNothing);
    expect(game.currentMap!.getTile(26, 26), 52);
    expect(game.currentMap!.getTile(29, 43), 44);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'map 23 exit uses source confirmation, cancellation y45 and map 5',
    (tester) async {
      final game = await open(tester, 26, 45);
      final portal = LoreWorldManager.instance.findPortal(23, 26, 46)!;
      game.onPortalRequested!(portal, 26, 46);
      await tick(tester);
      expect(find.text(LoreFieldLogic.exitPrompt), findsOneWidget);
      await tester.tap(find.text(LoreFieldLogic.confirmNo));
      await tick(tester);
      expect([game.currentMapId, game.playerX, game.playerY], [23, 26, 45]);
      game.onPortalRequested!(portal, 26, 46);
      await tick(tester);
      await tester.tap(find.text(LoreFieldLogic.confirmYes));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tick(tester);
      expect([game.currentMapId, game.playerX, game.playerY], [5, 34, 15]);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );
}

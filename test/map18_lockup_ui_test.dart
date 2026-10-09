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

/// LORESPEC.PAS `case 18` (LOCKUP) through the real screen: Huge Dragon walk,
/// battle continuations, Minotaur etc[39] bit3 and the y = 95 exit.
void main() {
  setUp(installSourceAudioPlatform);
  final party = [PartyMember.createPreset(1), PartyMember.createPreset(3)];

  Future<LoreGame> open(
    WidgetTester tester,
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
    for (final channel in [
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers.global',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), (_) async => 1);
    }
    final map = await LoreMapData.loadFromAsset('DEN5', category: 'den');
    await tester.pumpWidget(
      MaterialApp(
        home: MainGameScreen(
          initialSaveData: SaveData(
            slot: 1,
            slotName: 'LOCKUP',
            timestamp: DateTime.utc(1993),
            mapId: 18,
            mapTitle: 'DEN5',
            playerX: x,
            playerY: y,
            gold: 100,
            food: 20,
            party: party,
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

  Future<void> acknowledge(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('script-scene-continue')).last);
    await tick(tester);
  }

  ScriptScene scene(WidgetTester tester) => tester
      .widget<ScriptSceneDialog>(find.byType(ScriptSceneDialog).last)
      .scene;

  BattleViewportView battle(WidgetTester tester) =>
      tester.widget<BattleViewportView>(find.byType(BattleViewportView));

  testWidgets('Huge Dragon: walk to (37,13), battle, victory sets etc[15] = 4', (
    tester,
  ) async {
    final game = await open(tester, 31, 10);
    expect(game.onStepTaken!(), isTrue);
    await tick(tester);
    // `message` has no key wait; the PressAnyKey after the walk shows a scene.
    expect(scene(tester).title, 'Huge Dragon');
    expect([game.playerX, game.playerY], [37, 13]);
    await acknowledge(tester);
    final fight = battle(tester);
    expect(fight.enemies.length, 7);
    expect(fight.enemies.first.name, 'Huge Dragon');
    expect(fight.enemies[1].name, "Dragon's tail");
    expect(fight.enemyFirst, isTrue);
    for (final enemy in fight.enemies) {
      enemy.isDead = true;
    }
    fight.onVictory(0);
    await tick(tester);
    expect(scene(tester).lines.first, '당신들은 Huge Dragon을 물리쳤다.');
    await acknowledge(tester);
    expect(LoreDialogueManager.instance.partyEtc.read(15), 4);
    expect([game.playerX, game.playerY], [37, 13]);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Huge Dragon escape moves to (25,94) and keeps etc[15]', (
    tester,
  ) async {
    final game = await open(tester, 31, 10);
    expect(game.onStepTaken!(), isTrue);
    await tick(tester);
    await acknowledge(tester);
    battle(tester).onRunAway();
    await tick(tester);
    expect([game.playerX, game.playerY], [25, 94]);
    expect(LoreDialogueManager.instance.partyEtc.read(15), 0);
    expect(find.byType(BattleViewportView), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Minotaur escape still sets etc[39] bit3', (tester) async {
    final game = await open(tester, 22, 41);
    // (22,41) writes map[21,41] := 52, making the guardian cell special.
    expect(game.onStepTaken!(), isTrue);
    await tick(tester);
    expect(game.currentMap!.getTile(22, 41), 44);
    expect(game.currentMap!.getTile(21, 41), 52);
    game.playerX = 21;
    expect(game.onStepTaken!(), isTrue);
    await tick(tester);
    expect(scene(tester).lines.single, '미로속에서 소를 닮은 괴물이 나타났다');
    await acknowledge(tester);
    expect(battle(tester).enemies.single.eNumber, isNotNull);
    battle(tester).onRunAway();
    await tick(tester);
    expect(LoreDialogueManager.instance.partyEtc.read(39) & 4, 4);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'map 18 exit uses source confirmation, cancellation y94 and map 3',
    (tester) async {
      final game = await open(tester, 24, 94);
      final portal = LoreWorldManager.instance.findPortal(18, 24, 95)!;
      game.onPortalRequested!(portal, 24, 95);
      await tick(tester);
      expect(find.text(LoreFieldLogic.exitPrompt), findsOneWidget);
      await tester.tap(find.text(LoreFieldLogic.confirmNo));
      await tick(tester);
      expect([game.currentMapId, game.playerX, game.playerY], [18, 24, 94]);
      game.onPortalRequested!(portal, 24, 95);
      await tick(tester);
      await tester.tap(find.text(LoreFieldLogic.confirmYes));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tick(tester);
      expect([game.currentMapId, game.playerX, game.playerY], [3, 96, 43]);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );
}

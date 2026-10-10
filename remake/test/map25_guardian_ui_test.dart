import 'support/source_audio_platform.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/services/save_manager.dart';
import 'package:lore/widgets/battle_viewport_view.dart';
import 'package:lore/widgets/script_scene_dialog.dart';
import 'package:lore/widgets/message_log_view.dart';
import 'package:lore/widgets/lore_select_view.dart';

void main() {
  setUp(installSourceAudioPlatform);
  testWidgets(
    'LORESPEC.PAS guardian UI resumes through intro, battle, guide and promotion',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        LoreDialogueManager.instance.loadFlags({});
        LoreScriptEngine.instance.resetForTest();
      });
      for (final channel in [
        'xyz.luan/audioplayers',
        'xyz.luan/audioplayers.global',
      ]) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(MethodChannel(channel), (_) async => 1);
      }
      final map = await LoreMapData.loadFromAsset('K_DEN2', category: 'den');
      map.setTile(25, 43, 0);
      final party = [PartyMember.createPreset(1), PartyMember.createPreset(3)];
      await tester.pumpWidget(
        MaterialApp(
          home: MainGameScreen(
            sourceReplayBattle: true,
            initialSaveData: SaveData(
              slot: 1,
              slotName: '수호자 직전',
              timestamp: DateTime.utc(1993),
              mapId: 25,
              mapTitle: 'CASTLE KEEP',
              playerX: 25,
              playerY: 43,
              gold: 100,
              food: 20,
              party: party,
              flags: const {'etc1': 0},
              mapTiles: map.tileSnapshot(),
            ),
          ),
        ),
      );
      final gameFinder = find.byType(GameWidget<LoreGame>);
      final game = tester.widget<GameWidget<LoreGame>>(gameFinder).game!;
      final state = tester.state<GameWidgetState<LoreGame>>(gameFinder);
      await tester.runAsync(() => state.loaderFuture);
      await tester.pump();
      expect(game.currentMap, isNotNull);
      expect(game.onStepTaken!(), isTrue);
      await tester.pump();
      expect(find.byType(ScriptSceneDialog), findsNothing);
      expect(game.specialArrivalDraws.last.index, 23);
      expect(LoreDialogueManager.instance.partyEtc.read(1), 1);
      final position = [game.playerX, game.playerY];
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump(const Duration(seconds: 2));
      expect([game.playerX, game.playerY], position);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.byType(ScriptSceneDialog), findsOneWidget);
      expect(LoreDialogueManager.instance.partyEtc.read(1), 1);
      expect(find.byType(BattleViewportView), findsNothing);
      expect(game.partyProvider!().first.playerClass, PlayerClass.knight);

      await tester.tap(find.byKey(const ValueKey('script-scene-continue')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      final battle = tester.widget<BattleViewportView>(
        find.byType(BattleViewportView),
      );
      expect(game.specialArrivalDraws, isEmpty);
      expect(battle.enemies.map((e) => e.eNumber).toList(), [
        66,
        66,
        66,
        66,
        71,
      ]);
      expect(battle.enemyFirst, isTrue);
      // Supply the terminal battle result; combat math has its own source tests.
      for (final enemy in battle.enemies) {
        enemy.isDead = true;
      }
      battle.partyMembers.first.name = '영입한 대원';
      battle.onVictory(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(
        tester
            .widget<ScriptSceneDialog>(find.byType(ScriptSceneDialog).last)
            .scene
            .title,
        '금속 수호자 격파',
      );
      for (var x = 24; x <= 27; x++) {
        expect(game.currentMap!.getTile(x, 43), 41);
      }
      expect(game.partyProvider!().first.playerClass, PlayerClass.knight);

      await tester.tap(find.byKey(const ValueKey('script-scene-continue')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      final guide = tester.widget<ScriptSceneDialog>(
        find.byType(ScriptSceneDialog).last,
      );
      expect(guide.actors.map((e) => e.eNumber).toList(), [68, 67]);
      expect(guide.scene.lines.first, ' 매우 수고하시는군요. 영입한 대원');
      expect(
        find.descendant(
          of: find.byType(ScriptSceneDialog).last,
          matching: find.byType(LoreMessageDialog),
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<MessageLogView>(find.byType(MessageLogView)).logs,
        isNot(contains(guide.scene.lines.first)),
      );
      expect(game.partyProvider!().first.playerClass, PlayerClass.knight);
      await tester.tap(
        find.byKey(const ValueKey('script-scene-continue')).last,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      final promoted = game.partyProvider!();
      expect(promoted.length, 6);
      final named = promoted.where((m) => m.name.isNotEmpty).toList();
      expect(named.length, 2);
      expect(
        named.map((m) => m.playerClass),
        everyElement(PlayerClass.demigod),
      );
      // LORESPEC.PAS:2063-2064 only promotes named player[1..6]. Load now
      // retains the four reserved records instead of shortening the array.
      expect(
        promoted.where((m) => m.name.isEmpty).map((m) => m.toJson()),
        everyElement(PartyMember.blank().toJson()),
      );
      expect(find.byType(BattleViewportView), findsNothing);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ScriptSceneDialog), findsNothing);
      expect(
        LoreDialogueManager.instance
            .getFlagsCopy()['keep3MetalGuardianCleared'],
        isNot(true),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );
}

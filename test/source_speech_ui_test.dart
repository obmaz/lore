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
import 'package:lore/logic/lore_view_procedures.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/services/save_manager.dart';
import 'package:lore/services/audio_manager.dart';
import 'package:lore/widgets/battle_viewport_view.dart';
import 'package:lore/widgets/dialogue_history_view.dart';
import 'package:lore/widgets/lore_select_view.dart';
import 'package:lore/widgets/message_log_view.dart';

/// LORESPEC.PAS:496-519 and LOREENT.PAS:289-311 input boundaries.
void main() {
  Future<void> tick(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<LoreGame> open(
    WidgetTester tester,
    int id,
    int x,
    int y, {
    List<PartyMember>? party,
    Size size = const Size(390, 480),
  }) async {
    tester.view.physicalSize = size;
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
    final info = LoreWorldManager.mapRegistry[id]!;
    final map = await LoreMapData.loadFromAsset(
      info.fileName,
      category: info.category.name,
    );
    map.setTile(x, y, 0);
    await tester.pumpWidget(
      MaterialApp(
        home: MainGameScreen(
          initialSaveData: SaveData(
            slot: 1,
            slotName: 'Source dialogue',
            timestamp: DateTime.utc(1993),
            mapId: id,
            mapTitle: info.title,
            playerX: x,
            playerY: y,
            gold: 100,
            food: 20,
            party: party ?? [PartyMember.createPreset(1)],
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
    await tick(tester);
    return game;
  }

  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    testWidgets('field commands stay outside the map at $size', (tester) async {
      await open(tester, 6, 51, 31, size: size);
      final map = tester.getRect(find.byType(GameWidget<LoreGame>));
      final menu = tester.getRect(find.byIcon(Icons.menu));
      if (size.width > size.height) {
        expect(menu.left, greaterThanOrEqualTo(map.right));
      } else {
        expect(menu.top, greaterThanOrEqualTo(map.bottom));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'source see-through suspends only SoundOn and restores it on acknowledgement',
    (tester) async {
      final audio = AudioManager.instance;
      audio.sourceSoundEnabled = false;
      addTearDown(() => audio.sourceSoundEnabled = true);
      final game = await open(
        tester,
        6,
        51,
        31,
        party: [
          PartyMember.createPreset(3)
            ..playerClass = PlayerClass.esper
            ..esp = 100,
        ],
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
      await tick(tester);
      await tester.tap(find.byKey(const ValueKey('lore-select-1')));
      await tick(tester);
      audio.sourceSoundEnabled =
          true; // initial source preference for this cast.
      await tester.tap(find.byKey(const ValueKey('lore-select-1')));
      await tick(tester);
      expect(game.seeThroughSpecial, isTrue);
      expect(audio.sourceSoundEnabled, isFalse);
      await tester.tap(find.byKey(const ValueKey('lore-press-any-key')));
      await tick(tester);
      expect(game.seeThroughSpecial, isFalse);
      expect(audio.sourceSoundEnabled, isTrue);
      expect(game.partyProvider!().first.esp, 90);
    },
  );

  testWidgets(
    'field character pages and QuickView keep their source Print colors',
    (tester) async {
      final hero = PartyMember.createPreset(1);
      final game = await open(tester, 6, 51, 31, party: [hero]);
      // Town tile 0 dispatches an entrance; use the source floor so the
      // post-menu dispatch stays in the field instead of opening a portal.
      game.currentMap!.setTile(51, 31, 42);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tick(tester);
      await tester.tap(find.byKey(const ValueKey('lore-select-1')));
      await tick(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tick(tester);
      var log = tester.widget<MessageLogView>(find.byType(MessageLogView));
      final page = LoreViewProcedures.characterPage2(hero);
      for (final (color, text) in page) {
        final index = log.logs.indexOf(text);
        expect(index, greaterThanOrEqualTo(0));
        expect(log.colors[index], color, reason: text);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
      await tick(tester);
      log = tester.widget<MessageLogView>(find.byType(MessageLogView));
      final quick = LoreViewProcedures.quickView([hero]);
      for (final (color, text) in quick) {
        final index = log.logs.indexOf(text);
        expect(index, greaterThanOrEqualTo(0), reason: 'next Q command: $text');
        expect(log.colors[index], color, reason: text);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'LORESPEC spear has two source pages before ChooseWhom, kept in history',
    (tester) async {
      final game = await open(tester, 11, 25, 44);
      game.tryMove(0, 0);
      await tick(tester);
      expect(find.text('당신은 어떤 창을 발견했다.'), findsOneWidget);
      expect(find.byType(LoreMessageDialog), findsOneWidget);
      expect(find.byType(LoreSelectView), findsNothing);
      await tester.tap(find.byKey(const ValueKey('lore-press-any-key')));
      await tick(tester);
      expect(find.text('그 창의 손잡이에 쓰인 문구를 따르면..'), findsOneWidget);
      expect(find.text('   이것으로 전에 Sphinx 를 무찌르다'), findsOneWidget);
      expect(find.byType(LoreSelectView), findsNothing);
      await tester.tap(find.byKey(const ValueKey('lore-press-any-key')));
      await tick(tester);
      // The prompt stays above the source Select; no third page/key wait.
      expect(find.text('누가 오이디푸스의 창을 다루겠습니까 ?'), findsOneWidget);
      expect(find.byType(LoreSelectView), findsOneWidget);
      expect(find.byKey(const ValueKey('lore-press-any-key')), findsNothing);
      expect(game.partyProvider!().first.weapon, isNot(3));
      await tester.tap(find.byKey(const ValueKey('dialog-cancel')));
      await tick(tester);
      expect(game.partyProvider!().first.weapon, isNot(3));
      expect(LoreDialogueManager.instance.partyEtc.read(33) & 128, 0);
      expect(tester.widget<MessageLogView>(find.byType(MessageLogView)).logs, [
        LoreFieldLogic.asYouWish,
      ]);
      await tester.tap(find.byKey(const ValueKey('panel-tab-history')).first);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final history = tester
          .widget<DialogueHistoryView>(find.byType(DialogueHistoryView))
          .history;
      expect(history.blocks.map((b) => b.first), [
        '당신은 어떤 창을 발견했다.',
        '그 창의 손잡이에 쓰인 문구를 따르면..',
        '누가 오이디푸스의 창을 다루겠습니까 ?',
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'LOREENT strike follows first confirmation and battle follows second',
    (tester) async {
      final party = [
        for (var i = 1; i <= 6; i++) PartyMember.createPreset(i <= 5 ? i : 1),
      ];
      party.last.name = 'Draconian';
      final game = await open(tester, 23, 25, 27, party: party);
      const portal = PortalInfo(
        targetMapId: 25,
        targetX: 25,
        targetY: 45,
        name: 'DUNGEON OF EVIL',
        scriptId: 'portal-23-25-dungeon',
      );
      game.onPortalRequested!(portal, 25, 27);
      await tick(tester);
      await tester.tap(find.text(LoreFieldLogic.confirmYes));
      await tick(tester);
      expect(find.text(' 이 동굴에 들어 가겠다고?'), findsOneWidget);
      expect(game.partyProvider!().last.dead, 0);
      expect(find.byType(BattleViewportView), findsNothing);
      await tester.tap(find.byKey(const ValueKey('lore-press-any-key')));
      await tick(tester);
      expect(find.text(' ArchiDraconian은 마지막에 있는 Draconian'), findsOneWidget);
      expect(game.partyProvider!().last.dead, 30000);
      expect(find.byType(BattleViewportView), findsNothing);
      await tester.tap(find.byKey(const ValueKey('lore-press-any-key')));
      await tick(tester);
      final battle = tester.widget<BattleViewportView>(
        find.byType(BattleViewportView),
      );
      expect(battle.enemyFirst, isTrue);
      expect(battle.enemies.length, 7);
      expect(battle.enemies[2].eNumber, 70);
      expect(
        tester.widget<MessageLogView>(find.byType(MessageLogView)).logs,
        isNot(contains(' 이 동굴에 들어 가겠다고?')),
      );
      expect(game.currentMapId, 23);
      expect(tester.takeException(), isNull);
    },
  );
}

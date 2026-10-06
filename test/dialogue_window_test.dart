import 'dart:convert';
import 'dart:io';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/game/lore_world_manager.dart';
import 'package:lore/logic/lore_dialogue_history.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/services/save_manager.dart';
import 'package:lore/widgets/dialogue_history_view.dart';
import 'package:lore/widgets/game_screen_layout.dart';
import 'package:lore/widgets/message_log_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// LORETALK.PAS `Print` lines + `PressAnyKey` as one dialogue window, and the
/// `이전 대화` tab that keeps them afterwards.
void main() {
  test('history keeps the lines of each speech unchanged and bounded', () {
    final history = LoreDialogueHistory();
    var notified = 0;
    history.addListener(() => notified++);
    history.add([' 안녕하시오.', '이었던 사람이오.']);
    history.add([]);
    history.add(['talk']);
    expect(history.blocks, [
      [' 안녕하시오.', '이었던 사람이오.'],
      ['talk'],
    ]);
    expect(notified, 2);
    for (var i = 0; i < LoreDialogueHistory.maxBlocks + 5; i++) {
      history.add(['$i']);
    }
    expect(history.blocks.length, LoreDialogueHistory.maxBlocks);
    expect(history.blocks.last, ['${LoreDialogueHistory.maxBlocks + 4}']);
  });

  test('history keeps colors and text bounded together, and clears both', () {
    final history = LoreDialogueHistory();
    for (var i = 0; i < LoreDialogueHistory.maxBlocks + 2; i++) {
      history.addColored([(13, '$i')]);
    }
    expect(history.coloredBlocks.length, LoreDialogueHistory.maxBlocks);
    expect(history.coloredBlocks.first, [(13, '2')]);
    expect(history.blocks.first, ['2']);
    history.clear();
    expect(history.blocks, isEmpty);
    expect(history.coloredBlocks, isEmpty);
  });

  testWidgets('the history view stacks each speech as one block', (
    tester,
  ) async {
    final history = LoreDialogueHistory()
      ..add(['첫째 줄', '둘째 줄'])
      ..add(['다음 대화']);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DialogueHistoryView(history: history)),
      ),
    );
    expect(find.text('첫째 줄'), findsOneWidget);
    expect(find.text('둘째 줄'), findsOneWidget);
    expect(find.text('다음 대화'), findsOneWidget);
    // No bullets, no highlight on the newest block.
    expect(find.textContaining('▶'), findsNothing);
    expect(find.textContaining('·'), findsNothing);
    history.add(['새 대화']);
    await tester.pump();
    expect(find.text('새 대화'), findsOneWidget);
  });

  Future<LoreGame> openTown(
    WidgetTester tester,
    Size size, {
    required int x,
    required int y,
  }) async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(() {
      LoreDialogueManager.instance.loadFlags({});
      LoreScriptEngine.instance.resetForTest();
    });
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    for (final channel in [
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers.global',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), (_) async => 1);
    }
    // `main()` loads the data before `runApp`.
    await tester.runAsync(() async {
      await LoreWorldManager.instance.loadData();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: MainGameScreen(
          initialSaveData: SaveData(
            slot: 1,
            slotName: SaveManager.slotNames.first,
            timestamp: DateTime.utc(1993),
            mapId: 6,
            mapTitle: 'TOWN 1',
            playerX: x,
            playerY: y,
            gold: 100,
            food: 20,
            party: [PartyMember.createPreset(1)],
            flags: const {},
          ),
        ),
      ),
    );
    final finder = find.byType(GameWidget<LoreGame>);
    final game = tester.widget<GameWidget<LoreGame>>(finder).game!;
    await tester.runAsync(
      () => tester.state<GameWidgetState<LoreGame>>(finder).loaderFuture,
    );
    await tester.pump(const Duration(milliseconds: 300));
    return game;
  }

  for (final size in [const Size(1280, 720), const Size(390, 844)]) {
    testWidgets('an NPC speech is one window, then lives in 이전 대화 ($size)', (
      tester,
    ) async {
      final game = await openTown(tester, size, x: 63, y: 9);
      game.tryMove(0, 1); // the NPC at (63, 10)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      const first = ' 안녕하시오. 나는 한때 이 곳의 유명한 도둑';
      const last = '운을 빌겠소.';
      // One window with every line; nothing reaches the message log.
      expect(find.byKey(const ValueKey('lore-press-any-key')), findsOneWidget);
      expect(find.text(first), findsOneWidget);
      expect(find.text(last), findsOneWidget);
      expect(
        tester.widget<MessageLogView>(find.byType(MessageLogView)).logs,
        isEmpty,
      );
      await tester.tap(find.byKey(const ValueKey('lore-press-any-key')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('lore-press-any-key')), findsNothing);
      // The log stays free of speech; the history tab has it.
      expect(
        tester.widget<MessageLogView>(find.byType(MessageLogView)).logs,
        isEmpty,
      );
      await tester.tap(find.byKey(const ValueKey('panel-tab-history')).first);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text(first), findsOneWidget);
      expect(find.text(last), findsOneWidget);
      expect(find.text(GameScreenLayout.historyLabel), findsWidgets);
    });
  }

  testWidgets('the hero name of LORETALK `player[1].name` is filled in', (
    tester,
  ) async {
    final game = await openTown(tester, const Size(390, 844), x: 25, y: 50);
    final hero = PartyMember.createPreset(1).name;
    game.tryMove(-1, 0); // the NPC at (24, 50): ' 힘내게, '+player[1].name
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(' 힘내게, $hero'), findsOneWidget);
    expect(find.textContaining('{hero}'), findsNothing);
  });

  testWidgets('the tavern greets with the sign line and ReturnSex(1)', (
    tester,
  ) async {
    final game = await openTown(tester, const Size(390, 844), x: 13, y: 28);
    game.tryMove(0, -1); // the barkeeper at (13, 27)
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // `Print(7,' 어서 오십시오. ...')` then one `talk` of `random(2)`.
    expect(find.text(' 어서 오십시오. 여기는 LORE 주점입니다.'), findsOneWidget);
    expect(find.textContaining('{sex}'), findsNothing);
    final greeting = find.textContaining(' 거기 ');
    final drinks = find.text(' 위스키에서 칵테일까지 마음껏 선택하십시오.');
    expect(
      greeting.evaluate().length + drinks.evaluate().length,
      1,
      reason: 'exactly one of the two talk lines',
    );
    if (greeting.evaluate().isNotEmpty) {
      final sex = PartyMember.createPreset(1).sex == Gender.female
          ? '여성'
          : '남성';
      expect(find.text(' 거기 $sex분 어서 오십시오.'), findsOneWidget);
    }
  });

  testWidgets('a speech with talk/PressAnyKey inside is shown page by page', (
    tester,
  ) async {
    // LORETALK.PAS:105 at(63,76): two Prints + talk, 12 Prints + talk(''),
    // 4 Prints + PressAnyKey: three windows, each cleared by a key.
    final game = await openTown(tester, const Size(390, 844), x: 63, y: 75);
    game.tryMove(0, 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    const page1 = ' 당신이  한 유골 앞에 섰을때  이상한 느낌과';
    const page2 = ' 안녕하시오. 대담한 용사여.';
    const page3 = ' 아참,  그리고 내가 죽기전에 여기에 뭔가를';
    expect(find.text(page1), findsOneWidget);
    expect(find.text(page2), findsNothing);
    await tester.tap(find.byKey(const ValueKey('lore-press-any-key')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(page1), findsNothing);
    expect(find.text(page2), findsOneWidget);
    expect(find.text(page3), findsNothing);
    await tester.tap(find.byKey(const ValueKey('lore-press-any-key')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(page3), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lore-press-any-key')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('lore-press-any-key')), findsNothing);
    // History keeps the three pages as three blocks.
    final history = tester.widget<DialogueHistoryView>(
      find.byType(DialogueHistoryView, skipOffstage: false),
    );
    expect(history.history.blocks.length, 3);
    expect(history.history.blocks.first.first, page1);
  });

  testWidgets(
    'message panel retains source QuickView output outside speech popups',
    (tester) async {
      final game = await openTown(tester, const Size(390, 844), x: 40, y: 16);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final messages = tester.widget<MessageLogView>(
        find.byType(MessageLogView),
      );
      expect(
        messages.logs.join('\n'),
        contains(game.partyProvider!().first.name),
      );
      expect(find.byKey(const ValueKey('lore-press-any-key')), findsNothing);
      expect(find.text('메시지'), findsOneWidget);
    },
  );

  testWidgets(
    'Polaris slot cancellation preserves state; acceptance completes source arm',
    (tester) async {
      final game = await openTown(tester, const Size(390, 844), x: 40, y: 16);
      await tester.runAsync(() => game.loadMapById(7, startX: 37, startY: 42));
      final dialogue = LoreDialogueManager.instance;
      dialogue.partyEtc[13] = 1;
      final party = game.partyProvider!();
      final before = party.map((member) => member.toJson()).toList();
      final npcTile = game.currentMap!.getTile(37, 41);
      Future<void> settle() async {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      Future<void> offer() async {
        game.tryMove(0, -1);
        await settle();
        expect(find.text('나는 당신의 제안을 받아 들이겠소'), findsOneWidget);
      }

      await offer();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle();
      expect(party.map((member) => member.toJson()).toList(), before);
      expect(game.currentMap!.getTile(37, 41), npcTile);
      await offer();
      await tester.tap(find.text('나는 당신의 제안을 받아 들이겠소'));
      await settle();
      await tester.sendKeyEvent(
        LogicalKeyboardKey.escape,
      ); // ReturnJoinMember = 1.
      await settle();
      expect(party.map((member) => member.toJson()).toList(), before);
      expect(game.currentMap!.getTile(37, 41), npcTile);
      expect(dialogue.polarisJoined, isFalse);
      await offer();
      await tester.tap(find.text('나는 당신의 제안을 받아 들이겠소'));
      await settle();
      await tester.tap(find.text('보조 일원으로 둠'));
      await settle();
      final polaris = game.partyProvider!()[5];
      expect(polaris.name, 'Polaris');
      expect(polaris.playerClass, PlayerClass.warrior);
      expect(polaris.magicLevel, 3);
      expect((polaris.weapon, polaris.shield, polaris.armor), (4, 1, 1));
      expect(
        (polaris.weaPower, polaris.shiPower, polaris.armPower, polaris.ac),
        (10, 1, 2, 3),
      );
      expect(game.currentMap!.getTile(37, 41), 44);
      expect(dialogue.partyEtc.read(13), 1);
      expect(dialogue.polarisJoined, isTrue);
      await tester.runAsync(() => game.loadMapById(7, startX: 37, startY: 42));
      await offer(); // Source has no polarisJoined guard on a restored NPC tile.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle();
    },
  );

  for (final stage in [2, 4]) {
    testWidgets(
      'Water lord stage $stage rewards before wait and advances only on acknowledgement',
      (tester) async {
        final game = await openTown(tester, const Size(390, 844), x: 40, y: 16);
        await tester.runAsync(
          () => game.loadMapById(10, startX: 25, startY: 19),
        );
        final etc = LoreDialogueManager.instance.partyEtc;
        etc[15] = stage;
        final hero = game.partyProvider!().first..experience = 100;
        final reward = stage == 2 ? 150000 : 300000;
        game.tryMove(0, -1);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('[ EXP + $reward ]'), findsOneWidget);
        expect(hero.experience, 100 + reward);
        expect(etc.read(15), stage);
        final position = (game.playerX, game.playerY);
        // A direction key acknowledges PressAnyKey without moving the party.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect((game.playerX, game.playerY), position);
        expect(etc.read(15), stage + 1);
        expect(hero.experience, 100 + reward);
        // Repeat audience reaches the next stage; it cannot award EXP again.
        game.tryMove(0, -1);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('[ EXP + $reward ]'), findsNothing);
        expect(hero.experience, 100 + reward);
      },
    );
  }

  testWidgets(
    'Lore Hunter preserves raw bits; Escape and slot cancel differ from refusal',
    (tester) async {
      final game = await openTown(tester, const Size(390, 844), x: 40, y: 16);
      await tester.runAsync(() => game.loadMapById(10, startX: 40, startY: 57));
      final dialogue = LoreDialogueManager.instance;
      dialogue.partyEtc[38] = 0xa9;
      dialogue.loreHunterJoined = true;
      final npcTile = game.currentMap!.getTile(40, 56);
      final before = game.partyProvider!()
          .map((member) => member.toJson())
          .toList();
      Future<void> settle() async {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      Future<void> offer() async {
        game.tryMove(0, -1);
        await settle();
        expect(find.text('우리도 그러기를 바라오'), findsOneWidget);
      }

      List<String> logs() => List.of(
        tester.widget<MessageLogView>(find.byType(MessageLogView)).logs,
      );
      final originalLogs = logs();
      await offer();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle();
      expect(logs(), originalLogs); // k=0: exit without asyouwish.
      expect(game.currentMap!.getTile(40, 56), npcTile);
      await offer();
      await tester.tap(find.text('몸이 완전히 회복될때까지 기다리시오'));
      await settle();
      expect(logs().last, '당신이 바란다면 ...'); // only k=2 prints it.
      final refusedLogs = logs();
      await offer();
      await tester.tap(find.text('우리도 그러기를 바라오'));
      await settle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle();
      expect(
        game.partyProvider!().map((member) => member.toJson()).toList(),
        before,
      );
      expect(dialogue.partyEtc.read(38), 0xa9);
      expect(game.currentMap!.getTile(40, 56), npcTile);
      expect(logs(), refusedLogs);
      dialogue.partyEtc[38] = 0xa1;
      await offer();
      await tester.tap(find.text('우리도 그러기를 바라오'));
      await settle();
      await tester.tap(find.text('보조 일원으로 둠'));
      await settle();
      final fixture = jsonDecode(
        File('test/fixtures/dos_lorehunter_reentry.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final hunter = game.partyProvider!()[5];
      expect(hunter.toJson(), fixture['observed']['slot6']);
      expect(hunter.name, 'Lore Hunter');
      expect(hunter.playerClass, PlayerClass.hunter);
      expect((hunter.weapon, hunter.shield, hunter.armor), (5, 2, 1));
      expect(
        (hunter.weaPower, hunter.shiPower, hunter.armPower, hunter.ac),
        (15, 2, 2, 4),
      );
      expect(dialogue.partyEtc.read(38), 0xa9);
      expect(game.currentMap!.getTile(40, 56), 44);
      final saved = dialogue.getSaveFlags();
      dialogue.loadFlags({...saved, 'loreHunterJoined': false});
      expect(dialogue.partyEtc.read(38), 0xa9);
      await tester.runAsync(() => game.loadMapById(10, startX: 40, startY: 57));
      game.applyEntrancePostLoadTiles(
        fromMap: 3,
        partyNames: const {},
        flags: const {},
        questSteps: const {},
        sourceEtc: dialogue.partyEtc.snapshot(),
      );
      expect(game.currentMap!.getTile(40, 56), 44);
      game.tryMove(0, -1);
      await settle();
      expect(find.text('우리도 그러기를 바라오'), findsNothing);
    },
  );

  testWidgets(
    'Mad Joe: saved map stays empty, fresh map restores repeat recruitment',
    (tester) async {
      final fixture = jsonDecode(
        File('test/fixtures/dos_madjoe_reentry.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      var game = await openTown(tester, const Size(390, 844), x: 40, y: 16);
      final etc = LoreDialogueManager.instance.partyEtc;
      etc[50] = 2; // The DOS fixture starts after a previous recruitment.
      final party = game.partyProvider!();
      while (party.length < 6) {
        party.add(PartyMember.blank());
      }
      party[5] = PartyMember.createPreset(1)..name = 'SlotSix';
      game.tryMove(0, -1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('그렇다면 당신을 받아들이지요'), findsOneWidget);
      await tester.tap(find.text('그렇다면 당신을 받아들이지요'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(game.partyProvider!()[5].toJson(), fixture['observed']['slot6']);
      expect(etc.read(50), fixture['observed']['etc50']);
      expect(game.currentMap!.getTile(40, 15), 47);
      game.tryMove(0, -1); // tile 47 no longer calls talkmode in this map.
      await tester.pump();
      expect(find.text('그렇다면 당신을 받아들이지요'), findsNothing);

      final save = SaveData(
        slot: 1,
        slotName: SaveManager.slotNames.first,
        timestamp: DateTime.utc(1993),
        mapId: 6,
        mapTitle: 'CASTLE LORE',
        playerX: 40,
        playerY: 16,
        gold: 100,
        food: 20,
        party: List.of(game.partyProvider!()),
        flags: LoreDialogueManager.instance.getSaveFlags(),
        etc: etc.fieldCounters(),
        mapTiles: game.currentMap!.tileSnapshot(),
      );
      expect(
        await tester.runAsync(() => SaveManager.instance.saveGame(save)),
        isTrue,
      );
      final restored = await tester.runAsync(
        () => SaveManager.instance.loadGame(1),
      );
      expect(restored, isNotNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(home: MainGameScreen(initialSaveData: restored)),
      );
      final finder = find.byType(GameWidget<LoreGame>);
      game = tester.widget<GameWidget<LoreGame>>(finder).game!;
      await tester.runAsync(
        () => tester.state<GameWidgetState<LoreGame>>(finder).loaderFuture,
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(game.currentMap!.getTile(40, 15), 47);
      expect(LoreDialogueManager.instance.partyEtc.read(50), 2);
      expect(game.partyProvider!()[5].toJson(), fixture['observed']['slot6']);

      await tester.runAsync(() => game.loadMapById(1));
      await tester.runAsync(() => game.loadMapById(6, startX: 40, startY: 16));
      expect(game.currentMap!.getTile(40, 15), isNot(47));
      game.partyProvider!()[5] = PartyMember.createPreset(1)
        ..name = 'Replacement';
      game.tryMove(0, -1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('그렇다면 당신을 받아들이지요'), findsOneWidget);
      await tester.tap(find.text('그렇다면 당신을 받아들이지요'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(game.partyProvider!()[5].toJson(), fixture['observed']['slot6']);
      expect(game.currentMap!.getTile(40, 15), 47);
      expect(LoreDialogueManager.instance.partyEtc.read(50), 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a speech that ends in a Select keeps its lines above the menu', (
    tester,
  ) async {
    // LORETALK.PAS:191-197: two Prints, `m[0] := ''`, `select(.., FALSE, TRUE)`
    // (the lines stay), then `asyouwish` = message(7, ..) without a key wait.
    final game = await openTown(tester, const Size(390, 844), x: 40, y: 16);
    game.tryMove(0, -1); // Mad Joe at (40, 15)
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    const first = ' 히히히... 위대한 용사님. 낄낄낄.. 내가 당';
    const second = '신들의 일행에 끼이면 안될까요 ? 우히히히..';
    expect(find.byKey(const ValueKey('lore-press-any-key')), findsNothing);
    expect(find.text(first), findsOneWidget);
    expect(find.text(second), findsOneWidget);
    expect(find.text('그렇다면 당신을 받아들이지요'), findsOneWidget);
    expect(find.text('그의 제안을 받아들이시겠습니까 ?'), findsNothing);
    expect(find.text('어떻게 하시겠습니까 ?'), findsNothing);
    // Refuse: `asyouwish` is one log line, no PressAnyKey window.
    await tester.tap(find.text('당신은 이곳에 그냥 있는게 낫겠소'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('lore-press-any-key')), findsNothing);
    expect(find.text('당신이 바란다면 ...'), findsWidgets);
    final logs = tester.widget<MessageLogView>(find.byType(MessageLogView));
    expect(logs.logs, ['당신이 바란다면 ...']);
    final history = tester.widget<DialogueHistoryView>(
      find.byType(DialogueHistoryView, skipOffstage: false),
    );
    expect(history.history.blocks, [
      [first, second],
    ]);
  });
}

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
import 'package:lore/logic/lore_random.dart';
import 'package:lore/logic/lore_field_logic.dart';
import 'package:lore/theme/retro_theme.dart';
import 'package:lore/widgets/message_log_view.dart';
import 'package:lore/widgets/battle_viewport_view.dart';
import 'package:lore/widgets/encounter_viewport_view.dart';
import 'package:lore/logic/lore_menu_text.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/services/save_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// LOREENT.PAS:37-43, LORESUB.PAS:986-1024 and LOREMAIN.PAS sequential position blocks.
/// LORESPEC.PAS:826-832, LOREMAIN.PAS:205, LOREBATT.PAS:1147-1155, LOREMENU.PAS:869-1022.
/// Actual native victory save -> recovery -> MENACE admission, without suppressing encounters.
void main() {
  final fixture = jsonDecode(
    File('test/fixtures/dos_menace_entry.json').readAsStringSync(),
  );
  final native = jsonDecode(
    File('test/fixtures/dos_resumed_field_battle.json').readAsStringSync(),
  )['save'];
  final random = LoreRandom(fixture['initial']['seed']);

  Future<void> tick(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<LoreGame> open(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
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
    final capture = fixture['initial'];
    final party = capture['partyRecord'];
    final nativeMap = List<int>.from(
      _hex(native['files']['SAVE1.MAP']['hex']).skip(2),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MainGameScreen(
          encounterRandom: random,
          initialSaveData: SaveData(
            slot: 1,
            slotName: 'DOS castle departure',
            timestamp: DateTime.utc(1993),
            mapId: party['mapId'],
            mapTitle: 'GROUND1',
            playerX: party['x'],
            playerY: party['y'],
            gold: party['gold'],
            food: party['food'],
            party: [
              for (final r in capture['records']) PartyMember.fromJson(r),
            ],
            flags: {
              for (var i = 0; i < 100; i++) 'etc${i + 1}': party['etc'][i],
            },
            mapTiles: nativeMap,
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

  Future<void> walk(
    WidgetTester tester,
    LoreGame game,
    List<dynamic> route,
  ) async {
    for (final key in route) {
      final (dx, dy) = switch (key) {
        'Up' => (0, -1),
        'Down' => (0, 1),
        'Left' => (-1, 0),
        'Right' => (1, 0),
        _ => throw StateError('Unknown captured key $key'),
      };
      game.tryMove(dx, dy);
      await tick(tester);
    }
  }

  Future<void> save(WidgetTester tester, int slot, dynamic checkpoint) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    await tick(tester);
    await tester.tap(find.text(LoreMenuText.optionSave));
    await tick(tester);
    await tester.tap(find.text(SaveManager.slotNames[slot - 1]));
    await tick(tester);
    final saved = (await SaveManager.instance.loadGame(slot))!;
    final p = checkpoint['partyRecord'];
    expect(saved.mapId, p['mapId']);
    expect((saved.playerX, saved.playerY), (p['x'], p['y']));
    expect((saved.gold, saved.food), (p['gold'], p['food']));
    expect(saved.party.map((p) => p.toJson()).toList(), checkpoint['records']);
    expect([for (var i = 1; i <= 100; i++) saved.flags['etc$i']], p['etc']);
    final file = 'SAVE$slot.MAP';
    expect(
      saved.mapTiles,
      _hex(checkpoint['files'][file]['hex']).skip(2).toList(),
    );
    expect(random.seed, checkpoint['wait']['seed']);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tick(tester);
    expect(random.seed, checkpoint['afterKey']['seed']);
  }

  Future<void> difficulty(WidgetTester tester, dynamic capture) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    await tick(tester);
    await tester.tap(find.text(LoreMenuText.optionDifficulty));
    await tick(tester);
    await tester.tap(find.byKey(const ValueKey('lore-select-1')));
    await tick(tester);
    await tester.tap(find.byKey(const ValueKey('lore-select-1')));
    await tick(tester);
    expect(random.seed, capture['after']['seed']);
    expect(LoreDialogueManager.instance.partyEtc.read(7), 5);
    expect(LoreDialogueManager.instance.partyEtc.read(8), 3);
  }

  Future<void> continueCenter(WidgetTester tester, LoreGame game) async {
    final f = jsonDecode(
      File('test/fixtures/dos_menace_center.json').readAsStringSync(),
    );
    void check(dynamic state) {
      expect(random.seed, state['seed']);
      expect(
        game.partyProvider!().map((p) => p.toJson()).toList(),
        state['records'],
      );
      expect(LoreDialogueManager.instance.partyEtc.snapshot(), {
        for (var i = 0; i < 100; i++) i + 1: state['partyRecord']['etc'][i],
      });
    }

    Future<void> process() async {
      for (var i = 0; i < 10; i++) {
        await tick(tester);
      }
    }

    check(f['initial']);
    await walk(tester, game, [for (final s in f['movement']) s['key']]);
    expect((game.playerX, game.playerY), (16, 39));
    expect(find.byType(EncounterViewportView), findsOneWidget);
    expect(
      tester
          .widget<EncounterViewportView>(find.byType(EncounterViewportView))
          .enemies
          .map((e) => e.eNumber)
          .toList(),
      [10, 12, 10],
    );
    check(f['encounter']);
    await tester.tap(find.byKey(const ValueKey('encounter-flee')));
    await process();
    check(f['enemyFirst']);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tick(tester);
    for (var slot = 0; slot < 6; slot++) {
      if (!game.partyProvider!()[slot].isBattleActive) continue;
      final c = f['round']['commands'][slot];
      await tester.tap(find.byKey(ValueKey('enemy-${c[2] - 1}')));
      await tester.tap(find.byKey(ValueKey('battle-cmd-${c[0]}')));
      await tick(tester);
    }
    await process();
    check(f['round']['partyPhase']);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await process();
    check(f['round']['enemyPhase']);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tick(tester);
    for (var slot = 0; slot < 6; slot++) {
      if (!game.partyProvider!()[slot].isBattleActive) continue;
      await tester.ensureVisible(find.byKey(const ValueKey('battle-cmd-7')));
      await tester.tap(find.byKey(const ValueKey('battle-cmd-7')));
      await tick(tester);
    }
    await process();
    // The native shared battle byte is already2 at the successful-flee ReadKey.
    check(f['runAway']['wait']);
    expect(find.byType(BattleViewportView), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tick(tester);
    check(f['runAway']['afterKey']);
    expect(find.byType(BattleViewportView), findsNothing);
    await walk(tester, game, [for (final s in f['centerMovement']) s['key']]);
    expect((game.playerX, game.playerY), (25, 8));
    check(f['center']['wait']);
    for (final (color, line) in const [
      (7, "여기가 `MENACE'의 중심이다."),
      (15, '당신의 탐험은 성공적이었다.'),
      (15, '이제 Lord Ahn 에게 돌아가는 일만 남았다.'),
    ]) {
      expect(
        tester.widget<Text>(find.text(line)).style!.color,
        RetroTheme.ega(color),
      );
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tick(tester);
    check(f['center']['afterKey']);
    // Real native menu detour: max-enemy Esc defaults to5 and continues to frequency.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    await tick(tester);
    await tester.tap(find.text(LoreMenuText.optionDifficulty));
    await tick(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tick(tester);
    check(f['menuDetour']['maxEscape']);
    await tester.tap(find.byKey(const ValueKey('lore-select-5')));
    await tick(tester);
    check(f['menuDetour']['frequencySelected']);
    await walk(tester, game, List<dynamic>.from(f['menuDetour']['keys']));
    check(f['menuDetour']['afterMovement']);
    expect((game.playerX, game.playerY), (25, 11));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    await tick(tester);
    await tester.tap(find.text(LoreMenuText.optionSave));
    await tick(tester);
    check(f['saveCancel']['wait']);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tick(tester);
    check(f['saveCancel']['afterEscape']);
    // Touch close has the same source Esc result; repeated cancellation cannot roll.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    await tick(tester);
    await tester.tap(find.text(LoreMenuText.optionSave));
    await tick(tester);
    await tester.tap(find.byKey(const ValueKey('dialog-cancel')));
    await tick(tester);
    check(f['saveCancel']['afterEscape']);
    await difficulty(tester, f['restoreDifficulty']);
    check(f['restoreDifficulty']['after']);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    await tick(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tick(tester);
    check(f['optionCancel']['afterEscape']);
    for (final rest in f['rests']) {
      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tick(tester);
      check(rest['wait']);
      await tester.sendKeyEvent(
        rest['escape'] ? LogicalKeyboardKey.escape : LogicalKeyboardKey.enter,
      );
      await tick(tester);
      check(rest['afterKey']);
      if (rest['escape']) {
        // Android/system back is also Esc, without calling the acknowledgement.
        await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
        await tick(tester);
        check(rest['wait']);
        await tester.binding.handlePopRoute();
        await tick(tester);
        check(rest['afterKey']);
      }
    }
    for (final (i, key) in (f['revisit']['keys'] as List).indexed) {
      await walk(tester, game, [key]);
      check(f['revisit']['states'][i]);
    }
    expect((game.playerX, game.playerY), (25, 8));
    expect(find.text("여기가 `MENACE'의 중심이다."), findsNothing);
    // Mobile persistence check, NOT an original centre disk-save fixture.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    await tick(tester);
    await tester.tap(find.text(LoreMenuText.optionSave));
    await tick(tester);
    await tester.tap(find.text(SaveManager.slotNames[3]));
    await tick(tester);
    final saved = (await SaveManager.instance.loadGame(4))!;
    final state = f['revisit']['states'].last;
    expect((saved.mapId, saved.playerX, saved.playerY), (14, 25, 8));
    expect(
      (saved.gold, saved.food),
      (state['partyRecord']['gold'], state['partyRecord']['food']),
    );
    expect(saved.party.map((p) => p.toJson()).toList(), state['records']);
    expect([
      for (var i = 1; i <= 100; i++) saved.flags['etc$i'],
    ], state['partyRecord']['etc']);
    expect(
      saved.mapTiles,
      _hex(fixture['goldSave']['files']['SAVE3.MAP']['hex']).skip(2).toList(),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tick(tester);
    check(state);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    await tick(tester);
    await tester.tap(find.text(LoreMenuText.optionResume));
    await tick(tester);
    await tester.tap(find.text(SaveManager.slotNames[3]));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tick(tester);
    expect((game.currentMapId, game.playerX, game.playerY), (14, 25, 8));
    expect(LoreDialogueManager.instance.partyEtc.read(10), 4);
    expect(
      LoreDialogueManager.instance.partyEtc.read(7),
      2,
    ); // Source Load normalization.
    expect(random.seed, state['seed']);
    await walk(tester, game, ['Down', 'Up']);
    expect(LoreDialogueManager.instance.partyEtc.read(10), 4);
    expect(find.text("여기가 `MENACE'의 중심이다."), findsNothing);
  }

  testWidgets(
    'native recovery, MENACE entry/centre, flee, Esc guards and persistence match on mobile',
    (tester) async {
      final game = await open(tester);
      for (final rest in fixture['rests']) {
        await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
        await tick(tester);
        expect(random.seed, rest['wait']['seed']);
        expect(
          game.partyProvider!().map((p) => p.toJson()).toList(),
          rest['wait']['records'],
        );
        expect(LoreDialogueManager.instance.partyEtc.snapshot(), {
          for (var i = 0; i < 100; i++)
            i + 1: rest['wait']['partyRecord']['etc'][i],
        });
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tick(tester);
        expect(random.seed, rest['afterKey']['seed']);
      }
      await difficulty(tester, fixture['difficulty']);
      await walk(tester, game, [for (final s in fixture['movement']) s['key']]);
      expect((game.currentMapId, game.playerX, game.playerY), (1, 18, 89));
      await save(tester, 1, fixture['approachSave']);
      for (final response in ['decline', 'escape']) {
        game.tryMove(-1, 0);
        await tick(tester);
        expect(random.seed, fixture['portal']['request']['seed']);
        expect(
          tester
              .widget<Text>(find.text(LoreFieldLogic.enterPrompt('MENACE')))
              .style!
              .color,
          RetroTheme.ega(11),
        );
        if (response == 'escape') {
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        } else {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        }
        await tick(tester);
        expect((game.currentMapId, game.playerX, game.playerY), (1, 18, 89));
        expect(random.seed, fixture['portal'][response]['seed']);
        expect(find.byKey(const ValueKey('dialog-cancel')), findsNothing);
        expect(
          tester.widget<MessageLogView>(find.byType(MessageLogView)).logs,
          isNot(contains(LoreFieldLogic.asYouWish)),
        );
      }
      game.tryMove(-1, 0);
      await tick(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tick(tester);
      expect((game.currentMapId, game.playerX, game.playerY), (14, 25, 45));
      expect(random.seed, fixture['portal']['entered']['seed']);
      expect(LoreDialogueManager.instance.partyEtc.read(7), 2);
      expect(LoreDialogueManager.instance.partyEtc.read(8), 3);
      await tester.runAsync(
        () => tester
            .state<GameWidgetState<LoreGame>>(find.byType(GameWidget<LoreGame>))
            .loaderFuture,
      );
      await tick(tester);
      await save(tester, 2, fixture['insideSave']);
      await difficulty(tester, fixture['goldDifficulty']);
      await walk(tester, game, [
        for (final step in fixture['goldMovement']) step['key'],
      ]);
      expect((game.currentMapId, game.playerX, game.playerY), (14, 6, 44));
      expect(random.seed, fixture['goldCollected']['seed']);
      expect(LoreDialogueManager.instance.partyEtc.read(32), 4);
      await save(tester, 3, fixture['goldSave']);
      for (final (i, key) in (fixture['goldRevisit']['keys'] as List).indexed) {
        await walk(tester, game, [key]);
        expect(
          random.seed,
          fixture['goldRevisit'][i == 0 ? 'left' : 'returned']['seed'],
        );
      }
      expect(LoreDialogueManager.instance.partyEtc.read(32), 4);
      // A subsequent normal save checks that revisiting did not collect400 twice.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
      await tick(tester);
      await tester.tap(find.text(LoreMenuText.optionSave));
      await tick(tester);
      await tester.tap(find.text(SaveManager.slotNames[2]));
      await tick(tester);
      expect((await SaveManager.instance.loadGame(3))!.gold, 2525);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tick(tester);
      await continueCenter(tester, game);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

List<int> _hex(String s) => [
  for (var i = 0; i < s.length; i += 2)
    int.parse(s.substring(i, i + 2), radix: 16),
];

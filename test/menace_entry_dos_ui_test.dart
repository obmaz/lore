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
import 'package:lore/logic/lore_menu_text.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/services/save_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// LOREENT.PAS:37-43, LORESUB.PAS:986-1024 and LOREMAIN.PAS sequential position blocks.
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

  testWidgets(
    'native recovery, source difficulty and MENACE refusal/admission match on mobile',
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
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

List<int> _hex(String s) => [
  for (var i = 0; i < s.length; i += 2)
    int.parse(s.substring(i, i + 2), radix: 16),
];

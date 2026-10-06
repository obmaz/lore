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
import 'package:lore/theme/retro_theme.dart';
import 'package:lore/logic/lore_menu_text.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/services/save_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// LORESUB.PAS:1636-1790, LORESPEC.PAS:826-832, LOREMAIN.PAS:205.
/// LORETALK.PAS:360-383: actual centre disk reload and Lord Ahn continuation.
void main() {
  final fixture = jsonDecode(
    File('test/fixtures/dos_menace_return.json').readAsStringSync(),
  );
  // LORESUB.PAS Grocery/Save; LOREMENU.PAS Rest; LORETALK.PAS:406-469.
  final lastditch = jsonDecode(
    File('test/fixtures/dos_lastditch_arrival.json').readAsStringSync(),
  );
  dynamic observed(int number) => (lastditch['inputs'] as List).singleWhere(
    (input) => input['capture'] == 'lore_$number.png',
  )['after'];
  // LOREENT.PAS:159-167; LORESPEC.PAS:313-319, 493-521.
  final pyramid = lastditch['pyramid'];
  dynamic pyramidState(int number) => (pyramid['inputs'] as List).singleWhere(
    (input) => input['capture'] == 'lore_$number.png',
  )['after'];
  Future<void> tick(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<LoreGame> open(
    WidgetTester tester,
    dynamic saved,
    LoreRandom random,
  ) async {
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
    final capture = saved;
    final party = capture['partyRecord'];
    final files = Map<String, dynamic>.from(saved['files']);
    final mapFile = files.entries.singleWhere(
      (file) => file.key.startsWith('SAVE'),
    );
    final nativeMap = _hex(mapFile.value['hex']).skip(2).toList();
    await tester.pumpWidget(
      MaterialApp(
        home: MainGameScreen(
          encounterRandom: random,
          initialSaveData: SaveData(
            slot: 1,
            slotName: 'Original DOS checkpoint',
            timestamp: DateTime.utc(1993),
            mapId: party['mapId'],
            mapTitle: 'Original map',
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

  void check(LoreGame game, LoreRandom random, dynamic state) {
    expect(random.seed, state['seed']);
    expect(
      game.partyProvider!().map((p) => p.toJson()).toList(),
      state['records'],
    );
    expect(LoreDialogueManager.instance.partyEtc.snapshot(), {
      for (var i = 0; i < 100; i++) i + 1: state['partyRecord']['etc'][i],
    });
  }

  Future<void> save(
    WidgetTester tester,
    LoreGame game,
    LoreRandom random,
    dynamic checkpoint,
    dynamic wait,
    dynamic afterKey,
  ) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    await tick(tester);
    await tester.tap(find.text(LoreMenuText.optionSave));
    await tick(tester);
    await tester.tap(find.text(SaveManager.slotNames[0]));
    await tick(tester);
    check(game, random, wait);
    final saved = (await SaveManager.instance.loadGame(1))!;
    final p = checkpoint['partyRecord'];
    expect(
      (saved.mapId, saved.playerX, saved.playerY),
      (p['mapId'], p['x'], p['y']),
    );
    expect((saved.gold, saved.food), (p['gold'], p['food']));
    expect(saved.party.map((p) => p.toJson()).toList(), checkpoint['records']);
    expect([for (var i = 1; i <= 100; i++) saved.flags['etc$i']], p['etc']);
    expect(
      saved.mapTiles,
      _hex(checkpoint['files']['SAVE1.MAP']['hex']).skip(2).toList(),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tick(tester);
    check(game, random, afterKey);
  }

  testWidgets(
    'actual DOS centre disk reload, revisit and resave preserve all records and map bytes',
    (tester) async {
      final f = fixture['centerReload'];
      final inputs = f['inputs'];
      final random = LoreRandom(inputs[0]['after']['seed']);
      final game = await open(tester, fixture['centerSave'], random);
      check(game, random, inputs[0]['after']);
      expect((game.playerX, game.playerY), (25, 8));
      for (var i = 1; i <= 2; i++) {
        await walk(tester, game, List<dynamic>.from(inputs[i]['keys']));
        check(game, random, inputs[i]['after']);
      }
      expect((game.playerX, game.playerY), (25, 8));
      expect(find.text("여기가 `MENACE'의 중심이다."), findsNothing);
      expect(find.text('당신의 탐험은 성공적이었다.'), findsNothing);
      await save(
        tester,
        game,
        random,
        f['save'],
        inputs[5]['after'],
        inputs[6]['after'],
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'actual DOS grocery, four rests and disk save recover the Lord Ahn party',
    (tester) async {
      final movement = lastditch['walks']['grocery'];
      final random = LoreRandom(movement['initial']['seed']);
      final game = await open(tester, fixture['lordAhn']['save'], random);
      check(game, random, movement['initial']);
      for (final step in movement['steps']) {
        await walk(tester, game, [step['key']]);
        expect(random.seed, step['after']['seed']);
      }
      check(game, random, movement['after']);
      expect((game.playerX, game.playerY), (86, 73));
      await walk(tester, game, ['Right']);
      check(game, random, observed(109));
      await tester.tap(find.text('50 인분 : 금 500 개'));
      await tick(tester);
      check(game, random, observed(110));
      for (final number in [111, 113, 115, 117]) {
        await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
        await tick(tester);
        check(game, random, observed(number));
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tick(tester);
        check(game, random, observed(number + 1));
      }
      await save(
        tester,
        game,
        random,
        lastditch['readySave'],
        observed(121),
        observed(122),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'actual LASTDITCH save -> Lord request -> Polaris cancel/replacement -> disk save',
    (tester) async {
      final movement = lastditch['walks']['lord'];
      final random = LoreRandom(movement['initial']['seed']);
      final game = await open(tester, lastditch['arrivalSave'], random);
      check(game, random, movement['initial']);
      for (final step in movement['steps']) {
        await walk(tester, game, [step['key']]);
        expect(random.seed, step['after']['seed']);
      }
      check(game, random, movement['after']);
      expect((game.playerX, game.playerY), (38, 18));
      await walk(tester, game, ['Up']);
      check(game, random, observed(137));
      expect(LoreDialogueManager.instance.partyEtc.read(13), 0);
      expect(find.textContaining('PYRAMID'), findsWidgets);
      // DOS Scroll pages need extra keys; compare the closed procedure's
      // first wait and final PressAnyKey, not original text-page geometry.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tick(tester);
      check(game, random, observed(142));
      await walk(tester, game, ['Up']);
      check(game, random, observed(143));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tick(tester);
      check(game, random, observed(144));
      for (final step in lastditch['walks']['polaris']['steps']) {
        await walk(tester, game, [step['key']]);
        expect(random.seed, step['after']['seed']);
      }
      check(game, random, lastditch['walks']['polaris']['after']);
      expect((game.playerX, game.playerY), (37, 42));
      for (final attempt in [false, true]) {
        await walk(tester, game, ['Up']);
        check(game, random, observed(attempt ? 149 : 146));
        await tester.tap(find.text('나는 당신의 제안을 받아 들이겠소'));
        await tick(tester);
        check(game, random, observed(attempt ? 150 : 147));
        if (attempt) {
          // Use the captured Select keys; the character panel also shows Merlin.
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tick(tester);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        } else {
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        }
        await tick(tester);
        check(game, random, observed(attempt ? 151 : 148));
        expect(game.currentMap!.getTile(37, 41), attempt ? 44 : 53);
      }
      await save(
        tester,
        game,
        random,
        lastditch['polarisSave'],
        observed(154),
        observed(155),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'actual LASTDITCH secret passage, PYRAMID load and save acknowledgment encounter',
    (tester) async {
      final movement = pyramid['entryMovement'];
      final random = LoreRandom(movement['initial']['seed']);
      final game = await open(tester, lastditch['polarisSave'], random);
      check(game, random, movement['initial']);
      for (final step in movement['steps']) {
        await walk(tester, game, [step['key']]);
        expect(random.seed, step['after']['seed']);
      }
      expect((game.playerX, game.playerY), (29, 8));
      for (var number = 157; number <= 166; number++) {
        final input = (pyramid['inputs'] as List).singleWhere(
          (i) => i['capture'] == 'lore_$number.png',
        );
        await walk(tester, game, List<String>.from(input['keys']));
        check(game, random, input['after']);
        if (number < 166) expect(game.currentMap!.getTile(31, 8), 45);
      }
      expect((game.playerX, game.playerY), (37, 7));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.runAsync(() async {
        for (var i = 0; i < 20 && game.currentMapId != 11; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tick(tester);
      check(game, random, pyramidState(167));
      expect((game.currentMapId, game.playerX, game.playerY), (11, 25, 45));
      await save(
        tester,
        game,
        random,
        pyramid['arrivalSave'],
        pyramidState(170),
        pyramidState(171),
      );
      expect(find.textContaining('Giant'), findsWidgets);
      // Stop at the native encounter choice; the captured Giant battle is
      // retained as provenance, not claimed as a new full battle replay.
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'actual PYRAMID spear cancellation, fighter rejection, knight bonus and save',
    (tester) async {
      // After the actual Giant escape, exit and reentry, native party/player
      // bytes equal this genuine earlier disk save (checked by Python).
      final random = LoreRandom(pyramidState(209)['seed']);
      final game = await open(tester, pyramid['arrivalSave'], random);
      check(game, random, pyramidState(209));
      for (final (start, choice) in [(210, -1), (215, 4), (220, 1)]) {
        if (start != 210) {
          await walk(tester, game, ['Down']);
          check(game, random, pyramidState(start - 1));
        }
        await walk(tester, game, ['Up']);
        check(game, random, pyramidState(start));
        expect((game.playerX, game.playerY), (25, 44));
        for (var number = start + 1; number <= start + 2; number++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tick(tester);
          check(game, random, pyramidState(number));
        }
        if (choice < 0) {
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        } else {
          for (var i = 0; i < choice; i++) {
            await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
            await tick(tester);
          }
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        }
        await tick(tester);
        check(game, random, pyramidState(start + 3));
        expect(
          LoreDialogueManager.instance.partyEtc.read(33),
          choice == 1 ? 128 : 0,
        );
      }
      await save(
        tester,
        game,
        random,
        pyramid['spearSave'],
        pyramidState(226),
        pyramidState(227),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'actual DOS Castle reload -> Lord Ahn reward -> LASTDITCH hint -> revisit -> save',
    (tester) async {
      final f = fixture['lordAhn'];
      final random = LoreRandom(fixture['castleReload']['after']['seed']);
      final game = await open(tester, fixture['castleSave'], random);
      check(game, random, fixture['castleReload']['after']);
      expect((game.playerX, game.playerY), (51, 95));
      for (final step in f['movement']['steps']) {
        expect(random.seed, step['seedBefore']);
        await walk(tester, game, [step['key']]);
        expect(random.seed, step['seedAfter']);
      }
      check(game, random, f['movement']['after']);
      expect((game.playerX, game.playerY), (51, 29));
      final before = game.partyProvider!().map((p) => p.experience).toList();
      for (final (index, input) in (f['inputs'] as List).indexed) {
        check(game, random, input['before']);
        final keys = List<String>.from(input['keys']);
        if (keys.single == 'Up') {
          await walk(tester, game, keys);
        } else {
          await tester.sendKeyEvent(
            keys.single == 'Escape'
                ? LogicalKeyboardKey.escape
                : LogicalKeyboardKey.enter,
          );
          await tick(tester);
        }
        check(game, random, input['after']);
        expect((game.playerX, game.playerY), (51, 29));
        if (index == 0) {
          expect(
            tester.widget<Text>(find.text('[EXP + 1000]')).style!.color,
            RetroTheme.ega(11),
          );
          expect(LoreDialogueManager.instance.partyEtc.read(10), 5);
        }
        if (index == 2) {
          expect(LoreDialogueManager.instance.partyEtc.read(10), 5);
          expect(find.textContaining('LASTDITCH'), findsWidgets);
        }
        if (index >= 3) {
          expect(LoreDialogueManager.instance.partyEtc.read(10), 6);
        }
        expect(
          game.partyProvider!().map((p) => p.experience).toList(),
          before.map((v) => v + 1000).toList(),
        );
      }
      await save(
        tester,
        game,
        random,
        f['save'],
        f['saveInputs'][2]['after'],
        f['saveInputs'][3]['after'],
      );
      expect(tester.takeException(), isNull);
    },
  );
}

List<int> _hex(String value) => [
  for (var i = 0; i < value.length; i += 2)
    int.parse(value.substring(i, i + 2), radix: 16),
];

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

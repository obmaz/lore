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
import 'package:lore/logic/lore_menu_text.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/services/save_manager.dart';
import 'package:lore/widgets/battle_viewport_view.dart';
import 'package:lore/widgets/encounter_viewport_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A real departure-save reload and a different native enemy-first encounter.
void main() {
  final fixture = jsonDecode(
    File('test/fixtures/dos_resumed_field_battle.json').readAsStringSync(),
  );
  final native = jsonDecode(
    File('test/fixtures/dos_new_game.json').readAsStringSync(),
  )['castleRoute']['departure'];
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

  testWidgets('resumed native enemy magic and member flee match on mobile', (
    tester,
  ) async {
    final game = await open(tester);
    await walk(tester, game, [for (final s in fixture['movement']) s['key']]);
    expect(find.byType(EncounterViewportView), findsOneWidget);
    expect(random.seed, fixture['encounter']['seed']);
    await tester.tap(find.byKey(const ValueKey('encounter-engage')));
    for (var i = 0; i < 10; i++) {
      await tick(tester);
    }
    expect(random.seed, fixture['enemyFirst']['seed']);
    expect(
      game.partyProvider!().map((p) => p.toJson()).toList(),
      fixture['enemyFirst']['records'],
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tick(tester);
    for (final round in fixture['rounds']) {
      if (round['commands'] == null) {
        await tester.tap(find.byKey(const ValueKey('battle-cmd-7')));
      } else {
        for (var i = 0; i < 6; i++) {
          if (!game.partyProvider!()[i].isBattleActive) continue;
          final c = round['commands'][i];
          if (c[0] == 1) {
            await tester.tap(find.byKey(ValueKey('enemy-${c[2] - 1}')));
          }
          await tester.tap(find.byKey(ValueKey('battle-cmd-${c[0]}')));
          if (c[0] == 5) {
            await tick(tester);
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          }
          await tick(tester);
        }
      }
      for (var i = 0; i < 10; i++) {
        await tick(tester);
      }
      expect(random.seed, round['partyPhase']['seed']);
      expect(
        game.partyProvider!().map((p) => p.toJson()).toList(),
        round['partyPhase']['records'],
      );
      if (round['enemyPhase'] != null) {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        for (var i = 0; i < 10; i++) {
          await tick(tester);
        }
        expect(random.seed, round['enemyPhase']['seed']);
        expect(
          game.partyProvider!().map((p) => p.toJson()).toList(),
          round['enemyPhase']['records'],
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tick(tester);
      }
    }
    expect(find.byType(BattleViewportView), findsNothing);
    expect(random.seed, fixture['victory']['seed']);
    expect(
      game.partyProvider!().map((p) => p.toJson()).toList(),
      fixture['victory']['records'],
    );
    await tester.runAsync(
      () => tester
          .state<GameWidgetState<LoreGame>>(find.byType(GameWidget<LoreGame>))
          .loaderFuture,
    );
    await tick(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    await tick(tester);
    await tester.tap(find.text(LoreMenuText.optionSave));
    await tick(tester);
    await tester.tap(find.text(SaveManager.slotNames.first));
    await tick(tester);
    final saved = (await SaveManager.instance.loadGame(1))!;
    final checkpoint = fixture['save'];
    final p = checkpoint['partyRecord'];
    expect(saved.mapId, p['mapId']);
    expect((saved.playerX, saved.playerY), (p['x'], p['y']));
    expect(saved.gold, p['gold']);
    expect(saved.food, p['food']);
    expect(saved.party.map((p) => p.toJson()).toList(), checkpoint['records']);
    expect([for (var i = 1; i <= 100; i++) saved.flags['etc$i']], p['etc']);
    expect(
      saved.mapTiles,
      _hex(checkpoint['files']['SAVE1.MAP']['hex']).skip(2).toList(),
    );
    expect(random.seed, checkpoint['wait']['seed']);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tick(tester);
    expect(random.seed, checkpoint['afterKey']['seed']);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

List<int> _hex(String s) => [
  for (var i = 0; i < s.length; i += 2)
    int.parse(s.substring(i, i + 2), radix: 16),
];

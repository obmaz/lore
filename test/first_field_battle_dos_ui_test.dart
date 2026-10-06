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
import 'package:lore/models/party_member.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/services/save_manager.dart';
import 'package:lore/widgets/battle_viewport_view.dart';
import 'package:lore/widgets/encounter_viewport_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Actual DOS movement RNG -> encounter -> automatic round -> second encounter
/// -> failed flee -> enemy phase through the mobile screen. No synthetic RNG.
void main() {
  final fixture = jsonDecode(
    File('test/fixtures/dos_first_field_battle.json').readAsStringSync(),
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

  testWidgets(
    'native seeded route, automatic victory and failed flee match on mobile',
    (tester) async {
      final game = await open(tester);
      await walk(tester, game, [
        for (final step in fixture['movement']) step['key'],
      ]);
      expect(find.byType(EncounterViewportView), findsOneWidget);
      expect(random.seed, fixture['encounter']['seed']);
      expect(
        tester
            .widget<EncounterViewportView>(find.byType(EncounterViewportView))
            .enemies
            .map((e) => e.eNumber)
            .toList(),
        [4],
      );
      await tester.tap(find.byKey(const ValueKey('encounter-engage')));
      await tick(tester);
      await tester.tap(find.byKey(const ValueKey('battle-cmd-7')));
      for (var i = 0; i < 10; i++) {
        await tick(tester);
      }
      expect(random.seed, fixture['checkpoints']['partyPhaseWait']['seed']);
      expect(
        game.partyProvider!().map((p) => p.toJson()).toList(),
        fixture['checkpoints']['partyPhaseWait']['records'],
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter); // party PressAnyKey
      await tick(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter); // enemy ReadKey
      await tick(tester);
      expect(find.byType(BattleViewportView), findsNothing);
      expect(random.seed, fixture['checkpoints']['victory']['seed']);
      expect(LoreDialogueManager.instance.partyEtc.snapshot(), {
        for (var i = 0; i < 100; i++)
          i + 1: fixture['checkpoints']['victory']['partyRecord']['etc'][i],
      });
      final second = fixture['secondEncounter'];
      await walk(tester, game, [
        for (final step in second['movement']) step['key'],
      ]);
      expect(find.byType(EncounterViewportView), findsOneWidget);
      expect(random.seed, second['encounter']['seed']);
      await tester.tap(find.byKey(const ValueKey('encounter-flee')));
      for (var i = 0; i < 10; i++) {
        await tick(tester);
      }
      expect(find.byType(BattleViewportView), findsOneWidget);
      expect(random.seed, second['enemyPhaseReadKey']['seed']);
      expect(
        game.partyProvider!().map((p) => p.toJson()).toList(),
        second['enemyPhaseReadKey']['records'],
      );
      expect(LoreDialogueManager.instance.partyEtc.snapshot(), {
        for (var i = 0; i < 100; i++)
          i + 1: second['enemyPhaseReadKey']['partyRecord']['etc'][i],
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

List<int> _hex(String value) => [
  for (var i = 0; i < value.length; i += 2)
    int.parse(value.substring(i, i + 2), radix: 16),
];

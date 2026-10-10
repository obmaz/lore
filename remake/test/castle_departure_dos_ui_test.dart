import 'support/source_audio_platform.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/game/lore_world_manager.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/services/save_manager.dart';
import 'package:lore/widgets/script_scene_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// LORESPEC.PAS:243-301 / LORETALK.PAS:285-291, through the actual screen.
/// Starts at the independently captured cold-created DOS armoury save.
/// Unrelated encounters are disabled; this is not native RNG seed parity.
class _NoEncounter implements Random {
  @override
  int nextInt(int max) => max - 1;
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0.99;
}

void main() {
  setUp(installSourceAudioPlatform);
  final fixture = jsonDecode(
    File('test/fixtures/dos_new_game.json').readAsStringSync(),
  )['castleRoute'];

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
    final capture = fixture['armory'];
    final party = capture['party'];
    final nativeMap = List<int>.from(
      _hex(capture['files']['SAVE1.MAP']['hex']).skip(2),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MainGameScreen(
          sourceReplayBattle: true,
          encounterRandom: _NoEncounter(),
          initialSaveData: SaveData(
            slot: 1,
            slotName: 'DOS armoury',
            timestamp: DateTime.utc(1993),
            mapId: party['mapId'],
            mapTitle: 'CASTLE LORE',
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

  for (final response in ['accept', 'decline', 'escape']) {
    testWidgets('Skeleton $response waits before exit flag and map load', (
      tester,
    ) async {
      final game = await open(tester);
      await walk(tester, game, fixture['inputs']['blessingApproach']);
      game.tryMove(0, 1);
      await tick(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tick(tester);
      await walk(tester, game, fixture['inputs']['exitApproach']);
      await tester.tap(find.text('예, 그렇습니다.'));
      await tick(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tick(tester);
      if (response == 'escape') {
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      } else {
        await tester.tap(
          find.text(response == 'accept' ? '당신을 환영하오.' : '미안하지만 안되겠소.'),
        );
      }
      await tick(tester);
      expect(game.currentMapId, 6);
      expect([game.playerX, game.playerY], [51, 96]);
      expect(LoreDialogueManager.instance.partyEtc.read(31), 0);
      final scene = tester.widget<ScriptSceneDialog>(
        find.byType(ScriptSceneDialog),
      );
      expect(
        scene.scene.lines,
        response == 'accept' ? isEmpty : ['당신이 바란다면 ...'],
      );
      expect(
        find.text('Skeleton'),
        response == 'accept' ? findsWidgets : findsNothing,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tick(tester);
      expect(game.currentMapId, 1);
      expect([game.playerX, game.playerY], [20, 12]);
      expect(LoreDialogueManager.instance.partyEtc.read(31), 1);
      expect(
        game.currentMap!.tileSnapshot(),
        _hex(fixture['departure']['files']['SAVE1.MAP']['hex'])
            .skip(2)
            .toList(),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
      await tick(tester);
      await tester.tap(find.text('현재의 게임을 저장'));
      await tick(tester);
      await tester.tap(find.text('본 게임 데이타'));
      await tick(tester);
      final saved = (await SaveManager.instance.loadGame(1))!;
      expect(
        saved.party.map((p) => p.toJson()).toList(),
        fixture[response == 'accept' ? 'departure' : 'armory']['records'],
      );
      expect([saved.food, saved.gold], [20, 2000]);
      expect(LoreDialogueManager.instance.partyEtc.snapshot(), {
        for (var i = 0; i < 100; i++)
          i + 1: fixture['departure']['party']['etc'][i],
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

List<int> _hex(String value) => [
  for (var i = 0; i < value.length; i += 2)
    int.parse(value.substring(i, i + 2), radix: 16),
];

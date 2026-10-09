import 'dart:convert';
import 'dart:io';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:lore/logic/lore_startup_options.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/game/sprite_sheet.dart';
import 'package:lore/game/lore_world_manager.dart';
import 'package:lore/data/lore_data.dart';
import 'package:lore/data/lore_creation.dart';
import 'package:lore/main.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/screens/character_creation_screen.dart';
import 'package:lore/screens/lore_help_screen.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/services/audio_manager.dart';
import 'package:lore/services/save_manager.dart';
import 'package:lore/widgets/game_over_view.dart';
import 'package:lore/widgets/lore_title_intro.dart';
import 'package:lore/widgets/lore_creation_animation.dart';

import 'support/source_audio_platform.dart';

import 'package:shared_preferences/shared_preferences.dart';

// LORE.PAS first-argument predicates, InitSound failure and outer Main/music
// dispatch; LOREHELP.PAS help fade/create jump; LORESUB.PAS UnSound cleanup.
// CLI, MP3/device and GUI event loop are modern adapters; no DOS driver launch.
void main() {
  final data = jsonDecode(
    File('test/fixtures/dos_startup.json').readAsStringSync(),
  );
  final calls = <MethodCall>[];
  var halted = 0;
  var usedAudio = false;
  setUp(() {
    installSourceAudioPlatform();
    (AudioplayersPlatformInterface.instance as SourceAudioPlatform)
            .prepareAssets =
        true;
    SharedPreferences.setMockInitialValues({});
    calls.clear();
    halted = 0;
    usedAudio = false;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers.global',
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(channel), (call) async {
        calls.add(call);
        return 1;
      });
    }
    messenger.setMockStreamHandler(
      const EventChannel('xyz.luan/audioplayers.global/events'),
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemNavigator.pop') halted++;
      return null;
    });
  });
  tearDown(() async {
    if (usedAudio) {
      AudioManager.instance.sourceMusicEnabled = true;
      AudioManager.instance.sourceSoundEnabled = true;
    }
    (AudioplayersPlatformInterface.instance as SourceAudioPlatform)
            .prepareAssets =
        false;
    SharedPreferences.resetStatic();
  });
  for (final row in data['main']) {
    test(
      'native startup ${row['argv']}/${row['initExists']}/${row['error']}',
      () {
        final args = (row['argv'] as List).cast<String>();
        final options = LoreStartupOptions.parse(args);
        final trace = row['trace'] as List;
        expect(trace.first, ['argc', args.length]);
        expect(
          trace.where((op) => op[0] == 'argv').toList(),
          args.isEmpty
              ? []
              : [
                  ['argv', 1],
                ],
        );
        expect(trace.any((op) => op[0] == 'initSound'), options.musicEnabled);
        expect(row['adlib'], options.musicEnabled && row['error'] == 0);
        expect(
          trace.any((op) => op[0] == 'title'),
          options.mode != LoreStartupMode.game,
        );
        expect(
          trace.where((op) => op[0] == 'exec').length,
          options.musicEnabled && row['initExists'] ? 1 : 0,
        );
        if (options.mode == LoreStartupMode.help) {
          expect(trace.last, ['halt', 0]);
          expect(trace.any((op) => op[0] == 'setAll'), false);
        } else if (row['adlib']) {
          expect(trace.where((op) => op[0] == 'play').toList(), [
            ['play', 0x25d, 0x6c7],
            ['play', 0x25d, 0x6c7],
          ]);
          expect(trace.where((op) => op[0] == 'song').toList(), [
            ['song', 'Music2.Bgm', 0],
            ['song', 'Music3.Bgm', 0],
          ]);
          expect(trace.where((op) => op[0] == 'playOff').length, 2);
        } else {
          expect(trace.where((op) => op[0] == 'main').length, 2);
          expect(trace.any((op) => op[0] == 'song'), false);
        }
      },
    );
  }
  Future<void> clean(WidgetTester tester) async {
    AudioManager.instance.stopSourceAudio();
    await tester.pump();
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump();
  }

  Future<void> loaded(WidgetTester tester) async {
    final f = find.byType(GameWidget<LoreGame>);
    await tester.runAsync(
      () => tester.state<GameWidgetState<LoreGame>>(f).loaderFuture,
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  // AudioPlayer stores creation futures. Keep simulated process launches in
  // one FakeAsync zone so a singleton device is not reused from a dead zone.
  testWidgets(
    'actual startup modes, music loop and UnSound/Halt match source',
    (tester) async {
      usedAudio = true;
      await tester.pumpWidget(
        LoreApp(startup: LoreStartupOptions.parse(['/m', '/g'])),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(LoreTitleIntro), findsOneWidget);
      expect(AudioManager.instance.sourceMusicEnabled, false);
      expect(AudioManager.instance.currentBgm, isNull);
      expect(calls.any((call) => call.method == 'setReleaseMode'), false);
      final platform =
          AudioplayersPlatformInterface.instance as SourceAudioPlatform;
      final before = platform.sourceBytes.length;
      AudioManager.instance.playSourceTone(20, 5);
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(platform.sourceBytes.length, before + 1);
      await clean(tester);

      for (final arg in ['/c', '/C']) {
        calls.clear();
        await tester.pumpWidget(
          LoreApp(startup: LoreStartupOptions.parse([arg])),
        );
        await tester.pump();
        expect(find.byType(LoreTitleIntro), findsNothing);
        expect(find.byType(LoreCreationAnimation), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'a');
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyM, character: 'm');
        await tester.pump(const Duration(milliseconds: 5120));
        await tester.pump();
        await tester.pump();
        expect(
          find.text(LoreCreationData.instance.questions.first.lines.first),
          findsOneWidget,
        );
        expect(find.byType(LoreTitleIntro), findsNothing);
        expect(AudioManager.instance.sourceMusicEnabled, true);
        if (arg == '/c') {
          expect(
            calls.any(
              (call) =>
                  call.method == 'setReleaseMode' &&
                  (call.arguments as Map)['releaseMode'] ==
                      ReleaseMode.loop.toString(),
            ),
            true,
          );
        }
        await clean(tester);
      }
      await tester.runAsync(() async {
        await LoreData.instance.load();
        await SpriteLibrary.instance.load();
        await LoreWorldManager.instance.loadData();
      });
      for (final arg in ['/g', '/G']) {
        await SaveManager.instance.writeNewGame([
          PartyMember.createPreset(1),
        ], mapTitle: 'TOWN1');
        await tester.pumpWidget(
          LoreApp(startup: LoreStartupOptions.parse([arg, '/m'])),
        );
        await tester.pump();
        await tester.pump();
        expect(find.byType(CharacterCreationScreen), findsNothing);
        expect(find.byType(MainGameScreen), findsOneWidget);
        await loaded(tester);
        final f = find.byType(GameWidget<LoreGame>);
        final game = tester.widget<GameWidget<LoreGame>>(f).game!;
        final before = (game.playerX, game.playerY);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
        await tester.pump();
        expect((game.playerX, game.playerY), isNot(before));
        AudioManager.instance.playBgm(BgmTrack.ground);
        await tester.pump();
        await tester.pump();
        await tester.pump();
        expect(AudioManager.instance.currentBgm, BgmTrack.ground);
        final now = (game.playerX, game.playerY);
        AudioManager.instance.playBgm(BgmTrack.town);
        await tester.pump();
        await tester.pump();
        await tester.pump();
        expect(AudioManager.instance.currentBgm, BgmTrack.town);
        expect((game.playerX, game.playerY), now);
        expect(
          identical(tester.widget<GameWidget<LoreGame>>(f).game, game),
          true,
        );
        expect(AudioManager.instance.sourceSoundEnabled, true);
        await clean(tester);
      }
      halted = 0;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('lore_save_slot_1');
      await tester.pumpWidget(
        LoreApp(startup: LoreStartupOptions.parse(['/g'])),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(HaltView), findsOneWidget);
      expect(find.text('"party1.dat" not found.'), findsOneWidget);
      expect(find.text('You need to CREATE CHARACTER.'), findsOneWidget);
      expect(find.byType(MainGameScreen), findsNothing);
      expect(find.byType(CharacterCreationScreen), findsNothing);
      expect(halted, 1);
      await clean(tester);

      for (final arg in ['/?', '-?', '?']) {
        calls.clear();
        halted = 0;
        await tester.pumpWidget(
          LoreApp(startup: LoreStartupOptions.parse([arg])),
        );
        await tester.pump();
        expect(find.byType(LoreHelpScreen), findsOneWidget);
        expect(find.byType(CharacterCreationScreen), findsNothing);
        await tester.pump(const Duration(milliseconds: 6450));
        await tester.pump();
        await tester.pump();
        expect(halted, 1);
        expect(AudioManager.instance.currentBgm, isNull);
        expect(
          calls
              .where((call) => call.method == 'stop')
              .map((call) => (call.arguments as Map)['playerId'])
              .toSet()
              .length,
          2,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(halted, 1);
        await clean(tester);
      }
      halted = 0;
      await tester.pumpWidget(const LoreApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 53030));
      await tester.pump();
      calls.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await tester.pump();
      await tester.pump();
      expect(halted, 1);
      expect(
        calls
            .where((call) => call.method == 'stop')
            .map((call) => (call.arguments as Map)['playerId'])
            .toSet()
            .length,
        2,
      );
      await clean(tester);
    },
  );
  for (final limit in [1, 43, 64, 129, 999]) {
    testWidgets(
      'three native help fades wait/skip exactly at $limit delay polls',
      (tester) async {
        usedAudio = true;
        final row = (data['title'] as List).firstWhere(
          (r) =>
              r['arg'] == '/?' && !r['endExists'] && r['delayLimit'] == limit,
        );
        final total = (row['trace'] as List)
            .where((op) => op[0] == 'delay')
            .fold<int>(0, (sum, op) => sum + op[1] as int);
        var done = 0;
        await tester.pumpWidget(
          MaterialApp(home: LoreHelpScreen(onHalt: () => done++)),
        );
        await tester.pump();
        if (limit < 129) {
          await tester.pump(Duration(milliseconds: (limit - 1) * 50));
          await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
          await tester.pump(const Duration(milliseconds: 49));
          expect(done, 0);
          await tester.pump(const Duration(milliseconds: 1));
        } else {
          await tester.pump(Duration(milliseconds: total - 1));
          expect(done, 0);
          await tester.pump(const Duration(milliseconds: 1));
        }
        expect(done, 1);
        expect(total, limit < 129 ? limit * 50 : 6450);
        for (final line in [
          ...LoreHelpScreen.fadingLines,
          ...LoreHelpScreen.optionLines,
        ]) {
          expect(find.text(line), findsOneWidget);
        }
        await tester.pump(const Duration(seconds: 1));
        expect(done, 1);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets(
    'help modifiers do not skip fading and palette follows native 0..42',
    (tester) async {
      usedAudio = true;
      var done = 0;
      await tester.pumpWidget(
        MaterialApp(home: LoreHelpScreen(onHalt: () => done++)),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        tester
            .widget<Text>(find.text(LoreHelpScreen.fadingLines.first))
            .style!
            .color,
        loreVgaColor(1, 1, 1),
      );
      await tester.pump(const Duration(milliseconds: 2099));
      expect(done, 0);
      expect(find.text(LoreHelpScreen.fadingLines[1]), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text(LoreHelpScreen.fadingLines[1]), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 4300));
      expect(done, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

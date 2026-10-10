import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/logic/lore_startup_options.dart';
import 'package:lore/main.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/services/audio_manager.dart';
import 'package:lore/services/save_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/source_audio_platform.dart';

// LORE.PAS AdLib_Error<>0 selects the persistent nonmusic Main loop.
// Modern backend setup failure substitutes for unavailable legacy AdLib.
void main() {
  testWidgets(
    'failed music device setup keeps native field input and CRT tones live',
    (tester) async {
      installSourceAudioPlatform();
      SharedPreferences.setMockInitialValues({});
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      for (final channel in [
        'xyz.luan/audioplayers',
        'xyz.luan/audioplayers.global',
      ]) {
        messenger.setMockMethodCallHandler(MethodChannel(channel), (
          call,
        ) async {
          calls.add(call);
          if (call.method == 'setReleaseMode') {
            throw PlatformException(code: 'device-unavailable');
          }
          return 1;
        });
      }
      messenger.setMockStreamHandler(
        const EventChannel('xyz.luan/audioplayers.global/events'),
        MockStreamHandler.inline(onListen: (_, _) {}),
      );
      await SaveManager.instance.writeNewGame([
        PartyMember.createPreset(1),
      ], mapTitle: 'TOWN1');
      await tester.pumpWidget(
        LoreApp(startup: LoreStartupOptions.parse(['/g'])),
      );
      await tester.pump();
      await tester.pump();
      final f = find.byType(GameWidget<LoreGame>);
      await tester.runAsync(
        () => tester.state<GameWidgetState<LoreGame>>(f).loaderFuture,
      );
      await tester.pump(const Duration(milliseconds: 300));
      final game = tester.widget<GameWidget<LoreGame>>(f).game!;
      expect(AudioManager.instance.sourceMusicEnabled, false);
      expect(AudioManager.instance.currentBgm, isNull);
      expect(calls.where((call) => call.method == 'setReleaseMode').length, 1);
      expect(calls.any((call) => call.method == 'setSourceUrl'), false);
      expect(AudioManager.instance.sourceSoundEnabled, true);
      final before = (game.playerX, game.playerY);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      await tester.pump();
      expect((game.playerX, game.playerY), isNot(before));
      expect(calls.any((call) => call.method == 'setSourceBytes'), true);
      expect(
        identical(tester.widget<GameWidget<LoreGame>>(f).game, game),
        true,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      AudioManager.instance.stopSourceAudio();
      await tester.pump();
      SharedPreferences.resetStatic();
    },
  );
}

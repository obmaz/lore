import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/services/audio_manager.dart';
import 'package:lore/services/save_manager.dart';

import 'support/source_audio_platform.dart';

// LORESUB.PAS Scroll240: source tone frequency/duration through actual UI audio.
void main() {
  setUp(installSourceAudioPlatform);
  testWidgets(
    'Set_All resets SoundOn, source redraw emits5ms, Canvas frames do not',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      for (final name in [
        'xyz.luan/audioplayers',
        'xyz.luan/audioplayers.global',
      ]) {
        messenger.setMockMethodCallHandler(MethodChannel(name), (_) async => 1);
      }
      messenger.setMockStreamHandler(
        const EventChannel('xyz.luan/audioplayers.global/events'),
        MockStreamHandler.inline(onListen: (_, _) {}),
      );
      final platform =
          AudioplayersPlatformInterface.instance as SourceAudioPlatform;
      platform.sourceBytes.clear();
      AudioManager.instance.sourceSoundEnabled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: MainGameScreen(
            initialSaveData: SaveData(
              slot: 1,
              slotName: 'SOURCE',
              timestamp: DateTime.utc(1993),
              mapId: 6,
              mapTitle: 'TOWN1',
              playerX: 10,
              playerY: 10,
              gold: 2000,
              food: 20,
              party: [PartyMember.createPreset(1)],
              flags: const {},
              mapWidth: 20,
              mapHeight: 20,
              mapTiles: List.filled(400, 42),
            ),
          ),
        ),
      );
      final finder = find.byType(GameWidget<LoreGame>);
      await tester.runAsync(
        () => tester.state<GameWidgetState<LoreGame>>(finder).loaderFuture,
      );
      await tester.pump(const Duration(milliseconds: 300));
      final game = tester.widget<GameWidget<LoreGame>>(finder).game!;
      expect(AudioManager.instance.sourceSoundEnabled, isTrue);
      game.clearPeek();
      await tester.pump();
      await tester.pump();
      expect(platform.sourceBytes, isNotEmpty);
      final wave = platform.sourceBytes.last;
      final data = ByteData.sublistView(wave);
      final native = jsonDecode(
        File('test/fixtures/dos_scroll.json').readAsStringSync(),
      );
      final row = (native['cases'] as List).firstWhere((r) => r['sound']);
      final frequency = (row['trace'] as List).singleWhere(
        (op) => op[0] == 'tone',
      )[1];
      final delay = (row['trace'] as List).singleWhere(
        (op) => op[0] == 'delay',
      )[1];
      expect(frequency, 20);
      expect(data.getUint32(24, Endian.little), 8000);
      expect(data.getUint32(40, Endian.little) * 1000 ~/ 8000, delay);
      final before = platform.sourceBytes.length;
      for (var i = 0; i < 3; i++) {
        final recorder = ui.PictureRecorder();
        game.render(Canvas(recorder));
        recorder.endRecording().dispose();
      }
      await tester.pump();
      expect(platform.sourceBytes.length, before);
      AudioManager.instance.sourceSoundEnabled = false;
      game.clearPeek();
      await tester.pump();
      await tester.pump();
      expect(platform.sourceBytes.length, before);
      AudioManager.instance.sourceSoundEnabled = true;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}

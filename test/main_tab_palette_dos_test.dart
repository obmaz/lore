import 'support/source_audio_platform.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/services/save_manager.dart';
import 'package:lore/services/source_palette.dart';
import 'package:lore/widgets/lore_select_view.dart';

class _NoRandom implements Random {
  int calls = 0;
  @override
  int nextInt(int max) {
    calls++;
    return max > 1 ? 1 : 0;
  }

  @override
  bool nextBool() => throw StateError('Tab random');
  @override
  double nextDouble() => throw StateError('Tab random');
}

// LOREMAIN.PAS:192: unchanged EXE issues AX101B only for byte9.
// The modern RGB filter is an explicit adapter, not equal BIOS DAC pixels.
void main() {
  setUp(installSourceAudioPlatform);
  final data = jsonDecode(
    File('test/fixtures/dos_main_input_gates.json').readAsStringSync(),
  );
  test('native Tab request is isolated from all other input bytes', () {
    for (final row in data['tabs'] as List) {
      expect(
        row['result']['events'],
        row['byte'] == 9
            ? [
                [16, 0x101b, 0, 255],
              ]
            : [],
      );
    }
  });
  for (final size in [const Size(1280, 900), const Size(390, 844)]) {
    for (final afterView in [false, true]) {
      testWidgets(
        'Tab grayscale retains state and future modal: $size/$afterView',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          SourcePalette.instance.reset();
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            SourcePalette.instance.reset();
            LoreDialogueManager.instance.loadFlags({});
          });
          for (final channel in [
            'xyz.luan/audioplayers',
            'xyz.luan/audioplayers.global',
          ]) {
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                .setMockMethodCallHandler(
                  MethodChannel(channel),
                  (_) async => 1,
                );
          }
          final rng = _NoRandom();
          await tester.pumpWidget(
            MaterialApp(
              builder: SourcePalette.wrap,
              home: MainGameScreen(
                encounterRandom: rng,
                initialSaveData: SaveData(
                  slot: 1,
                  slotName: 'TAB',
                  timestamp: DateTime.utc(1993),
                  mapId: 6,
                  mapTitle: 'TOWN1',
                  playerX: 10,
                  playerY: 10,
                  gold: 123,
                  food: 20,
                  flags: const {},
                  party: [PartyMember.createPreset(1)],
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
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          final game = tester.widget<GameWidget<LoreGame>>(finder).game!;
          final records = [for (final p in game.partyProvider!()) p.toJson()];
          await tester.pump(const Duration(seconds: 1));
          expect(rng.calls, 0);
          expect((game.playerX, game.playerY), (10, 10));
          if (afterView) {
            await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
            await tester.pump();
            await tester.tap(find.byKey(const ValueKey('lore-select-1')));
            await tester.pump();
            expect(find.byType(LoreMessageDialog), findsOneWidget);
          }
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(SourcePalette.instance.grayscale, isTrue);
          expect(find.byKey(const ValueKey('source-palette')), findsOneWidget);
          expect(tester.widget<GameWidget<LoreGame>>(finder).game, same(game));
          expect((game.playerX, game.playerY), (10, 10));
          expect([for (final p in game.partyProvider!()) p.toJson()], records);
          expect(rng.calls, afterView ? 1 : 0);
          await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
          await tester.pump();
          expect(find.byType(LoreSelectView), findsOneWidget);
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('source-palette')),
              matching: find.byType(LoreSelectView),
            ),
            findsOneWidget,
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pump();
          expect(SourcePalette.instance.grayscale, isTrue);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}

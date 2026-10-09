import 'support/source_audio_platform.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/logic/lore_game_over.dart';
import 'package:lore/logic/lore_load_failure.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/services/save_manager.dart';
import 'package:lore/theme/retro_theme.dart';
import 'package:lore/widgets/dpad_widget.dart';
import 'package:lore/widgets/game_over_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoRandom implements Random {
  int calls = 0;
  @override
  int nextInt(int max) {
    calls++;
    throw StateError('Load must not draw RNG');
  }

  @override
  bool nextBool() => throw StateError('RNG');
  @override
  double nextDouble() => throw StateError('RNG');
}

/// LORESUB.PAS:1637-1652 Load.ErrorMessage and LORESUB.Load map failure.
/// Native CRT/BIOS/file calls are adapter boundaries, not DOS pixel equivalence.
void main() {
  setUp(installSourceAudioPlatform);
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    void silence(String name) => messenger.setMockStreamHandler(
      EventChannel(name),
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
  });
  final fixture = jsonDecode(
    File('test/fixtures/dos_load_errors.json').readAsStringSync(),
  );
  testWidgets(
    'all native ASCII file labels and need branch render correct EGA text then Halt',
    (tester) async {
      for (final row in fixture['cases']) {
        var halted = 0;
        final failure = LoreLoadFailure(row['name'], needCreate: row['need']);
        final texts = [
          for (final e in row['events'])
            if (e[0] == 'write') e[1],
        ];
        expect(failure.lines, texts);
        await tester.pumpWidget(
          MaterialApp(
            home: HaltView(
              key: UniqueKey(),
              loadFailure: failure,
              onHalt: () => halted++,
            ),
          ),
        );
        await tester.pump();
        expect(halted, 1);
        for (var i = 0; i < texts.length; i++) {
          final text = tester.widget<Text>(find.text(texts[i]));
          expect(text.style!.color, RetroTheme.ega(i == 0 ? 12 : 7));
        }
        expect(find.text(LoreGameOver.haltMessage), findsNothing);
      }
      for (var slot = 1; slot <= 4; slot++) {
        expect(
          LoreGameOver.missingSaveLines(slot),
          LoreLoadFailure('party$slot.dat', needCreate: true).lines,
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test('missing/truncated/unknown map throws a typed source failure and cannot move afterward', () async {
    for (final kind in ['missing', 'truncated', 'unknown']) {
      final rng = _NoRandom();
      var loaded = 0;
      final game = LoreGame(
        random: rng,
        onMapLoaded: () => loaded++,
        mapLoader: (name, {required category}) async {
          if (kind == 'missing') throw StateError('missing asset');
          return LoreMapData.fromBytes(
            name,
            Uint8List.fromList([100, 100, 44]),
            category: category,
          );
        },
      );
      await expectLater(
        game.loadMapById(kind == 'unknown' ? 0 : 1),
        throwsA(
          isA<LoreLoadFailure>().having(
            (e) => e.fileName,
            'file',
            kind == 'unknown' ? '.map' : 'ground1.map',
          ),
        ),
      );
      expect(loaded, 0);
      expect(rng.calls, 0);
      expect(game.currentMap, isNull);
      expect(game.tryMove(1, 0), isFalse);
      await expectLater(game.loadMapById(6), throwsA(isA<LoreLoadFailure>()));
      expect(loaded, 0);
    }
  });

  test('map parameter uses source byte width and successful Load retains its callback', () async {
    final names = <String>[];
    var loaded = 0;
    final game = LoreGame(
      initialMapId: 257,
      onMapLoaded: () => loaded++,
      mapLoader: (name, {required category}) async {
        names.add(name);
        return LoreMapData.fromBytes(
          name,
          Uint8List.fromList([10, 10, ...List.filled(100, 44)]),
          category: category,
        );
      },
    );
    expect(game.currentMapId, 1);
    await game.loadMapById(257, startX: 5, startY: 6);
    expect(names, ['GROUND1']);
    expect(loaded, 1);
    expect(
      (game.currentMapId, game.playerX, game.playerY, game.playerDirection),
      (1, 5, 6, 1),
    );
  });

  for (final size in [const Size(1280, 900), const Size(390, 844)]) {
    for (final kind in ['missing', 'truncated', 'unknown', 'arrival']) {
      testWidgets(
        'real screen $kind map failure halts without post-load continuation: $size',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            LoreDialogueManager.instance.loadFlags({});
          });
          var halted = 0;
          final rng = _NoRandom();
          final attempted = Completer<void>();
          Future<LoreMapData> loader(
            String name, {
            required String category,
          }) async {
            if (kind == 'arrival' && name == 'TOWN1') {
              return LoreMapData.loadFromAsset(name, category: category);
            }
            if (!attempted.isCompleted) {
              attempted.complete();
            }
            if (kind == 'missing' || kind == 'arrival') {
              throw StateError('asset unavailable');
            }
            return LoreMapData.fromBytes(
              name,
              Uint8List.fromList([100, 100, 44]),
              category: category,
            );
          }

          await tester.pumpWidget(
            MaterialApp(
              home: MainGameScreen(
                mapLoader: loader,
                onHalt: () => halted++,
                encounterRandom: rng,
                initialSaveData: SaveData(
                  slot: 1,
                  slotName: 'native load failure',
                  timestamp: DateTime.utc(1993),
                  mapId: kind == 'unknown'
                      ? 0
                      : kind == 'arrival'
                      ? 6
                      : 1,
                  mapTitle: '',
                  playerX: 51,
                  playerY: 31,
                  gold: 100,
                  food: 20,
                  party: [PartyMember.createPreset(1)],
                  flags: const {},
                  consumedScripts: const [],
                ),
              ),
            ),
          );
          LoreGame? game;
          var continued = false;
          if (kind == 'arrival') {
            await tester.runAsync(
              () => tester
                  .state<GameWidgetState<LoreGame>>(
                    find.byType(GameWidget<LoreGame>),
                  )
                  .loaderFuture,
            );
            await tester.pump();
            game = tester
                .widget<GameWidget<LoreGame>>(find.byType(GameWidget<LoreGame>))
                .game!;
            unawaited(
              game
                  .loadMapById(1, startX: 20, startY: 11)
                  .then((_) => continued = true),
            );
          }
          for (
            var i = 0;
            i < 50 && find.byType(HaltView).evaluate().isEmpty;
            i++
          ) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
            await tester.pump(const Duration(milliseconds: 50));
          }
          await tester.pump();
          expect(find.byType(HaltView), findsOneWidget);
          expect(
            find.text(
              kind == 'unknown'
                  ? '".map" not found.'
                  : '"ground1.map" not found.',
            ),
            findsOneWidget,
          );
          expect(find.text('You need to CREATE CHARACTER.'), findsNothing);
          expect(find.byType(DPadWidget), findsNothing);
          expect(halted, 1);
          expect(rng.calls, 0);
          expect(continued, isFalse);
          expect(attempted.isCompleted, kind != 'unknown');
          if (game != null) {
            final coordinates = (game.playerX, game.playerY);
            expect(game.tryMove(1, 0), isFalse);
            await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
            await tester.pump();
            expect((game.playerX, game.playerY), coordinates);
          }
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}

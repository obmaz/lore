import 'support/source_audio_platform.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/bgi_font_decoder.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/logic/lore_load_failure.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/widgets/dpad_widget.dart';
import 'package:lore/widgets/game_over_view.dart';

class _NoRandom implements Random {
  int calls = 0;
  @override
  int nextInt(int max) {
    calls++;
    throw StateError('font Load consumed RNG');
  }

  @override
  bool nextBool() => throw StateError('font Load consumed RNG');
  @override
  double nextDouble() => throw StateError('font Load consumed RNG');
}

/// LORESUB.PAS:1671,1752: cold CHARA and every selected region FNT are required.
/// Native file error conditions/arguments compose with ErrorMessage replay;
/// BIOS/CRT/Halt remain adapters, not BGI pixel equivalence.
void main() {
  setUp(installSourceAudioPlatform);
  TestWidgetsFlutterBinding.ensureInitialized();
  final native = jsonDecode(
    File('test/fixtures/dos_load_font_errors.json').readAsStringSync(),
  );
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
  tearDown(() => LoreDialogueManager.instance.loadFlags({}));
  BgiFontDecoder font(String name, {bool truncated = false}) {
    final raw = File('repo_source/LORE_1993_runtime/$name.FNT')
        .readAsBytesSync();
    return BgiFontDecoder(
      truncated ? Uint8List.sublistView(raw, 0, raw.length - 1) : raw,
    );
  }

  test(
    '48 native missing/short/ignored FNT cases match actual cold and warm Load',
    () async {
      expect(native['cases'], hasLength(48));
      for (final row in native['cases']) {
        var enabled = !row['warm'];
        final reads = <String>[];
        var callbacks = 0;
        final rng = _NoRandom();
        final game = LoreGame(
          initialMapId: row['mapId'],
          random: rng,
          onMapLoaded: () => callbacks++,
          fontLoader: (name) async {
            reads.add('${name.toLowerCase()}.fnt');
            if (enabled && '${name.toLowerCase()}.fnt' == row['target']) {
              if (row['mode'] == 'missing') throw StateError('missing FNT');
              return font(name, truncated: true);
            }
            return font(name);
          },
        );
        if (row['warm']) {
          await game.onLoad();
          enabled = true;
          reads.clear();
          callbacks = 0;
        }
        final chara = game.charaFont;
        final operation = row['warm']
            ? game.loadMapById(row['mapId'])
            : game.onLoad();
        if (row['error'] == null) {
          await operation;
          expect(callbacks, 1);
          if (row['warm']) expect(identical(game.charaFont, chara), isTrue);
        } else {
          await expectLater(
            operation,
            throwsA(
              isA<LoreLoadFailure>()
                  .having(
                    (e) => e.fileName,
                    'native filename',
                    row['error']['name'],
                  )
                  .having(
                    (e) => e.needCreate,
                    'native need',
                    row['error']['need'],
                  ),
            ),
          );
          expect(callbacks, 0);
          expect(game.tryMove(1, 0), isFalse);
          await expectLater(
            game.loadMapById(row['mapId']),
            throwsA(isA<LoreLoadFailure>()),
          );
        }
        expect(rng.calls, 0);
        expect(reads, [
          for (final event in row['events'])
            if (event[0] == 'openAttempt' &&
                (event[1] as String).endsWith('.fnt'))
              event[1],
        ]);
      }
    },
  );
  test('one source font record ignores trailing bytes and only selects the active region', () async {
    final calls = <String>[];
    final game = LoreGame(
      initialMapId: 14,
      fontLoader: (name) async {
        calls.add(name);
        final raw = font(name).data;
        return BgiFontDecoder(Uint8List.fromList([...raw, 1, 2, 3]));
      },
    );
    await game.onLoad();
    expect(calls, ['CHARA', 'DEN']);
    expect(game.charaFont!.data, font('CHARA').data);
    expect(game.selectedTileFont!.data, font('DEN').data);
    expect(game.townFont, isNull);
    expect(game.groundFont, isNull);
    expect(game.keepFont, isNull);
  });
  for (final size in [const Size(1280, 900), const Size(390, 844)]) {
    for (final target in ['CHARA', 'TOWN', 'DEN']) {
      for (final mode in ['missing', 'truncated']) {
        testWidgets('required $target/$mode halts real screen: $size', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var halted = 0;
          var continued = false;
          final rng = _NoRandom();
          await tester.pumpWidget(
            MaterialApp(
              home: MainGameScreen(
                encounterRandom: rng,
                onHalt: () => halted++,
                fontLoader: (name) async {
                  if (name == target) {
                    if (mode == 'missing') throw StateError('missing FNT');
                    return font(name, truncated: true);
                  }
                  return font(name);
                },
              ),
            ),
          );
          LoreGame? game;
          if (target == 'DEN') {
            final finder = find.byType(GameWidget<LoreGame>);
            await tester.runAsync(
              () =>
                  tester.state<GameWidgetState<LoreGame>>(finder).loaderFuture,
            );
            game = tester.widget<GameWidget<LoreGame>>(finder).game!;
            unawaited(game.loadMapById(14).then((_) => continued = true));
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
            find.text('"${target.toLowerCase()}.fnt" not found.'),
            findsOneWidget,
          );
          expect(find.text('You need to CREATE CHARACTER.'), findsNothing);
          expect(find.byType(DPadWidget), findsNothing);
          expect(halted, 1);
          expect(continued, isFalse);
          expect(rng.calls, 0);
          if (game != null) {
            expect(game.tryMove(1, 0), isFalse);
            final position = (game.playerX, game.playerY);
            await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
            await tester.pump();
            expect((game.playerX, game.playerY), position);
          }
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }
}

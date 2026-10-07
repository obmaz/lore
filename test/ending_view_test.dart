import 'dart:math';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_end.dart';
import 'package:lore/logic/lore_random.dart';
import 'package:lore/widgets/ending_view.dart';

/// LOREEND.PAS `End_Demo` flow: fades ignore keys, Esc leaves the thunder and
/// staff screens, and the closing text screen waits (`Halt`) for a key.
void main() {
  Future<EndingViewState> open(
    WidgetTester tester,
    VoidCallback onFinish, {
    Random? random,
    bool initialKeyWasEscape = false,
  }) async {
    for (final channel in [
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers.global',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), (_) async => 1);
    }
    await tester.pumpWidget(
      MaterialApp(
        home: EndingView(
          heroName: '용사',
          onFinish: onFinish,
          random: random ?? Random(5),
          initialKeyWasEscape: initialKeyWasEscape,
        ),
      ),
    );
    return tester.state<EndingViewState>(find.byType(EndingView));
  }

  Future<void> run(WidgetTester tester, int ms) async {
    for (var elapsed = 0; elapsed < ms; elapsed += 16) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  final native = jsonDecode(
    File('test/fixtures/dos_ending_input.json').readAsStringSync(),
  );
  for (final row in native['cases']) {
    if (row['closed'] != true) continue;
    testWidgets(
      'compiled ThunderEffect seed ${row['seed']}, inherited c ${row['initialKey']}, keys ${row['keys']}',
      (tester) async {
        final random = LoreRandom(row['seed']);
        final state = await open(
          tester,
          () {},
          random: random,
          initialKeyWasEscape: row['initialKey'] == 27,
        );
        for (final key in row['keys']) {
          await tester.sendKeyEvent(switch (key) {
            27 => LogicalKeyboardKey.escape,
            13 => LogicalKeyboardKey.enter,
            _ => LogicalKeyboardKey.keyA,
          });
        }
        await run(tester, 2800);
        expect(state.phase, EndPhase.staff);
        expect(random.seed, row['afterSeed']);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  final staffNative = jsonDecode(
    File('test/fixtures/dos_ending_staff.json').readAsStringSync(),
  );
  for (var index = 0; index < staffNative['cases'].length; index++) {
    final row = staffNative['cases'][index];
    if (row['closed'] != true) continue;
    testWidgets(
      'compiled staff loop case $index, every sprite and final delay',
      (tester) async {
        final state = await open(tester, () {}, initialKeyWasEscape: true);
        while (state.phase != EndPhase.staff) {
          await tester.pump(const Duration(milliseconds: 1));
        }
        for (final key in row['keys']) {
          await tester.sendKeyEvent(switch (key) {
            27 => LogicalKeyboardKey.escape,
            13 => LogicalKeyboardKey.enter,
            _ => LogicalKeyboardKey.keyA,
          });
        }
        for (var frame = 0; frame < row['frames'].length; frame++) {
          await tester.pump(Duration(milliseconds: frame == 0 ? 1 : 200));
          expect(state.phase, EndPhase.staff);
          final nativeFrame = row['frames'][frame];
          expect(state.walkerFrame!.y, nativeFrame['y']);
          expect(state.walkerFrame!.sprite, nativeFrame['sprite']);
        }
        await tester.pump(const Duration(milliseconds: 199));
        expect(state.phase, EndPhase.staff);
        await tester.pump(const Duration(milliseconds: 1));
        expect(state.phase, EndPhase.outroFadeUp);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'farewell Esc survives the fades, one thunder iteration, and staff resets c',
    (tester) async {
      final random = _RecordedRandom();
      final state = await open(
        tester,
        () {},
        random: random,
        initialKeyWasEscape: true,
      );
      await run(tester, 2800);
      expect(state.phase, EndPhase.staff);
      expect(random.bounds, [1000]);
      await run(tester, 500);
      expect(state.phase, EndPhase.staff);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'ThunderEffect reads queued keys in FIFO order after random, then drains staff input',
    (tester) async {
      final random = _RecordedRandom();
      final state = await open(tester, () {}, random: random);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await run(tester, 2800);
      expect(state.phase, EndPhase.staff);
      expect(random.bounds, [1000, 1000]);
      await run(tester, 500);
      expect(state.phase, EndPhase.staff);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'new buffered key replaces inherited Esc before the until guard',
    (tester) async {
      final random = _RecordedRandom();
      final state = await open(
        tester,
        () {},
        random: random,
        initialKeyWasEscape: true,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await run(tester, 2800);
      expect(state.phase, EndPhase.message);
      final before = random.bounds.length;
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 16));
      expect(state.phase, EndPhase.staff);
      expect(random.bounds.length, before + 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'thunder flash delay precedes the inherited Esc read and consumes no extra random',
    (tester) async {
      final random = _RecordedRandom([0, 0, 30]);
      final state = await open(
        tester,
        () {},
        random: random,
        initialKeyWasEscape: true,
      );
      while (random.bounds.isEmpty) {
        await tester.pump(const Duration(milliseconds: 1));
      }
      expect(random.bounds, [1000, 100, 100]);
      expect(state.phase, EndPhase.message);
      await tester.pump(const Duration(milliseconds: 49));
      expect(state.phase, EndPhase.message);
      await tester.pump(const Duration(milliseconds: 1));
      expect(state.phase, EndPhase.staff);
      expect(random.bounds, [1000, 100, 100]);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'staff reads one FIFO key per walking frame and delays after Esc',
    (tester) async {
      final state = await open(tester, () {}, initialKeyWasEscape: true);
      while (state.phase != EndPhase.staff) {
        await tester.pump(const Duration(milliseconds: 1));
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 1));
      expect(state.walkerFrame!.y, 2);
      expect(state.phase, EndPhase.staff);
      await tester.pump(const Duration(milliseconds: 199));
      expect(state.walkerFrame!.y, 2);
      expect(state.phase, EndPhase.staff);
      await tester.pump(const Duration(milliseconds: 1));
      expect(state.walkerFrame!.y, 4);
      expect(state.phase, EndPhase.staff);
      await tester.pump(const Duration(milliseconds: 199));
      expect(state.phase, EndPhase.staff);
      await tester.pump(const Duration(milliseconds: 1));
      expect(state.phase, EndPhase.outroFadeUp);
      // The Esc iteration is drawn and its mandatory delay completes before text mode.
      expect(state.walkerFrame!.y, 4);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('fade, thunder, staff, closing screen and Halt', (tester) async {
    var finished = 0;
    final state = await open(tester, () => finished++);
    expect(state.phase, EndPhase.fadeIn);
    await run(tester, 1100);
    expect(state.phase, EndPhase.fadeOut);
    await run(tester, 1000);
    expect(state.phase, EndPhase.message);
    expect(EndingView.epilogueTexts.length, 11);

    // Only Esc leaves the thunder screen; other keys are read and dropped.
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await run(tester, 600);
    expect(state.phase, EndPhase.message);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await run(tester, 100);
    expect(state.phase, EndPhase.staff);
    await run(tester, 700);
    // 200 ms per frame: sprites 24, 21, 24, 20 and y += 2 each.
    expect(state.walkerFrame!.y, 8);
    expect(state.walkerFrame!.sprite, 20);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await run(tester, 420);
    expect(state.phase, EndPhase.outroFadeUp);
    await run(tester, 2500);
    expect(state.phase, EndPhase.halted);
    expect(state.ramp15, LoreEnd.outroFadeTo);
    expect(state.ramp7, LoreEnd.outroDimTo);
    expect(finished, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    expect(finished, 1);
  });

  testWidgets('an Esc typed during the fade stays in the key buffer', (
    tester,
  ) async {
    final state = await open(tester, () {});
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await run(tester, 1400);
    expect(state.phase, EndPhase.fadeOut);
    while (state.phase != EndPhase.message) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    // The four RGB flashes (40 + 100 + 100 ms) always run to the end ...
    await run(tester, 160);
    expect(state.phase, EndPhase.message);
    // ... then the first ThunderEffect iteration reads the buffered Esc.
    await run(tester, 200);
    expect(state.phase, EndPhase.staff);
  });

  testWidgets('closing palette waits after its final writes before Halt', (
    tester,
  ) async {
    var finished = 0;
    final state = await open(tester, () => finished++);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    while (state.phase != EndPhase.staff) {
      await tester.pump(const Duration(milliseconds: 1));
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    while (state.phase == EndPhase.staff) {
      await tester.pump(const Duration(milliseconds: 1));
    }
    expect(state.phase, EndPhase.outroFadeUp);
    await tester.pump(const Duration(milliseconds: 620));
    expect(state.ramp15, 63);
    expect(state.phase, EndPhase.outroFadeUp);
    await tester.pump(const Duration(milliseconds: 10));
    expect(state.phase, EndPhase.outroHold);
    await tester.pump(const Duration(milliseconds: 499));
    expect(state.phase, EndPhase.outroHold);
    await tester.pump(const Duration(milliseconds: 1));
    expect(state.phase, EndPhase.outroDim);
    await tester.pump(const Duration(milliseconds: 300));
    expect(state.ramp7, 42);
    expect(state.phase, EndPhase.outroDim);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    expect(finished, 0);
    await tester.pump(const Duration(milliseconds: 14));
    expect(state.phase, EndPhase.outroDim);
    await tester.pump(const Duration(milliseconds: 1));
    expect(state.phase, EndPhase.halted);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    expect(finished, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'the message page stays visible during thunder; staff only after Esc',
    (tester) async {
      final state = await open(tester, () {});
      while (state.phase != EndPhase.message) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await run(tester, 2000);
      expect(state.phase, EndPhase.message);
      expect(state.walkerFrame, isNull);
      expect(state.erasedRows, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('thunder opening flashes the shadow colour then restores it', (
    tester,
  ) async {
    final state = await open(tester, () {});
    while (state.phase != EndPhase.message) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    // RGB(6,10,20,63); delay(40); RGB(6,40,20,0); delay(100); RGB(6,10,20,63); ...
    expect(state.shadowFlash, LoreEnd.thunderFlash);
    await run(tester, 80);
    expect(state.shadowFlash, LoreEnd.thunderBase);
    await run(tester, 120);
    expect(state.shadowFlash, LoreEnd.thunderFlash);
    await run(tester, 120);
    expect(state.shadowFlash, LoreEnd.thunderBase);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _RecordedRandom implements Random {
  _RecordedRandom([this.values = const []]);
  final List<int> values;
  final List<int> bounds = [];
  @override
  int nextInt(int max) {
    final index = bounds.length;
    bounds.add(max);
    return index < values.length ? values[index] : 1;
  }

  @override
  bool nextBool() => throw UnsupportedError('Unexpected random bool');
  @override
  double nextDouble() => throw UnsupportedError('Unexpected random double');
}

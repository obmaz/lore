import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_end.dart';
import 'package:lore/widgets/ending_view.dart';

/// LOREEND.PAS `End_Demo` flow: fades ignore keys, Esc leaves the thunder and
/// staff screens, and the closing text screen waits (`Halt`) for a key.
void main() {
  Future<EndingViewState> open(
    WidgetTester tester,
    VoidCallback onFinish,
  ) async {
    for (final channel in [
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers.global',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), (_) async => 1);
    }
    await tester.pumpWidget(
      MaterialApp(
        home: EndingView(heroName: '용사', onFinish: onFinish, random: Random(5)),
      ),
    );
    return tester.state<EndingViewState>(find.byType(EndingView));
  }

  Future<void> run(WidgetTester tester, int ms) async {
    for (var elapsed = 0; elapsed < ms; elapsed += 16) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

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
    await tester.pump(const Duration(milliseconds: 16));
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

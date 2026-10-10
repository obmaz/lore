import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_creation_palette.dart';
import 'package:lore/logic/lore_creation_rules.dart';
import 'package:lore/widgets/lore_creation_animation.dart';

// LORECRET.PAS Display/First/Second/Third/Fourth; original EXE RGB/poll traces.
void main() {
  final native = jsonDecode(
    File('test/fixtures/dos_creation_palette.json').readAsStringSync(),
  );
  for (final row in native['cases']) {
    test('${row['kind']} false polls ${row['falsePolls']}', () {
      final kind = row['kind'];
      final int polls = row['falsePolls'];
      final frames = switch (kind) {
        'displayBorder' => LoreCreationPalette.displayBorder,
        'displayTitle' => LoreCreationPalette.displayTitle,
        'divider' => LoreCreationPalette.divider,
        _ => <LoreCreationPaletteFrame>[],
      };
      final trace = <List<Object?>>[];
      for (final frame in frames) {
        for (final rgb in frame.colors) {
          trace.add(['rgb', rgb.$1, rgb.$2, rgb.$3, rgb.$4]);
        }
        trace.add(['delay', frame.milliseconds]);
      }
      if (kind == 'classPulse' || kind == 'confirmationPulse') {
        final select = LoreCreationClassPulse();
        final confirm = LoreCreationConfirmationPulse();
        for (var i = 0; i <= polls; i++) {
          final value = kind == 'classPulse' ? select.next() : confirm.next();
          trace.add(['rgb', kind == 'classPulse' ? 7 : 8, value, value, value]);
          trace.add(['delay', kind == 'classPulse' ? 10 : 50]);
          trace.add(['ready', i == polls]);
        }
      }
      if (kind.endsWith('Wait')) {
        for (var i = 0; i <= polls; i++) {
          trace.add(['ready', i == polls]);
        }
      }
      if (kind == 'quizReset') {
        final scratch = List<int>.filled(12, 255);
        LoreCreationRules.resetQuiz(scratch);
        expect(scratch.take(11), (row['reset'] as List).take(11));
      }
      if (kind == 'companionReset') {
        expect((row['reset'] as List).sublist(1, 11), List.filled(10, 0));
        expect(row['reset'][0], 255);
        expect(row['reset'][11], 10); // Adjacent native i, outside transdata.
      }
      expect(trace, row['trace']);
    });
  }
  for (final mode in ['display', 'divider']) {
    testWidgets('source $mode Delay cannot complete early and retains keys', (
      tester,
    ) async {
      var done = 0;
      final keys = <KeyEvent>[];
      final frames = mode == 'display'
          ? LoreCreationPalette.display
          : LoreCreationPalette.divider;
      await tester.pumpWidget(
        MaterialApp(
          home: LoreCreationAnimation(
            frames: frames,
            builder: (colors) => Container(color: colors[9] ?? colors[8]),
            onComplete: () => done++,
            onKey: keys.add,
          ),
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'a');
      await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
      final duration = frames.fold(0, (a, b) => a + b.milliseconds);
      await tester.pump(Duration(milliseconds: duration - 1));
      expect(done, 0);
      expect(keys.length, 1);
      await tester.pump(const Duration(milliseconds: 1));
      expect(done, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('Third source pulse freezes during its rejected-choice delay', (
    tester,
  ) async {
    Color? color;
    Widget view(bool paused) => MaterialApp(
      home: LoreCreationPulse(
        confirmation: false,
        paused: paused,
        builder: (c) {
          color = c;
          return const SizedBox();
        },
      ),
    );
    await tester.pumpWidget(view(false));
    await tester.pump(const Duration(milliseconds: 100));
    final frozen = color;
    await tester.pumpWidget(view(true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(color, frozen);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

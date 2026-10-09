import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_title_flow.dart';
import 'package:lore/widgets/lore_title_intro.dart';
import 'package:lore/widgets/lore_guide_dialog.dart';

// LOREHELP.PAS Box/MessageBox/title repeat loops/Scroll_Sub: original EXE.
void main() {
  final data = jsonDecode(
    File('test/fixtures/dos_title_intro.json').readAsStringSync(),
  );
  test('all 25 original EXE paragraphs are reused without rewriting', () {
    expect([
      ...LoreGuideDialog.authorPreface,
      ...List.filled(8, ''),
    ], data['paragraphs']);
  });
  for (final row in data['cases'] as List) {
    final kind = row['kind'];
    if (kind == 'scroll') continue;
    test(
      'native $kind ${row['falsePolls']} ${row['shadow']} ${row['bold']}',
      () {
        var polls = 0;
        final operations = switch (kind) {
          'box' => LoreTitleFlow.box(
            30,
            45,
            510,
            590,
            4,
            shadow: row['shadow'],
            bold: row['bold'],
          ),
          'messageBox' => LoreTitleFlow.messageBox(
            30,
            45,
            510,
            590,
            4,
            shadow: row['shadow'],
          ),
          'nestedBox' => LoreTitleFlow.nestedBox(),
          'nestedMessageBox' => LoreTitleFlow.nestedMessageBox(),
          'lift' => LoreTitleFlow.lift(),
          'story' => LoreTitleFlow.story(() => polls++ >= row['falsePolls']),
          _ => throw StateError('$kind'),
        };
        final expected = [
          for (final line in row['trace'])
            [for (final v in line) v is bool ? (v ? 1 : 0) : v],
        ];
        expect([for (final op in operations) op.trace], expected);
      },
    );
  }
  test('native REP MOVSB plane bytes match live indexed title scrolling', () {
    for (final mode in [0, 1]) {
      final row = (data['cases'] as List).singleWhere(
        (r) => r['kind'] == 'scroll' && r['mode'] == mode,
      );
      final expected = base64Decode(row['plane']);
      final surface = LoreTitleSurface();
      for (var i = 0; i < 38400; i++) {
        final value = (i * 37 ^ (i >> 8)) & 255;
        for (var bit = 0; bit < 8; bit++) {
          surface.pixels[i * 8 + bit] = (value >> (7 - bit)) & 1;
        }
      }
      surface.scroll(mode);
      for (var i = 0; i < 38400; i++) {
        var packed = 0;
        for (var bit = 0; bit < 8; bit++) {
          packed |= surface.pixels[i * 8 + bit] << (7 - bit);
        }
        expect(packed, expected[i], reason: 'mode=$mode byte=$i');
      }
    }
    final surface = LoreTitleSurface()..pixels[12345] = 7;
    for (var mode = 2; mode <= 255; mode++) {
      surface.scroll(mode);
    }
    expect(surface.pixels[12345], 7);
    expect(surface.pixels.where((v) => v != 0), [7]);
  });
  testWidgets('source intro completes after 610+52420ms, never early', (
    tester,
  ) async {
    var done = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: LoreTitleIntro(onComplete: () => done++, onKey: (_) {}),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 53029));
    expect(done, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(done, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(done, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'key during lift skips story at native first poll and remains queued',
    (tester) async {
      var done = 0;
      final keys = <LogicalKeyboardKey>[];
      await tester.pumpWidget(
        MaterialApp(
          home: LoreTitleIntro(
            onComplete: () => done++,
            onKey: (event) => keys.add(event.logicalKey),
          ),
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.pump(const Duration(milliseconds: 609));
      expect(done, 0);
      expect(keys, [LogicalKeyboardKey.digit1]);
      await tester.pump(const Duration(milliseconds: 1));
      expect(done, 1);
      expect(keys, [LogicalKeyboardKey.digit1]);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

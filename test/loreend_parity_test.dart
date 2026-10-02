import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_end.dart';

/// LOREEND.PAS `End_Demo` constants against `tool/source_loreend.py`.
void main() {
  final fixture = jsonDecode(
    File('test/fixtures/loreend_parity.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  test('FadeSub palette matches the Pascal div expressions for every step', () {
    final table = (fixture['fade'] as Map)['table'] as Map<String, dynamic>;
    for (final entry in table.entries) {
      final adder = int.parse(entry.key);
      final rows = entry.value as List;
      for (var color = 0; color <= 14; color++) {
        final (r, g, b) = LoreEnd.fadeColor(color, adder);
        expect([r, g, b], rows[color], reason: 'color $color adder $adder');
      }
    }
    expect(LoreEnd.fadeInAdders.first, 0);
    expect(LoreEnd.fadeInAdders.last, 310);
    expect(LoreEnd.fadeOutAdders.first, 310);
    expect(LoreEnd.fadeOutAdders.last, 0);
    expect(LoreEnd.fadeInAdders.length, 32);
  });

  test('EndMessage lines, colour and positions', () {
    final message = fixture['message'] as Map<String, dynamic>;
    expect(LoreEnd.messageColor, message['color']);
    final lines = message['lines'] as List;
    expect(LoreEnd.messageLines.length, lines.length);
    for (var i = 0; i < lines.length; i++) {
      final (x, y, s) = LoreEnd.messageLines[i];
      expect([x, y, s], lines[i]);
    }
  });

  test('StaffMessage draw list in source order', () {
    final staff = fixture['staff'] as Map<String, dynamic>;
    final ops = staff['ops'] as List;
    expect(LoreEnd.spriteMaskOffset, staff['putSpriteMaskOffset']);
    expect(LoreEnd.backgroundTile, staff['tile']);
    expect(LoreEnd.staffOps.length, ops.length);
    for (var i = 0; i < ops.length; i++) {
      final want = ops[i] as List;
      final got = LoreEnd.staffOps[i];
      switch (want[0]) {
        case 'color':
          expect([got.kind, got.a], ['color', want[1]]);
        case 'bold':
          expect(
            [got.kind, got.a, got.b, got.text],
            ['bold', want[1], want[2], want[3]],
          );
        case 'sprite':
          expect(
            [got.kind, got.a, got.b, got.c],
            ['sprite', want[1], want[2], want[3]],
          );
        case 'text':
          expect(
            [got.kind, got.a, got.b, got.text],
            ['text', want[1], want[2], want[3]],
          );
          expect(got.hero, want.length == 5);
          if (want.length == 5) expect(got.after, want[4]);
      }
    }
    expect(LoreEnd.staffOps[4].resolve('용사'), '이름은 용사. 바로 당신이다.');
  });

  test('thunder, opening flashes and the walking sprite loop', () {
    final thunder = fixture['thunder'] as Map<String, dynamic>;
    expect([
      LoreEnd.thunderBase.$1,
      LoreEnd.thunderBase.$2,
      LoreEnd.thunderBase.$3,
    ], thunder['base']);
    expect([
      LoreEnd.thunderFlash.$1,
      LoreEnd.thunderFlash.$2,
      LoreEnd.thunderFlash.$3,
    ], thunder['flash']);
    final flashes = fixture['openingFlashes'] as List;
    for (var i = 0; i < flashes.length; i++) {
      final (c, d) = LoreEnd.openingFlashes[i];
      expect([c.$1, c.$2, c.$3], flashes[i]['color']);
      expect(d, flashes[i]['delayMs']);
    }
    final walker = fixture['walker'] as Map<String, dynamic>;
    expect(
      [
        LoreEndWalker.x,
        LoreEndWalker.wrapAbove,
        LoreEndWalker.step,
        LoreEndWalker.delayMs,
      ],
      [walker['x'], walker['wrapAbove'], walker['step'], walker['delayMs']],
    );
    final w = LoreEndWalker();
    expect([w.j, w.i], [walker['startJ'], walker['startI']]);
    for (final want in fixture['walkerFrames'] as List) {
      final f = w.frame();
      expect([f.y, f.sprite], want);
    }
    // After y > 350 the position wraps to 0 + 2 and erases the row of the old y.
    final late = LoreEndWalker()..y = 352;
    final f = late.frame();
    expect([f.eraseRow, f.y], [17, 2]);
  });

  test(
    'ThunderEffect draws random(1000) then random(100) then random(100)+20',
    () {
      final a = Random(11);
      final b = Random(11);
      var flashes = 0;
      for (var n = 0; n < 2000000 && flashes < 3; n++) {
        final got = LoreEndThunder.iterate(a);
        var want = -1;
        if (b.nextInt(1000) == 0 && b.nextInt(100) == 0) {
          want = b.nextInt(100) + 20;
        }
        expect(got ?? -1, want);
        if (got != null) {
          flashes++;
          expect(got, inInclusiveRange(20, 119));
        }
      }
      expect(flashes, 3);
    },
  );

  test('closing text screen and its palette ramps', () {
    final outro = fixture['outro'] as Map<String, dynamic>;
    expect(LoreEnd.outroLines, outro['lines']);
    expect(LoreEnd.outroColors, outro['colors']);
    expect(LoreEnd.outroBlankLines, outro['blankLinesBefore']);
    expect(
      [LoreEnd.outroFadeTo, LoreEnd.outroFadeDelayMs, LoreEnd.outroHoldMs],
      [outro['fadeUpTo'], outro['fadeDelayMs'], outro['holdMs']],
    );
    expect(
      [LoreEnd.outroDimFrom, LoreEnd.outroDimTo, LoreEnd.outroDimDelayMs],
      [outro['dimFrom'], outro['dimTo'], outro['dimDelayMs']],
    );
  });
}

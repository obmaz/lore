import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_main_input.dart';
import 'package:lore/widgets/lore_select_view.dart';
import 'package:lore/theme/retro_theme.dart';
import 'package:lore/widgets/lore_source_text.dart';

// LORESUB.PAS PressAnyKey/Clear: discard pending bytes, read one key (or
// both extended-key bytes), then clear both source pages. Flutter dispatch
// represents extended keys atomically and has no application ReadKey queue.
void main() {
  final data = jsonDecode(
    File('test/fixtures/dos_common_screen.json').readAsStringSync(),
  );
  final keys = <int, LogicalKeyboardKey>{
    13: LogicalKeyboardKey.enter,
    27: LogicalKeyboardKey.escape,
    32: LogicalKeyboardKey.space,
    9: LogicalKeyboardKey.tab,
    8: LogicalKeyboardKey.backspace,
    97: LogicalKeyboardKey.keyA,
    72: LogicalKeyboardKey.arrowUp,
    80: LogicalKeyboardKey.arrowDown,
    75: LogicalKeyboardKey.arrowLeft,
    77: LogicalKeyboardKey.arrowRight,
  };
  for (final row in data['wait']) {
    testWidgets(
      'native wait page=${row['page']} pending=${row['pending']} fresh=${row['fresh']}',
      (tester) async {
        final input = LoreMainInput();
        var completed = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => input.run(() async {
                    await showLoreMessageDialog(
                      context,
                      lines: const [(12, 'SOURCE')],
                    );
                    completed++;
                  }),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        for (final old in row['pending']) {
          if (keys[old] != null) await tester.sendKeyEvent(keys[old]!);
        }
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(completed, 0);
        expect(find.byType(LoreMessageDialog), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
        expect(completed, 0);
        final code = row['c'] as int;
        expect((row['fresh'] as List).last, code);
        await tester.sendKeyEvent(keys[code]!);
        await tester.pumpAndSettle();
        expect(completed, 1);
        expect(find.byType(LoreMessageDialog), findsNothing);
        expect(input.lastKeyWasEscape, code == 27);
        expect(input.lastKeyWasSpace, code == 32);
        expect(input.lastKeyWasBackspace, code == 8);
        expect(input.lastKeyWasTab, code == 9);
        expect(row['afterPage'], row['page']);
        expect(row['yline'], 30);
        expect(row['hany'], 32);
      },
    );
  }
  for (final overlay in [false, true]) {
    testWidgets(
      'repeat after activation acknowledges but hardware toggles do not: overlay=$overlay',
      (tester) async {
        final wait = LoreKeyWait();
        var done = 0;
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    if (overlay) {
                      final result = wait.next();
                      showLoreKeyWaitOverlay(
                        context,
                        wait: wait,
                        lines: const [(14, 'SOURCE')],
                      );
                      await result;
                      Navigator.of(context).pop();
                    } else {
                      await showLoreMessageDialog(
                        context,
                        lines: const [(14, 'SOURCE')],
                      );
                    }
                    done++;
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        for (final key in [
          LogicalKeyboardKey.shiftLeft,
          LogicalKeyboardKey.controlLeft,
          LogicalKeyboardKey.altLeft,
          LogicalKeyboardKey.metaLeft,
          LogicalKeyboardKey.capsLock,
          LogicalKeyboardKey.numLock,
          LogicalKeyboardKey.scrollLock,
        ]) {
          await tester.sendKeyEvent(key);
          await tester.pump();
          expect(done, 0);
        }
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyA);
        await tester.pumpAndSettle();
        expect(done, 1);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  for (final row in data['print']) {
    if (row['kind'] == 'cprint') {
      testWidgets(
        'native cPrint appends three colors in one row ${row['page']}/${row['hany']}',
        (tester) async {
          final text = (row['parts'] as List).join();
          await tester.pumpWidget(
            MaterialApp(home: loreSourceText(text, RetroTheme.dosFont)),
          );
          final rendered = tester.widget<Text>(find.byType(Text));
          final spans = (rendered.textSpan! as TextSpan).children!
              .cast<TextSpan>()
              .toList();
          final nativeText = [
            for (final op in row['trace'])
              if (op[0] == 'text') op[1],
          ];
          final nativeColors = [
            for (final op in row['trace'])
              if (op[0] == 'color') RetroTheme.ega(op[1]),
          ];
          expect(spans.map((span) => span.text), nativeText);
          expect(spans.map((span) => span.style!.color), nativeColors);
          expect(
            [
              for (final op in row['trace'])
                if (op[0] == 'goto') op,
            ],
            [
              ['goto', 250, row['hany'] + 16],
            ],
          );
          expect(row['afterHany'], row['hany'] + 16);
        },
      );
    } else if (row['kind'] == 'message') {
      testWidgets(
        'native message pages project to one modern frame ${row['page']}/${row['hany']}',
        (tester) async {
          final nativeText = [
            for (final op in row['trace'])
              if (op[0] == 'text') op[1],
          ];
          expect(nativeText, ['SOURCE', 'SOURCE']);
          expect(row['afterPage'], row['page']);
          expect(row['afterHany'], 48);
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(body: LoreMessageDialog(lines: [(12, 'SOURCE')])),
            ),
          );
          expect(find.text('SOURCE'), findsOneWidget);
          expect(
            tester.widget<Text>(find.text('SOURCE')).style!.color,
            RetroTheme.ega(12),
          );
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/theme/retro_theme.dart';
import 'package:lore/logic/lore_main_input.dart';
import 'package:lore/widgets/lore_select_view.dart';

/// LORESUB.PAS `Select`: cursor starts at 1, wraps inside 1..maxsum,
/// Enter/Space return k, Esc returns 0, items past maxsum use color 0.
void main() {
  test(
    'key waits preserve Space and replace it with the latest read',
    () async {
      final input = LoreMainInput();
      final wait = LoreKeyWait();
      await input.run(() async {
        var pending = wait.next();
        wait.press(space: true);
        expect(await pending, false);
        expect(input.lastKeyWasSpace, true);
        pending = wait.next();
        wait.press(backspace: true);
        expect(await pending, false);
        expect(input.lastKeyWasBackspace, true);
        expect(input.lastKeyWasSpace, false);
        pending = wait.next();
        wait.press(escape: true);
        expect(await pending, true);
        expect(input.lastKeyWasSpace, false);
        expect(input.lastKeyWasEscape, true);
        pending = wait.next();
        wait.press();
        expect(await pending, false);
        expect(input.lastKeyWasSpace, false);
        expect(input.lastKeyWasEscape, false);
      });
      expect(LoreMainInput.current, isNull);
    },
  );
  testWidgets(
    'message acknowledgement records the actual Space, arrow or tap',
    (tester) async {
      final input = LoreMainInput();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => input.run(
                () => showLoreMessageDialog(
                  context,
                  lines: const [(7, 'Native wait')],
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      for (final key in [
        LogicalKeyboardKey.space,
        LogicalKeyboardKey.backspace,
        LogicalKeyboardKey.arrowDown,
        null,
      ]) {
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        if (key == null) {
          await tester.tap(find.text('Native wait'));
        } else {
          await tester.sendKeyEvent(key);
        }
        await tester.pumpAndSettle();
        expect(input.lastKeyWasSpace, key == LogicalKeyboardKey.space);
        expect(input.lastKeyWasBackspace, key == LogicalKeyboardKey.backspace);
        expect(input.lastKeyWasEscape, false);
      }
    },
  );
  testWidgets('Select keeps keyboard Space and normalizes touch to Enter', (
    tester,
  ) async {
    final input = LoreMainInput();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => input.run(() async {
              await showLoreSelectDialog(
                context,
                title: 'Native Select',
                items: const ['Pick'],
              );
            }),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    for (final key in [
      LogicalKeyboardKey.space,
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.escape,
      null,
    ]) {
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      if (key == null) {
        await tester.tap(find.text('Pick'));
      } else {
        await tester.sendKeyEvent(key);
      }
      await tester.pumpAndSettle();
      expect(input.lastKeyWasSpace, key == LogicalKeyboardKey.space);
      expect(input.lastKeyWasBackspace, key == LogicalKeyboardKey.backspace);
      expect(input.lastKeyWasEscape, key == LogicalKeyboardKey.escape);
    }
  });
  testWidgets('long speech and Select fit a short landscape display', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    int? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              selected = await showLoreSelectDialog(
                context,
                title: '',
                items: const ['수락', '거절'],
                lines: [for (var i = 0; i < 30; i++) (7, '대사 $i')],
              );
            },
            child: const Text('열기'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selected, 2);
  });

  Future<List<int>> pump(WidgetTester tester, {int? maxsum}) async {
    final picked = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoreSelectView(
            title: '선택',
            items: const ['A', 'B', 'C', 'D'],
            maxsum: maxsum,
            onSelected: picked.add,
          ),
        ),
      ),
    );
    await tester.pump();
    return picked;
  }

  Color colorOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style!.color!;

  testWidgets('up from 1 wraps to maxsum; Enter returns it', (tester) async {
    final picked = await pump(tester, maxsum: 3);
    expect(colorOf(tester, 'A'), RetroTheme.ega(15));
    expect(colorOf(tester, 'D'), RetroTheme.ega(0));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(colorOf(tester, 'C'), RetroTheme.ega(15));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(picked, [1]);
  });

  testWidgets('Esc returns 0 and a tap past maxsum is ignored', (tester) async {
    final picked = await pump(tester, maxsum: 2);
    await tester.tap(find.text('D'));
    expect(picked, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(picked, [0]);
  });

  testWidgets('maxsum 0 still lets slot 1 be chosen', (tester) async {
    final picked = await pump(tester, maxsum: 0);
    await tester.tap(find.text('A'));
    expect(picked, [1]);
  });
}

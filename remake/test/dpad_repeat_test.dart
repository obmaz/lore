import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/widgets/dpad_widget.dart';

/// The on-screen pad: a press moves once, holding repeats at a steady pace.
void main() {
  Future<List<(int, int)>> open(WidgetTester tester) async {
    final moves = <(int, int)>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: DPadWidget(
              onDirectionPressed: (dx, dy) => moves.add((dx, dy)),
            ),
          ),
        ),
      ),
    );
    return moves;
  }

  testWidgets('a tap moves exactly once', (tester) async {
    final moves = await open(tester);
    await tester.tap(find.byIcon(Icons.arrow_right));
    await tester.pump(const Duration(seconds: 1));
    expect(moves, [(1, 0)]);
  });

  testWidgets('holding a button repeats after the delay at the interval', (
    tester,
  ) async {
    final moves = await open(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.arrow_left)),
    );
    expect(moves, [(-1, 0)]); // at once
    await tester.pump(DPadWidget.repeatDelay - const Duration(milliseconds: 1));
    expect(moves.length, 1); // not before the delay
    await tester.pump(const Duration(milliseconds: 1));
    expect(moves.length, 2);
    await tester.pump(DPadWidget.repeatInterval * 3);
    expect(moves.length, 5);
    expect(moves.every((m) => m == (-1, 0)), isTrue);
    await gesture.up();
    final count = moves.length;
    await tester.pump(const Duration(seconds: 2));
    expect(moves.length, count); // released: no more input
  });

  testWidgets('a cancelled press and a removed pad stop the repeat', (
    tester,
  ) async {
    final moves = await open(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.arrow_drop_down)),
    );
    await tester.pump(DPadWidget.repeatDelay + DPadWidget.repeatInterval);
    final count = moves.length;
    expect(count, greaterThan(1));
    await gesture.cancel();
    await tester.pump(const Duration(seconds: 1));
    expect(moves.length, count);

    // The pad leaving the tree (battle, dialogs) cancels the timer.
    final held = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.arrow_drop_up)),
    );
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final after = moves.length;
    await tester.pump(const Duration(seconds: 1));
    expect(moves.length, after);
    await held.up();
    expect(tester.takeException(), isNull);
  });

  testWidgets('two buttons at once keep their own repeat', (tester) async {
    final moves = await open(tester);
    final left = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.arrow_left)),
    );
    final up = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.arrow_drop_up)),
    );
    await tester.pump(DPadWidget.repeatDelay);
    expect(moves.where((m) => m == (-1, 0)).length, 2);
    expect(moves.where((m) => m == (0, -1)).length, 2);
    await left.up();
    await up.up();
  });
}

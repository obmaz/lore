import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_creation.dart';
import 'package:lore/logic/lore_creation_allocation.dart';
import 'package:lore/screens/character_creation_screen.dart';

// LORECRET.PAS Second, native key-byte/cursor/rollback and actual UI adapter.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('all valid point triples and byte key/scan transitions match native', () {
    final data = jsonDecode(
      File('test/fixtures/dos_creation_second.json').readAsStringSync(),
    );
    expect(data['cases'].length, 54006);
    expect(LoreCreationAllocation().values, data['initial']);
    expect(LoreCreationAllocation().remaining, 40);
    for (final row in data['cases']) {
      final state = LoreCreationAllocation(
        values: List<int>.from(row['values']),
        cursor: row['cursor'],
      );
      final finished = state.readKey(row['key'], scan: row['scan']);
      final reason =
          'values=${row['values']} cursor=${row['cursor']} key=${row['key']} scan=${row['scan']}';
      expect(state.values, row['afterValues'], reason: reason);
      expect(state.cursor, row['afterCursor'], reason: reason);
      expect(state.remaining, row['afterRemaining'], reason: reason);
      expect(finished, row['finished'], reason: reason);
    }
  });
  testWidgets(
    'Second waits, clamps both cursors/budgets and accepts Enter only at zero',
    (tester) async {
      await LoreCreationData.instance.load(force: true);
      final data = LoreCreationData.instance;
      tester.view.physicalSize = const Size(1000, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(home: CharacterCreationScreen(onGameStart: (_) {})),
      );
      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pump();
      }

      await tap(find.text('1] 새로운 주인공을 생성 시킴'));
      await tap(find.text(data.text('Third', 10)));
      for (var i = 0; i < 10; i++) {
        await tap(find.text(data.questions[i].options[0].text));
      }
      expect(find.text('${data.text('Second', 1)}40'), findsOneWidget);
      for (var i = 2; i <= 4; i++) {
        expect(find.text('${data.text('Second', i)} 0'), findsOneWidget);
      }
      Future<void> key(LogicalKeyboardKey key) async {
        await tester.sendKeyEvent(key);
        await tester.pump();
      }

      await key(LogicalKeyboardKey.enter);
      expect(find.text('${data.text('Second', 1)}40'), findsOneWidget);
      await key(LogicalKeyboardKey.arrowLeft);
      await key(LogicalKeyboardKey.arrowUp);
      for (var i = 0; i < 21; i++) {
        await key(LogicalKeyboardKey.arrowRight);
      }
      expect(find.text('${data.text('Second', 2)} 20'), findsOneWidget);
      expect(find.text('${data.text('Second', 1)}20'), findsOneWidget);
      await key(LogicalKeyboardKey.arrowDown);
      await key(LogicalKeyboardKey.arrowDown);
      await key(LogicalKeyboardKey.arrowDown);
      for (var i = 0; i < 21; i++) {
        await key(LogicalKeyboardKey.arrowRight);
      }
      expect(find.text('${data.text('Second', 4)} 20'), findsOneWidget);
      expect(find.text('${data.text('Second', 1)}0'), findsOneWidget);
      await key(LogicalKeyboardKey.arrowUp);
      await key(LogicalKeyboardKey.arrowRight);
      expect(
        find.text('${data.text('Second', 3)} 0'),
        findsOneWidget,
      ); // exhausted budget
      await key(LogicalKeyboardKey.keyX);
      await key(LogicalKeyboardKey.escape);
      expect(
        find.text('${data.text('Second', 1)}0'),
        findsOneWidget,
      ); // not Enter
      await key(LogicalKeyboardKey.enter);
      expect(find.text('${data.text('Second', 1)}0'), findsNothing);
      expect(find.textContaining(data.text('Third', 0)), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_creation.dart';
import 'package:lore/logic/lore_creation_rules.dart';
import 'package:lore/screens/character_creation_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Third drains all supplied bytes; last byte decides class or rejection',
    () {
      final source = latin1.decode(
        File('repo_source/LORE_1993_src/LORECRET.PAS').readAsBytesSync(),
      );
      expect(source, contains('while KeyPressed do c := ReadKey;'));
      final data = jsonDecode(
        File('test/fixtures/dos_creation_class_queue.json').readAsStringSync(),
      );
      List<int> flags(int mask) => [
        0,
        for (var i = 0; i < 7; i++) (mask & (1 << i)) == 0 ? 0 : 1,
        1,
      ];
      expect(data['cases'].length, 32768);
      for (final row in data['cases']) {
        expect(
          LoreCreationRules.selectClassQueue([50, row[0]], flags(row[1])),
          row[2],
          reason: '$row',
        );
        expect(row[3], 2);
      }
      expect(data['mixed'].length, 1536);
      for (final row in data['mixed']) {
        final keys = List<int>.from(row[0]);
        expect(
          LoreCreationRules.selectClassQueue(keys, flags(row[1])),
          row[2],
          reason: '$row',
        );
        expect(row[3], keys.length);
      }
      expect(LoreCreationRules.selectClassQueue([], flags(127)), isNull);
    },
  );

  for (final size in [const Size(1280, 1000), const Size(390, 844)]) {
    testWidgets(
      'Third frame queue keeps last byte and subsequent acknowledgement at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.runAsync(
          () => LoreCreationData.instance.load(force: true),
        );
        final creation = LoreCreationData.instance;
        await tester.pumpWidget(
          MaterialApp(home: CharacterCreationScreen(onGameStart: (_) {})),
        );
        Future<void> key(LogicalKeyboardKey k) async {
          await tester.sendKeyEvent(k);
          await tester.pump(const Duration(milliseconds: 120));
        }

        await tester.tap(find.text('1] 새로운 주인공을 생성 시킴'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 5120));
        await tester.tap(find.text(creation.text('Third', 10)));
        await tester.pump();
        for (var i = 0; i < 10; i++) {
          await key(LogicalKeyboardKey.digit1);
        }
        await tester.pump(const Duration(milliseconds: 1640));
        for (var i = 0; i < 20; i++) {
          await key(LogicalKeyboardKey.arrowRight);
        }
        await key(LogicalKeyboardKey.arrowDown);
        for (var i = 0; i < 20; i++) {
          await key(LogicalKeyboardKey.arrowRight);
        }
        await key(LogicalKeyboardKey.enter);
        const confirmation = '당신의 계급은 ';
        // The first valid class must not survive an invalid final byte.
        await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
        await tester.pump();
        expect(find.textContaining('$confirmation마법사'), findsNothing);
        await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
        expect(find.textContaining('$confirmation마법사'), findsNothing);
        // Modifier/toggle keys do not enqueue DOS bytes, whereas two ordinary
        // keys in the same available batch are drained before selecting.
        await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
        await tester.sendKeyEvent(LogicalKeyboardKey.capsLock);
        await tester.sendKeyEvent(LogicalKeyboardKey.digit8);
        await tester.pump();
        expect(find.textContaining('$confirmation떠돌이'), findsOneWidget);
        expect(find.textContaining('$confirmation마법사'), findsNothing);
        expect(find.text('선택: 0 / 4 명'), findsNothing);
        await key(LogicalKeyboardKey.digit2);
        expect(find.text('선택: 0 / 4 명'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

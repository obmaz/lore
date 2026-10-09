import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_creation.dart';
import 'package:lore/logic/lore_creation_rules.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/screens/character_creation_screen.dart';

// LORECRET.PAS Which/Third numeric gates, WhatClass and Profile sex.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final data = jsonDecode(
    File('test/fixtures/dos_creation_class.json').readAsStringSync(),
  );
  test('all byte class keys and 128 eligibility masks match native', () {
    expect(data['cases'].length, 32768);
    for (final row in data['cases']) {
      final flags = [
        0,
        for (var i = 0; i < 7; i++) (row['mask'] & (1 << i)) == 0 ? 0 : 1,
        1,
      ];
      expect(LoreCreationRules.selectClass(row['key'], flags), row['selected']);
    }
    final source = latin1.decode(
      File('repo_source/LORE_1993_src/LORECRET.PAS').readAsBytesSync(),
    );
    expect(source, contains("until c in ['1'..'3'];"));
    for (var key = 0; key < 256; key++) {
      expect(
        LoreCreationRules.quizChoice(key),
        key >= 49 && key <= 51 ? key - 49 : null,
      );
      expect(
        LoreCreationRules.classLabel(key),
        data['source']['labels']['$key'] ?? data['source']['default'],
      );
    }
    for (final values in [List<int>.filled(8, 0), List<int>.filled(8, 255)]) {
      expect(LoreCreationRules.classFlags(values), [
        0,
        for (var id = 1; id <= 8; id++)
          LoreCreationRules.classEligible(id, values) ? 1 : 0,
      ]);
    }
  });
  for (final size in [const Size(1280, 1000), const Size(390, 844)]) {
    testWidgets(
      'Fourth keyboard choice, duplicate guard, review and restart at $size',
      (tester) async {
        await tester.runAsync(
          () => LoreCreationData.instance.load(force: true),
        );
        final creation = LoreCreationData.instance;
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        List<PartyMember>? party;
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterCreationScreen(onGameStart: (p) => party = p),
          ),
        );
        await tester.pump(const Duration(milliseconds: 53030));
        await tester.pump();
        Future<void> key(LogicalKeyboardKey k) async {
          await tester.sendKeyEvent(k);
          await tester.pump(const Duration(milliseconds: 120));
        }

        Future<void> enterFourth() async {
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
          await key(LogicalKeyboardKey.digit2);
          await key(LogicalKeyboardKey.enter);
          expect(find.text('선택: 0 / 4 명'), findsOneWidget);
          for (final c in creation.characters) {
            final item = find.byKey(ValueKey('creation-companion-${c.id}'));
            await tester.scrollUntilVisible(
              item,
              180,
              scrollable: find.descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              ),
            );
            expect(
              find.descendant(of: item, matching: find.textContaining(c.name)),
              findsOneWidget,
            );
          }
        }

        Future<void> selectFour() async {
          for (var i = 0; i < 4; i++) {
            await key(LogicalKeyboardKey.enter);
            await key(LogicalKeyboardKey.digit1);
            expect(find.text('선택: ${i + 1} / 4 명'), findsOneWidget);
            if (i == 0) {
              await key(LogicalKeyboardKey.enter);
              await key(LogicalKeyboardKey.digit1);
              expect(find.text('선택: 1 / 4 명'), findsOneWidget);
            }
            if (i < 3) {
              await key(LogicalKeyboardKey.arrowDown);
            }
          }
        }

        await enterFourth();
        await key(LogicalKeyboardKey.arrowUp);
        await key(LogicalKeyboardKey.enter);
        final prompt =
            '${creation.characters.first.name}: ${creation.text('Fourth', 2)} [1] / ${creation.text('Fourth', 3)} [2]';
        expect(find.text(prompt), findsOneWidget);
        await key(LogicalKeyboardKey.keyX);
        expect(find.text(prompt), findsOneWidget);
        await key(LogicalKeyboardKey.digit2);
        expect(find.text(prompt), findsNothing);
        expect(
          find.textContaining(creation.characters.first.name),
          findsWidgets,
        );
        await key(LogicalKeyboardKey.enter);
        expect(find.text(prompt), findsNothing); // Profile consumes this key.
        await key(LogicalKeyboardKey.enter);
        expect(find.text(prompt), findsOneWidget);
        await key(LogicalKeyboardKey.escape);
        expect(find.text(prompt), findsNothing);
        expect(find.text('선택: 0 / 4 명'), findsOneWidget);
        await selectFour();
        expect(party, isNull);
        expect(find.text('Hero'), findsOneWidget);
        for (final c in creation.characters.take(4)) {
          expect(find.text(c.name), findsOneWidget);
        }
        await key(LogicalKeyboardKey.escape);
        await tester.pump(const Duration(milliseconds: 53030));
        await tester.pump();
        expect(find.text('1] 새로운 주인공을 생성 시킴'), findsOneWidget);
        await enterFourth();
        await selectFour();
        await key(LogicalKeyboardKey.enter);
        expect(
          party!.skip(1).take(4).map((p) => p.name),
          creation.characters.take(4).map((c) => c.name),
        );
        expect(party!.first.playerClass, PlayerClass.mage);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets(
    'Which ignores invalid input, Third locks first valid choice and profiles cover both sexes',
    (tester) async {
      await tester.runAsync(() => LoreCreationData.instance.load(force: true));
      final creation = LoreCreationData.instance;
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      List<PartyMember>? party;
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterCreationScreen(onGameStart: (p) => party = p),
        ),
      );
      await tester.pump(const Duration(milliseconds: 53030));
      await tester.pump();
      Future<void> tap(Finder f) async {
        await tester.ensureVisible(f);
        await tester.tap(f);
        await tester.pump();
      }

      Future<void> key(LogicalKeyboardKey k) async {
        await tester.sendKeyEvent(k);
        await tester.pump(const Duration(milliseconds: 120));
      }

      await tap(find.text('1] 새로운 주인공을 생성 시킴'));
      await tester.pump(const Duration(milliseconds: 5120));
      await tap(find.text(creation.text('Third', 10)));
      final first = creation.questions[0].options[0].text;
      for (final invalid in [
        LogicalKeyboardKey.enter,
        LogicalKeyboardKey.escape,
        LogicalKeyboardKey.digit0,
        LogicalKeyboardKey.digit4,
        LogicalKeyboardKey.keyX,
      ]) {
        await key(invalid);
        expect(find.text(first), findsOneWidget);
      }
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
      await key(
        LogicalKeyboardKey.digit1,
      ); // unavailable Knight (endurance too low)
      expect(find.text('당신의 계급은 기사 입니다.'), findsNothing);
      await key(LogicalKeyboardKey.digit2);
      expect(find.text('당신의 계급은 마법사 입니다.'), findsOneWidget);
      await key(
        LogicalKeyboardKey.digit5,
      ); // acknowledgement, not a second class choice
      expect(find.text('선택: 0 / 4 명'), findsOneWidget);
      for (final raw in data['source']['characters']) {
        final item = find.byKey(ValueKey('creation-companion-${raw['id']}'));
        await tester.scrollUntilVisible(
          item,
          180,
          scrollable: find.descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          ),
        );
        await tap(
          find.descendant(
            of: item,
            matching: find.widgetWithText(
              TextButton,
              creation.text('Fourth', 3),
            ),
          ),
        );
        expect(
          find.text(
            '${creation.text('Profile', 2)}${raw['sex'] == 'female' ? '여성' : '남성'}',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            '${creation.text('Profile', 3)}${data['source']['labels']['${raw['class']}']}',
          ),
          findsOneWidget,
        );
      }
      for (final id in [4, 3, 2, 1]) {
        final item = find.byKey(ValueKey('creation-companion-$id'));
        await tester.scrollUntilVisible(
          item,
          -180,
          scrollable: find.descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          ),
        );
        await tap(
          find.descendant(
            of: item,
            matching: find.widgetWithText(
              TextButton,
              creation.text('Fourth', 2),
            ),
          ),
        );
      }
      await tap(find.text(creation.text('Third', 10)));
      expect(party!.first.playerClass, PlayerClass.mage);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

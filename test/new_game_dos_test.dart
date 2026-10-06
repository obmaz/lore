import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_creation.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/screens/character_creation_screen.dart';
import 'package:lore/services/save_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// LORECRET.PAS Fourth/Last: actual cold-start DOSBox inputs and four saves.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixture = jsonDecode(
    File('test/fixtures/dos_new_game.json').readAsStringSync(),
  );
  final inputs = fixture['inputs'];

  test('all creation classes reset the three levels to one', () {
    for (final cls in PlayerClass.values) {
      final member = PartyMember.createPreset(1)
        ..playerClass = cls
        ..concentration = 19
        ..battleLevel = 23
        ..magicLevel = 31
        ..espLevel = 41;
      member.applyCreationInit();
      expect(
        [member.battleLevel, member.magicLevel, member.espLevel],
        [1, 1, 1],
      );
      expect(member.esp, 19);
      expect(member.maxEsp, 19);
    }
  });

  testWidgets(
    'new-game UI, reverse companion choices and all four saves match DOS',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await LoreCreationData.instance.load(force: true);
      final data = LoreCreationData.instance;
      List<PartyMember>? created;
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterCreationScreen(
            onGameStart: (party) => created = party,
          ),
        ),
      );
      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.pump();
        await tester.tap(finder);
        await tester.pump();
      }

      Future<void> next() => tap(find.text(data.text('Third', 10)));
      await tap(find.text('1] 새로운 주인공을 생성 시킴'));
      await tester.enterText(find.byType(TextField), inputs['name']);
      await next();
      for (var i = 0; i < 10; i++) {
        await tap(find.text(data.questions[i].options[0].text));
      }
      for (final slot in [0, 1]) {
        for (var n = 0; n < 20; n++) {
          await tap(find.byIcon(Icons.add_circle_outline).at(slot));
        }
      }
      await next();
      await tap(find.text('8] 떠돌이'));
      await next();
      var previous = 1;
      Future<void> companion(int id) async {
        final item = find.byKey(ValueKey('creation-companion-$id'));
        await tester.scrollUntilVisible(
          item,
          id >= previous ? 180 : -180,
          scrollable: find.descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          ),
        );
        previous = id;
        await tap(
          find.descendant(
            of: item,
            matching: find.widgetWithText(TextButton, data.text('Fourth', 2)),
          ),
        );
      }

      for (final id in [1, 3, 5, 7]) {
        await companion(id);
      }
      for (final id in inputs['companionsSelected'] as List) {
        await companion(id);
      }
      await next();
      expect(created, isNotNull);
      expect(created!.map((p) => p.toJson()).toList(), fixture['records']);
      await SaveManager.instance.writeNewGame(
        created!,
        mapTitle: 'CASTLE LORE',
      );
      for (var slot = 1; slot <= 4; slot++) {
        final saved = (await SaveManager.instance.loadGame(slot))!;
        expect(saved.party.map((p) => p.toJson()).toList(), fixture['records']);
        expect(
          [saved.mapId, saved.playerX, saved.playerY, saved.food, saved.gold],
          [6, 51, 31, 20, 2000],
        );
        expect(saved.flags, isEmpty);
        expect(saved.etc, isEmpty);
        expect(saved.mapTiles, isEmpty);
      }
      // Source Set_All mutates only after Last has written its zero sixth slot.
      PartyMember.simpleDisCond(created!);
      expect(
        created!.map((p) => p.toJson()).toList(),
        fixture['firstQuest']['records'],
      );
      final first = (await SaveManager.instance.loadGame(1))!;
      expect([first.party[5].unconscious, first.party[5].dead], [0, 0]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

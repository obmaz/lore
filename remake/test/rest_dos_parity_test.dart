import 'support/source_audio_platform.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/logic/lore_menu_text.dart';
import 'package:lore/logic/town_logic.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/services/save_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// LOREMENU.PAS Rest: independent DOS save and actual mobile R/Save path.
void main() {
  setUp(installSourceAudioPlatform);
  final fixture = jsonDecode(
    File('test/fixtures/dos_rest_states.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  List<PartyMember> party() => [
    for (final record in fixture['input'] as List)
      PartyMember.fromJson(Map<String, dynamic>.from(record)),
  ];
  void check(List<PartyMember> members) {
    expect(members.length, 6);
    for (final (i, member) in members.indexed) {
      expect(
        member.toJson(),
        fixture['observed'][i],
        reason: 'native slot ${i + 1}',
      );
    }
  }

  test(
    'Rest integer assignments, six records and food match independent DOS',
    () {
      final members = party();
      final result = TownLogic.rest(
        members,
        fixture['initialFood'],
        torchSteps: fixture['initialEtc'][0],
      );
      check(members);
      expect(result.food, fixture['observedFood']);
      expect(result.torchSteps, fixture['observedEtc'][0]);
      expect(result.lines, [
        (15, 'Hero는 치료되었다'),
        (15, 'Mate는 모든 건강이 회복되었다'),
        (7, 'Dead는 죽었다'),
        (7, '독때문에, Poison 그녀의 건강은 회복되지 않았다'),
        (15, 'Faint는 의식이 회복되었다'),
      ]);
    },
  );
  test(
    'Rest keeps max-food refund, starvation priority and native slot bounds',
    () {
      for (final food in [254, 255]) {
        final full = PartyMember.createPreset(1)
          ..hp = 20
          ..endurance = 20
          ..battleLevel = 1;
        expect(TownLogic.rest([full], food).food, 254);
      }
      final starving = PartyMember.createPreset(1)
        ..dead = 1
        ..sp = 0;
      expect(TownLogic.rest([starving], 0).lines, [(4, '일행은 식량이 바닥났다')]);
      expect(
        starving.sp,
        starving.maxSp,
      ); // named dead member refills even with no food
      final slots = [
        for (var i = 0; i < 7; i++)
          PartyMember.blank()
            ..hp = 0
            ..unconscious = 0
            ..dead = 0
            ..sp = 123,
      ];
      TownLogic.rest(slots, 0);
      for (final m in slots.take(6)) {
        expect((m.unconscious, m.dead, m.sp), (1, 1, 123));
      }
      expect((slots[6].unconscious, slots[6].dead, slots[6].sp), (0, 0, 123));
    },
  );
  testWidgets('mobile R and Save preserve original DOS rest state', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(() {
      LoreDialogueManager.instance.loadFlags({});
      LoreScriptEngine.instance.resetForTest();
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final tiles = List.filled(10000, 44)..[(31 - 1) * 100 + (51 - 1)] = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: MainGameScreen(
          sourceReplayBattle: true,
          initialSaveData: SaveData(
            slot: 1,
            slotName: SaveManager.slotNames.first,
            timestamp: DateTime.utc(1993),
            mapId: 6,
            mapTitle: 'TOWN1',
            playerX: 51,
            playerY: 31,
            gold: 10000,
            food: fixture['initialFood'],
            party: party(),
            flags: const {},
            etc: const {
              'torchSteps': 2,
              'waterWalkSteps': 3,
              'swampWalkSteps': 4,
              'levitateSteps': 5,
            },
            mapTiles: tiles,
          ),
        ),
      ),
    );
    Future<void> settle() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    await tester.pump(const Duration(milliseconds: 500));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await settle();
    expect(find.textContaining('Hero는 치료되었다'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    await settle();
    await tester.tap(find.text(LoreMenuText.optionSave));
    await settle();
    await tester.tap(find.text(SaveManager.slotNames.first));
    await settle();
    final saved = await SaveManager.instance.loadGame(1);
    expect(saved, isNotNull);
    check(saved!.party);
    expect(saved.food, fixture['observedFood']);
    expect([
      saved.etc['torchSteps'],
      saved.etc['waterWalkSteps'],
      saved.etc['swampWalkSteps'],
      saved.etc['levitateSteps'],
    ], fixture['observedEtc']);
    expect([saved.mapId, saved.playerX, saved.playerY], [6, 51, 31]);
  });
}

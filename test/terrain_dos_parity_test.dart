import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/logic/lore_main_procedures.dart';
import 'package:lore/logic/lore_menu_text.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/services/save_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ReplayRandom implements Random {
  _ReplayRandom(this.draws);
  final List<int> draws;
  final List<int> bounds = [];
  int index = 0;
  @override
  int nextInt(int max) {
    bounds.add(max);
    // Field encounter after ordinary movement: a nonzero roll, no battle.
    final value = index < draws.length ? draws[index++] : 1;
    expect(value, inInclusiveRange(0, max == 0 ? 0 : max - 1));
    return value;
  }

  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
}

/// LOREMAIN.PAS Move_Mode/enter_swamp/enter_lava: independent original DOS
/// saves, including byte poison, integer HP/unc/dead and empty slot mutations.
void main() {
  final fixture = jsonDecode(
    File('test/fixtures/dos_terrain_states.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  for (final entry in fixture['cases'] as List) {
    final scenario = entry['scenario'] as String;
    List<PartyMember> party() => [
      for (final record in entry['input'] as List)
        PartyMember.fromJson(Map<String, dynamic>.from(record)),
    ];
    _ReplayRandom random() =>
        _ReplayRandom(List<int>.from(entry['replayDraws'] ?? const <int>[]));
    void check(List<PartyMember> members) {
      expect(members.length, 6);
      for (final (i, member) in members.indexed) {
        expect(
          member.toJson(),
          entry['observed'][i],
          reason: '$scenario slot ${i + 1}',
        );
      }
    }

    test(
      '$scenario closed field procedure matches native saved records',
      () async {
        final members = party();
        final rng = random();
        final trace = <String>[];
        var swampWalk = entry['initialSwampWalk'] as int;
        void condition() {
          trace.add('condition');
          PartyMember.simpleDisCond(members);
        }

        switch (scenario) {
          case 'move':
            await LoreMainProcedures.moveMode(
              party: members,
              scrollToParty: () => trace.add('scroll'),
              displayHealthAndCondition: condition,
              gameOver: () async => trace.add('gameOver'),
              mindReadSteps: () => 0,
              setMindReadSteps: (_) => fail('no mind read'),
              encounterFrequency: () => 2,
              random: rng.nextInt,
              encounterEnemy: () => fail('no encounter'),
            );
            expect(rng.bounds, [40]);
            expect(trace, ['scroll', 'condition']);
          case 'swamp':
            await LoreMainProcedures.enterSwamp(
              party: members,
              scrollToParty: () => trace.add('scroll'),
              swampWalkSteps: () => swampWalk,
              setSwampWalkSteps: (v) => swampWalk = v,
              random: rng,
              showSwampWarning: () => fail('protected'),
              showPoisonMessage: (_) => fail('protected'),
              displayCondition: condition,
              displayHealthAndCondition: condition,
              gameOver: () async => trace.add('gameOver'),
            );
            expect(rng.bounds, isEmpty);
            expect(trace, ['scroll', 'condition']);
          case 'lava':
            final damageLines = <int>[];
            await LoreMainProcedures.enterLava(
              party: members,
              random: rng,
              scrollToParty: () => trace.add('scroll'),
              showLavaWarning: () => trace.add('warning'),
              showDamage: (member, damage) {
                // All twelve random calls and all messages precede mutation.
                expect(rng.bounds.length, 12);
                expect(members.first.hp, entry['input'][0]['hp']);
                damageLines.add(damage);
              },
              displayCondition: condition,
              gameOver: () async => trace.add('gameOver'),
            );
            expect(rng.bounds, [0, 40, 255, 40, 0, 40, 0, 40, 0, 40, 0, 40]);
            expect(damageLines, [
              76,
              -117,
              61,
              79,
              77,
            ]); // empty slot 5 still takes 64
            expect(trace, ['scroll', 'warning', 'condition']);
        }
        check(members);
        expect(swampWalk, entry['observedSwampWalk']);
      },
    );

    testWidgets('$scenario mobile step and Save match native field records', (
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
      final tiles = List.filled(10000, 44);
      tiles[(31 - 1) * 100 + (52 - 1)] = entry['targetTile'] as int;
      await tester.pumpWidget(
        MaterialApp(
          home: MainGameScreen(
            encounterRandom: random(),
            initialSaveData: SaveData(
              slot: 1,
              slotName: SaveManager.slotNames.first,
              timestamp: DateTime.utc(1993),
              mapId: 6,
              mapTitle: 'TOWN1',
              playerX: 51,
              playerY: 31,
              gold: 10000,
              food: 100,
              party: party(),
              flags: const {},
              etc: {'swampWalkSteps': entry['initialSwampWalk'] as int},
              mapTiles: tiles,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(LoreMenuText.optionSave));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(SaveManager.slotNames.first));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final saved = await SaveManager.instance.loadGame(1);
      expect(saved, isNotNull);
      check(saved!.party);
      expect([
        saved.mapId,
        saved.playerX,
        saved.playerY,
      ], entry['observedPosition']);
      expect(saved.etc['swampWalkSteps'], entry['observedSwampWalk']);
      // Leave the save's final key wait pending, as in the DOS capture.
    });
  }
}

import 'support/source_audio_platform.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/logic/lore_battle.dart';
import 'package:lore/logic/lore_battle_progress.dart';
import 'package:lore/logic/lore_menu_text.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/services/save_manager.dart';
import 'package:lore/widgets/battle_viewport_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Zero implements Random {
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
}

/// LOREBATT.PAS PlusExperience/PlusGold and LORESPEC.PAS prison continuation:
/// independent original DOS saved six-member and party records, not JSON rules.
void main() {
  setUp(installSourceAudioPlatform);
  final f = jsonDecode(
    File('test/fixtures/dos_battle_rewards.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  List<PartyMember> party() => [
    for (final r in f['input'] as List)
      PartyMember.fromJson(Map<String, dynamic>.from(r)),
  ];
  Map<String, dynamic> flags() => {
    for (var i = 0; i < 100; i++) 'etc${i + 1}': f['initialEtc'][i],
  };
  void check(List<PartyMember> members) {
    expect(members.length, 6);
    for (final (i, m) in members.indexed) {
      expect(m.toJson(), f['observed'][i], reason: 'native slot ${i + 1}');
    }
  }

  List<Monster> soldiers() => [
    for (var i = 1; i <= 2; i++)
      Monster.create(
        26,
      ).withOverrides(name: 'Soldier$i', special: 0, castLevel: 0, eNumber: 1),
  ];

  test(
    'two native prison rounds reproduce signed rewards and all six records',
    () {
      final members = party(), foes = soldiers();
      final b = LoreBattle(
        party: members,
        enemy: foes,
        random: _Zero(),
        print: (_, _) {},
      );
      b.enemyPhase(); // BattleMode(FALSE) starts with the enemies.
      for (var round = 0; round < 2; round++) {
        for (var i = 1; i <= 6; i++) {
          if (b.exist(i)) b.autoSelect(i);
        }
        for (var i = 1; i <= 6; i++) {
          if (b.exist(i)) b.executePerson(i);
        }
        b.enemyPhase();
        expect(b.endBattle(), round == 0 ? isNull : 0);
      }
      check(members);
      final reward = b.plusGold();
      expect(
        reward,
        2,
      ); // E_number1's original template, not Soldier26's level.
      final result = LoreBattleProgress.resolve(
        LoreBattleProgressState(
          gold: f['initialGold'],
          lastBattleResult: 1,
          flags: const {},
        ),
        end: LoreBattleEnd.victory,
        enemyNames: foes.map((m) => m.name),
        goldEarned: reward,
      );
      expect(result.state.gold, f['observedGold']);
      expect(result.state.lastBattleResult, f['observedEtc'][5]);
    },
  );

  test(
    'shared kill reward excludes dead, unconscious, blank and seventh slots',
    () {
      final members = party()
        ..add(PartyMember.createPreset(1)..experience = 2147483647);
      final foe = Monster.create(1)..isUnconscious = true;
      final b = LoreBattle(
        party: members,
        enemy: [foe],
        random: _Zero(),
        print: (_, _) {},
      );
      final before = members.map((m) => m.experience).toList();
      b.plusExperience(1, 1);
      expect(members.map((m) => m.experience).toList(), [
        2147483647,
        -2147483648,
        ...before.skip(2),
      ]);
      for (final end in [LoreBattleEnd.runAway, LoreBattleEnd.defeat]) {
        final result = LoreBattleProgress.resolve(
          LoreBattleProgressState(
            gold: f['initialGold'],
            lastBattleResult: 1,
            flags: const {},
          ),
          end: end,
          enemyNames: ['Soldier1'],
          goldEarned: 2,
        );
        expect(result.state.gold, f['initialGold']);
      }
    },
  );

  testWidgets(
    'mobile original prison battle, continuation and Save match DOS',
    (tester) async {
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
      final tiles = List.filled(10000, 44)..[(12 - 1) * 100 + (51 - 1)] = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MainGameScreen(
            initialSaveData: SaveData(
              slot: 1,
              slotName: SaveManager.slotNames.first,
              timestamp: DateTime.utc(1993),
              mapId: 6,
              mapTitle: 'TOWN1',
              playerX: 51,
              playerY: 13,
              gold: f['initialGold'],
              food: 100,
              party: party(),
              flags: flags(),
              mapTiles: tiles,
            ),
          ),
        ),
      );
      Future<void> settle() async {
        for (var i = 0; i < 6; i++) {
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      await tester.runAsync(
        () => tester
            .state<GameWidgetState<LoreGame>>(find.byType(GameWidget<LoreGame>))
            .loaderFuture,
      );
      await settle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await settle();
      await tester.tap(
        find.byKey(const ValueKey('script-scene-continue')).last,
      );
      await settle();
      expect(find.byType(BattleViewportView), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter); // opening ReadKey
      await settle();
      for (var turn = 0; turn < 2; turn++) {
        expect(
          tester
              .widget<ElevatedButton>(
                find.byKey(const ValueKey('battle-cmd-7')),
              )
              .onPressed,
          isNotNull,
          reason: 'turn $turn command ready',
        );
        await tester.tap(find.byKey(const ValueKey('battle-cmd-7')));
        await settle();
        await tester.sendKeyEvent(
          LogicalKeyboardKey.enter,
        ); // party PressAnyKey
        await settle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter); // enemy ReadKey
        await settle();
      }
      expect(find.byType(BattleViewportView), findsNothing);
      expect(find.text('당신들은 수감소 병사들을 물리쳤다.'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('script-scene-continue')).last,
      );
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
      expect(saved.gold, f['observedGold']);
      expect(saved.food, f['food']);
      expect([
        saved.mapId,
        saved.playerX,
        saved.playerY,
      ], f['observedPosition']);
      for (var i = 0; i < 100; i++) {
        expect(
          saved.flags['etc${i + 1}'],
          f['observedEtc'][i],
          reason: 'etc${i + 1}',
        );
      }
      for (final cell in f['openedCells'] as List) {
        expect(
          saved.mapTiles[(cell['y'] - 1) * 100 + cell['x'] - 1],
          cell['tile'],
        );
      }
    },
  );
}

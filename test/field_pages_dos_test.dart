import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_main_procedures.dart';
import 'package:lore/logic/lore_lava_logic.dart';
import 'package:lore/logic/lore_random.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/services/save_manager.dart';
import 'package:lore/widgets/message_log_view.dart';

class _Zero implements Random {
  final void Function() onDraw;
  _Zero(this.onDraw);
  int calls = 0;
  @override
  int nextInt(int max) {
    calls++;
    onDraw();
    return 0;
  }

  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
}

// LOREMAIN.PAS:56/81/86: native pages and six fresh damage strings.
// Identical BGI redraws project to one modern message frame, not duplicate logs.
void main() {
  final data = jsonDecode(
    File('test/fixtures/dos_field_pages.json').readAsStringSync(),
  );
  List<String> lines(Map row, int page) => [
    for (final line in row['pages'][page]['lines'])
      if (data['strings'][line[1]] != '') data['strings'][line[1]] as String,
  ];
  for (final lava in [false, true]) {
    testWidgets(
      'actual hazard window clears old text and uses native frame colours: $lava',
      (tester) async {
        for (final channel in [
          'xyz.luan/audioplayers',
          'xyz.luan/audioplayers.global',
        ]) {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(MethodChannel(channel), (_) async => 1);
        }
        addTearDown(() => LoreDialogueManager.instance.loadFlags({}));
        final row = lava
            ? data['lava'][0]
            : (data['swamp'] as List).firstWhere(
                (r) => r['names'] == 63 && r['marks'] == 63,
              );
        final party = [
          for (var i = 0; i < 6; i++)
            PartyMember.createPreset(1)
              ..name = 'MEM${i + 1}'
              ..hp = 30000
              ..luck = 0
              ..poison = lava
                  ? 0
                  : (row['beforePoison'][i] > 0
                        ? row['beforePoison'][i] - 1
                        : 0),
        ];
        await tester.pumpWidget(
          MaterialApp(
            home: MainGameScreen(
              encounterRandom: LoreRandom(0),
              initialSaveData: SaveData(
                slot: 1,
                slotName: 'PAGE',
                timestamp: DateTime.utc(1993),
                mapId: 6,
                mapTitle: 'TOWN1',
                playerX: 10,
                playerY: 10,
                gold: 123,
                food: 20,
                flags: const {},
                party: party,
                mapWidth: 20,
                mapHeight: 20,
                mapTiles: List.filled(400, lava ? 26 : 25),
              ),
            ),
          ),
        );
        final finder = find.byType(GameWidget<LoreGame>);
        await tester.runAsync(
          () => tester.state<GameWidgetState<LoreGame>>(finder).loaderFuture,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        final game = tester.widget<GameWidget<LoreGame>>(finder).game!;
        game.onLog?.call('OLD CURRENT MESSAGE');
        await tester.pump();
        game.tryMove(1, 0);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        final window = tester.widget<MessageLogView>(
          find.byType(MessageLogView),
        );
        expect(window.logs, lines(row, 0));
        expect(window.colors, [
          for (final line in row['pages'][0]['lines'])
            if (data['strings'][line[1]] != '') line[0],
        ]);
        expect(window.logs, isNot(contains('OLD CURRENT MESSAGE')));
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  test(
    '4096 native name/mark masks project to one identical swamp frame',
    () async {
      for (final row in data['swamp'] as List) {
        expect(lines(row, 0), lines(row, 1));
        var cleared = false;
        final rng = _Zero(() => expect(cleared, isTrue));
        final party = [
          for (var i = 0; i < 6; i++)
            PartyMember.zero()
              ..name = (row['names'] & (1 << i)) != 0 ? 'MEM${i + 1}' : ''
              ..luck = (row['marks'] & (1 << i)) != 0 ? 0 : 255
              ..hp = 100
              ..poison =
                  (row['names'] & (1 << i)) != 0 && row['beforePoison'][i] > 0
                  ? row['beforePoison'][i] - 1
                  : row['beforePoison'][i],
        ];
        final output = <String>[];
        await LoreMainProcedures.enterSwamp(
          party: party,
          scrollToParty: () {},
          swampWalkSteps: () => 0,
          setSwampWalkSteps: (_) => fail('not protected'),
          random: rng,
          clearMessageWindow: () {
            cleared = true;
          },
          showSwampWarning: () => output.add('일행은 독이 있는 늪에 들어갔다 !!!'),
          showPoisonMessage: (p) => output.add('${p.name}는 중독 되었다.'),
          displayCondition: () {},
          displayHealthAndCondition: () => fail('no tick'),
          gameOver: () async => expect(row['names'], 0),
        );
        expect(output, lines(row, 0));
        expect(party.map((p) => p.poison).toList(), row['afterPoison']);
        expect(rng.calls, 6);
      }
    },
  );
  test('native lava scratch/RNG/Str repeat calls never reuse old damage', () {
    List<int>? previous;
    for (final row in data['lava'] as List) {
      final party = [
        for (var i = 0; i < 6; i++) PartyMember.zero()..luck = row['luck'][i],
      ];
      final rng = LoreRandom(row['seed']);
      final damages = LoreLavaLogic.rollDamages(party, rng);
      expect(damages.map((x) => x.toString()).toList(), row['texts']);
      expect(rng.seed, row['afterSeed']);
      expect(damages, hasLength(6));
      if (previous != null) expect(identical(previous, damages), isFalse);
      previous = damages;
      expect(lines(row, 0), lines(row, 1));
    }
  });
  test('lava renders native messages after clear and before damage in both page projections', () async {
    for (final row in data['lava'] as List) {
      var cleared = false;
      final rng = LoreRandom(row['seed']);
      final party = [
        for (var i = 0; i < 6; i++)
          PartyMember.zero()
            ..name = 'MEM${i + 1}'
            ..luck = row['luck'][i]
            ..hp = 30000,
      ];
      final output = <String>[];
      await LoreMainProcedures.enterLava(
        party: party,
        random: rng,
        scrollToParty: () {},
        clearMessageWindow: () {
          cleared = true;
        },
        showLavaWarning: () {
          expect(cleared, isTrue);
          output.add('일행은 용암지대로 들어섰다 !!!');
        },
        showDamage: (p, damage) {
          expect(party.map((x) => x.hp), everyElement(30000));
          output.add('${p.name}는 $damage의 피해를 입었다 !');
        },
        displayCondition: () {},
        gameOver: () async => fail('alive'),
      );
      expect(output, lines(row, 0));
      expect(rng.seed, row['afterSeed']);
      expect(party.map((p) => p.hp).toList(), [
        for (final text in row['texts']) 30000 - int.parse(text),
      ]);
    }
  });
}

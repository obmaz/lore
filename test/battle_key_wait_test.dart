import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_batt_text.dart';
import 'package:lore/logic/lore_sub_text.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/widgets/battle_viewport_view.dart';

import 'support/battle_keys.dart';

/// Every `random(n)` returns n - 1: attacks miss, a run attempt may fail.
class _MaxRandom implements Random {
  @override
  int nextInt(int max) => max - 1;

  @override
  bool nextBool() => true;

  @override
  double nextDouble() => 0.999;
}

class _ZeroRandom implements Random {
  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}

/// LOREBATT.PAS `BattleMode`: `PressAnyKey` after the party phase, `c :=
/// ReadKey` after the enemy phase and after a successful `RunAway`.
void main() {
  testWidgets(
    'the party phase ends with PressAnyKey, the enemy phase with ReadKey',
    (tester) async {
      final logs = <String>[];
      final hero = PartyMember.createPreset(1)..hp = 10000;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BattleViewportView(
              partyMembers: [hero],
              enemies: [Monster.create(1)],
              random: _MaxRandom(),
              espAccessGranted: false,
              onLog: logs.add,
              onVictory: (_) {},
              onTelepathyJoin: (_) {},
              onDefeat: () {},
              onRunAway: () {},
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('battle-cmd-1')));
      await tester.pump(const Duration(milliseconds: 300));
      // PressAnyKey: the party's own lines are out, the enemy has not acted.
      expect(find.text(LoreSubText.pressAnyKey), findsOneWidget);
      final partyLines = logs.length;
      expect(partyLines, greaterThan(0));
      await pressBattleKey(tester);
      // The enemy phase printed; ReadKey has no prompt and holds the round.
      expect(logs.length, greaterThan(partyLines));
      expect(find.text(LoreSubText.pressAnyKey), findsNothing);
      final enemyLines = logs.length;
      await tester.pump(const Duration(seconds: 1));
      expect(logs.length, enemyLines);
      final command = find.byKey(const ValueKey('battle-cmd-1'));
      expect(tester.widget<ElevatedButton>(command).onPressed, isNull);
      await pressBattleKey(tester);
      expect(tester.widget<ElevatedButton>(command).onPressed, isNotNull);
    },
  );

  testWidgets('a successful RunAway waits for ReadKey before leaving', (
    tester,
  ) async {
    final logs = <String>[];
    var ran = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BattleViewportView(
            partyMembers: [
              PartyMember.createPreset(1)..hp = 10000,
              PartyMember.createPreset(2)..hp = 10000,
            ],
            enemies: [Monster.create(1)],
            random: _ZeroRandom(),
            espAccessGranted: false,
            onLog: logs.add,
            onVictory: (_) {},
            onTelepathyJoin: (_) {},
            onDefeat: () {},
            onRunAway: () => ran++,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('battle-cmd-1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('battle-cmd-7')));
    await tester.pump(const Duration(milliseconds: 600));
    expect(logs, contains(LoreBattText.runSuccess));
    expect(ran, 0);
    await pressBattleKey(tester);
    expect(ran, 1);
  });
}

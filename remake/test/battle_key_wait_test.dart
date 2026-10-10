import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_batt_text.dart';
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
              sourceReplay: true,
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
      expect(find.byKey(const ValueKey('battle-continue')), findsOneWidget);
      final partyLines = logs.length;
      expect(partyLines, greaterThan(0));
      await pressBattleKey(tester);
      // The enemy phase printed; ReadKey has no prompt and holds the round.
      expect(logs.length, greaterThan(partyLines));
      expect(find.byKey(const ValueKey('battle-continue')), findsNothing);
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
            sourceReplay: true,
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

  testWidgets('the press that ends a wait does not pick an enemy', (
    tester,
  ) async {
    final logs = <String>[];
    final first = Monster.create(1)..hp = 30000;
    final second = Monster.create(10)..hp = 30000;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BattleViewportView(
            sourceReplay: true,
            partyMembers: [PartyMember.createPreset(1)..hp = 10000],
            enemies: [first, second],
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
    expect(find.byKey(const ValueKey('battle-continue')), findsOneWidget);
    // A wait is released only by the explicit mobile action.
    await tester.tap(find.byKey(const ValueKey('battle-continue')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const ValueKey('battle-continue')), findsNothing);
    await tester.pump(); // render the second enemy before its ReadKey
    await pressBattleKey(tester); // ReadKey after the enemy phase
    logs.clear();
    await tester.tap(find.byKey(const ValueKey('battle-cmd-1')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(logs.first, contains(first.name));
    expect(logs.first, isNot(contains(second.name)));
  });

  testWidgets('disposing during an enemy frame stops later enemy actions', (
    tester,
  ) async {
    final logs = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: BattleViewportView(
          sourceReplay: true,
          partyMembers: [PartyMember.createPreset(1)..hp = 10000],
          enemies: [Monster.create(1), Monster.create(10)],
          enemyFirst: true,
          random: _MaxRandom(),
          espAccessGranted: false,
          onLog: logs.add,
          onVictory: (_) {},
          onTelepathyJoin: (_) {},
          onDefeat: () {},
          onRunAway: () {},
        ),
      ),
    );
    // First enemy has acted; the widget is waiting for its rendered frame.
    expect(logs, isNotEmpty);
    final firstEnemyLines = List<String>.of(logs);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(logs, firstEnemyLines);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a lone modifier key does not end a wait', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BattleViewportView(
            sourceReplay: true,
            partyMembers: [PartyMember.createPreset(1)..hp = 10000],
            enemies: [Monster.create(1)..hp = 30000],
            random: _MaxRandom(),
            espAccessGranted: false,
            onLog: (_) {},
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
    await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const ValueKey('battle-continue')), findsOneWidget);
    await pressBattleKey(tester);
    expect(find.byKey(const ValueKey('battle-continue')), findsNothing);
  });
}

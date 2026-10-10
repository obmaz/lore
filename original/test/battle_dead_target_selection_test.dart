import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_sub_text.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/widgets/battle_viewport_view.dart';

class _CountingRandom implements Random {
  final bounds = <int>[];
  @override
  int nextInt(int max) {
    bounds.add(max);
    return max - 1;
  }

  @override
  bool nextBool() => throw UnsupportedError('integer Random only');
  @override
  double nextDouble() => throw UnsupportedError('integer Random only');
}

void main() {
  Widget screen(List<PartyMember> party, List<Monster> enemy, Random random) =>
      MaterialApp(
        home: Scaffold(
          body: BattleViewportView(
            partyMembers: party,
            enemies: enemy,
            random: random,
            espAccessGranted: false,
            onLog: (_) {},
            onVictory: (_) {},
            onTelepathyJoin: (_) {},
            onDefeat: () {},
            onRunAway: () {},
          ),
        ),
      );
  testWidgets('a dead last target does not attack an earlier live enemy', (
    tester,
  ) async {
    // SelectEnemy accepts dead slots. AttackOne retargets forwards only.
    final random = _CountingRandom();
    final live = Monster.create(1);
    await tester.pumpWidget(
      screen(
        [PartyMember.createPreset(1)],
        [
          live,
          Monster.create(2)
            ..hp = 0
            ..isDead = true,
        ],
        random,
      ),
    );
    final before = live.hp;
    await tester.tap(find.byKey(const ValueKey('enemy-1')));
    await tester.tap(find.byKey(const ValueKey('battle-cmd-1')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(LoreSubText.pressAnyKey), findsOneWidget);
    expect(random.bounds, isEmpty);
    expect(live.hp, before);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('next person starts at slot one including a dead first slot', (
    tester,
  ) async {
    final random = _CountingRandom();
    await tester.pumpWidget(
      screen(
        [PartyMember.createPreset(1), PartyMember.createPreset(2)],
        [
          Monster.create(1)
            ..hp = 0
            ..isDead = true,
          Monster.create(2),
          Monster.create(3)
            ..hp = 0
            ..isDead = true,
        ],
        random,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('enemy-2')));
    await tester.tap(find.byKey(const ValueKey('battle-cmd-1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('battle-cmd-1')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(LoreSubText.pressAnyKey), findsOneWidget);
    expect(random.bounds, [20]);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

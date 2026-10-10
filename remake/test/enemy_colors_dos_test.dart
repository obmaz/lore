import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_enemy_presentation.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/theme/retro_theme.dart';
import 'package:lore/widgets/battle_viewport_view.dart';

// LOREBATT.PAS DisplayEnemies numeric colours and rendered active roster.
void main() {
  final data = jsonDecode(
    File('test/fixtures/dos_enemy_colors.json').readAsStringSync(),
  );
  test(
    'all signed HP words, both statuses and native active-count iterations',
    () {
      final enemy = Monster.create(1);
      final rows = data['cases'] as List;
      expect(rows.take(65536).map((r) => r['hp']).toSet().length, 65536);
      for (final r in rows) {
        enemy.hp = r['hp'];
        enemy.isUnconscious = r['unconscious'];
        enemy.isDead = r['dead'];
        expect(
          [
            for (var i = 1; i <= r['count']; i++)
              [i, LoreEnemyPresentation.color(enemy)],
          ],
          r['printed'],
          reason: 'HP=${r['hp']} U=${r['unconscious']} D=${r['dead']}',
        );
      }
    },
  );
  testWidgets('native palettes and status precedence reach actual enemy text', (
    tester,
  ) async {
    final rows = (data['cases'] as List)
        .skip(65536)
        .where((r) => r['count'] == 7);
    for (final r in rows) {
      final enemies = [
        for (var i = 0; i < 7; i++)
          Monster.create(1)
            ..hp = r['hp']
            ..isUnconscious = r['unconscious']
            ..isDead = r['dead'],
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BattleViewportView(
              sourceReplay: true,
              key: UniqueKey(),
              partyMembers: [PartyMember.createPreset(1)],
              enemies: enemies,
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
      for (var i = 0; i < 7; i++) {
        final text = tester.widget<Text>(
          find.descendant(
            of: find.byKey(ValueKey('enemy-$i')),
            matching: find.byType(Text),
          ),
        );
        final index = r['printed'][i][1];
        expect(
          text.style!.color,
          index == 0 ? Colors.transparent : RetroTheme.ega(index),
        );
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

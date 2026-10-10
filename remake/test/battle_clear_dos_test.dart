import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/widgets/battle_viewport_view.dart';
import 'package:lore/widgets/encounter_viewport_view.dart';
import 'package:lore/logic/lore_enemy_presentation.dart';
import 'package:lore/theme/retro_theme.dart';

// LOREBATT.PAS:1027 BattleMode k<>1 Clear and DisplayEnemies:79 backdrop.
void main() {
  final fixture = jsonDecode(
    File('test/fixtures/dos_battle_clear.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  testWidgets(
    'clean backdrop replaces previous roster, then recolours without stale text',
    (tester) async {
      expect(fixture['displays'][0]['events'], isEmpty);
      expect(fixture['displays'][1]['events'], [
        [
          'SetFillStyle',
          [1, 0],
        ],
        [
          'Bar',
          [20, 20, 199, 199],
        ],
        [
          'SetFillStyle',
          [1, 8],
        ],
      ]);
      Widget encounter(List<Monster> enemies) => MaterialApp(
        home: Scaffold(
          body: EncounterViewportView(
            sourceReplay: true,
            enemies: enemies,
            onEngage: () {},
            onFlee: () {},
          ),
        ),
      );
      final old = [for (var i = 0; i < 7; i++) Monster.create(1)];
      final oldName = Monster.create(1).name;
      final currentName = Monster.create(2).name;
      await tester.pumpWidget(encounter(old));
      expect(find.textContaining(oldName), findsNWidgets(7));
      final enemy = Monster.create(2)..hp = 19;
      await tester.pumpWidget(encounter([enemy]));
      expect(find.textContaining(oldName), findsNothing);
      final current = find.textContaining(currentName);
      expect(current, findsOneWidget);
      expect(
        tester.widget<Text>(current).style!.color,
        RetroTheme.ega(LoreEnemyPresentation.color(enemy)),
      );
      enemy.hp = 300;
      await tester.pumpWidget(encounter([enemy]));
      expect(tester.widget<Text>(current).style!.color, RetroTheme.ega(10));
      expect(find.textContaining(oldName), findsNothing);
      // EncounterEnemy does not admit an empty roster (its average divides
      // by zero); returning to a field frame removes the previous roster.
      await tester.pumpWidget(const SizedBox.shrink());
      expect(current, findsNothing);
    },
  );
  for (var command = 0; command <= 7; command++) {
    testWidgets('native command $command clears before its submenu/action', (
      tester,
    ) async {
      var clears = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BattleViewportView(
              sourceReplay: true,
              partyMembers: [
                PartyMember.createPreset(1),
                PartyMember.createPreset(1),
              ],
              enemies: [Monster.create(1)],
              espAccessGranted: false,
              onLog: (_) {},
              onClearMessageWindow: () => clears++,
              onVictory: (_) {},
              onTelepathyJoin: (_) {},
              onDefeat: () {},
              onRunAway: () {},
            ),
          ),
        ),
      );
      if (command == 0) {
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      } else {
        await tester.tap(find.byKey(ValueKey('battle-cmd-$command')));
      }
      await tester.pump();
      final row = (fixture['commands'] as List)[command];
      expect(clears, (row['events'] as List).length);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  }
  testWidgets('dead selected row stays invisible and retains target slot', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BattleViewportView(
            sourceReplay: true,
            partyMembers: [PartyMember.createPreset(1)],
            enemies: [Monster.create(1)..isDead = true, Monster.create(2)],
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
    final row = find.byKey(const ValueKey('enemy-0'));
    final text = tester.widget<Text>(
      find.descendant(of: row, matching: find.byType(Text)),
    );
    expect(text.style!.color, Colors.transparent);
    expect(row, findsOneWidget);
    await tester.tap(row);
    await tester.pump();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('battle-target-preview')))
          .data,
      Monster.create(1).name,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

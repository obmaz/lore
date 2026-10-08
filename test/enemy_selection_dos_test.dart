import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_enemy_selection.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/theme/retro_theme.dart';
import 'package:lore/widgets/battle_viewport_view.dart';

// LORESUB.PAS SelectEnemy cursor/HP/dead gates; native BGI raster excluded.
void main() {
  final data = jsonDecode(
    File('test/fixtures/dos_enemy_selection.json').readAsStringSync(),
  );
  test('all byte keys/scans at every slot/count and all signed HP colours match native', () {
    for (final r in data['keys']) {
      final state = LoreEnemySelection(r['count'], number: r['number']);
      expect(state.readKey(r['key'], scan: r['scan']), r['accepted']);
      expect(state.number, r['after']);
    }
    final enemy = Monster.create(1);
    for (var hp = -32768; hp <= 32767; hp++) {
      enemy.hp = hp;
      expect(
        LoreEnemySelection.color(enemy, highlighted: false),
        data['colours'][hp + 32768],
      );
    }
    for (final r in data['states']) {
      enemy
        ..hp = r['hp']
        ..isPoisoned = (r['flags'] & 1) != 0
        ..isUnconscious = (r['flags'] & 2) != 0
        ..isDead = (r['flags'] & 4) != 0;
      expect(LoreEnemySelection.color(enemy, highlighted: false), r['color']);
      expect(LoreEnemySelection.color(enemy), r['highlight']);
    }
  });
  testWidgets(
    'actual arrow target wraps across all counts and accepts corpses/unconscious',
    (tester) async {
      for (var count = 1; count <= 7; count++) {
        final enemies = [for (var i = 0; i < count; i++) Monster.create(1)];
        enemies.first
          ..isDead = true
          ..hp = 300;
        if (count > 1) {
          enemies.last
            ..isUnconscious = true
            ..hp = 100;
        }
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BattleViewportView(
                key: UniqueKey(),
                partyMembers: [PartyMember.createPreset(1)],
                enemies: enemies,
                random: Random(1),
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
        Text preview() => tester.widget<Text>(
          find.byKey(const ValueKey('battle-target-preview')),
        );
        expect(preview().style!.color, RetroTheme.ega(7));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
        expect(preview().style!.color, RetroTheme.ega(count == 1 ? 7 : 14));
        for (var i = 0; i < count; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.pump();
        }
        expect(preview().style!.color, RetroTheme.ega(count == 1 ? 7 : 14));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(preview().style!.color, RetroTheme.ega(7));
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

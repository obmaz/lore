import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_battle_menus.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/models/spell.dart';
import 'package:lore/widgets/battle_viewport_view.dart';
import 'package:lore/widgets/lore_select_view.dart';

// LOREBATT.PAS BattleMode manual menu level CASEs and source ReturnMagic loops.
void main() {
  final rows =
      jsonDecode(
            File('test/fixtures/dos_battle_menus.json').readAsStringSync(),
          )['cases']
          as List;
  final labels = jsonDecode(
    File('test/fixtures/source_sub_labels.json').readAsStringSync(),
  )['labels']['ReturnMagic']['values'];
  test(
    'all byte levels and all attack ranges match actual native Select maxsum',
    () {
      expect(rows.length, 768);
      for (final row in rows) {
        expect(LoreBattleMenus.maxsum(row['how'], row['level']), row['maxsum']);
        final low = (row['how'] - 2) * 6 + 1;
        final available = Spell.allSpells
            .where(
              (s) =>
                  s.id >= low &&
                  s.id < low + 6 &&
                  s.isAvailableForLevel(row['level'], 0),
            )
            .length;
        expect(available + 1, row['maxsum']);
      }
    },
  );
  Future<void> open(WidgetTester tester, int level) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BattleViewportView(
            key: UniqueKey(),
            partyMembers: [
              PartyMember.createPreset(3)..magicLevel = level,
              PartyMember.createPreset(4),
            ],
            enemies: [for (var i = 0; i < 7; i++) Monster.create(1)],
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
  }

  testWidgets(
    'every native level CASE and original full menu texts reach actual UI',
    (tester) async {
      for (final row in rows) {
        await open(tester, row['level']);
        await tester.tap(find.byKey(ValueKey('battle-cmd-${row['how']}')));
        await tester.pumpAndSettle();
        final select = tester.widget<LoreSelectView>(
          find.byType(LoreSelectView),
        );
        expect(
          select.maxsum,
          row['maxsum'],
          reason: 'how=${row['how']} level=${row['level']}',
        );
        final first = (row['how'] - 2) * 6 + 1;
        expect(select.items, [
          '없음',
          for (var id = first; id < first + 6; id++) labels['$id'],
        ]);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
      }
      for (final level in [0, 1, 17, 255]) {
        await open(tester, level);
        await tester.tap(find.byKey(const ValueKey('battle-cmd-6')));
        await tester.pumpAndSettle();
        final select = tester.widget<LoreSelectView>(
          find.byType(LoreSelectView),
        );
        expect(select.maxsum, 5);
        expect(select.items, [for (var id = 41; id <= 45; id++) labels['$id']]);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

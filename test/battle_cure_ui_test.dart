import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_batt_text.dart';
import 'package:lore/logic/lore_cast_spell.dart';
import 'package:lore/logic/lore_menu_text.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/widgets/battle_viewport_view.dart';

/// LOREMENU.PAS `CureSpell` as `5 : CureSpell` of LOREBATT.PAS `BattleMode`.
void main() {
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> open(
    WidgetTester tester,
    List<PartyMember> party,
    List<String> logs,
  ) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: BattleViewportView(
          partyMembers: party,
          enemies: [Monster.create(1)..hp = 30000],
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

  testWidgets(
    'the cure runs at once, ends with a key wait and passes the turn',
    (tester) async {
      final mage = PartyMember.createPreset(3)
        ..magicLevel = 4
        ..sp = 100;
      final knight = PartyMember.createPreset(1)..hp = 1;
      final logs = <String>[];
      await open(tester, [mage, knight], logs);
      expect(
        find.text('${mage.name}${LoreBattText.battleMode}'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('battle-cmd-5')));
      await settle(tester);
      // `누구에게`: slots 1..5 by name (empty ones too) and 모든 사람들에게.
      expect(find.text(LoreCastSpell.toWhom), findsOneWidget);
      expect(find.text(LoreCastSpell.everyone), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('lore-select-2')));
      await settle(tester);
      // level div 2 + 1 = 3 spells (the rest are drawn but not selectable).
      expect(find.text(LoreMenuText.phenominaSelect), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('lore-select-1')));
      await settle(tester);
      // Both results are printed with the two blank lines and `PressAnyKey`.
      expect(find.text('${knight.name}는 치료되어 졌습니다.'), findsOneWidget);
      expect(knight.hp, greaterThan(1));
      expect(mage.sp, 100 - 2 * mage.magicLevel);
      expect(
        find.text('${knight.name}${LoreBattText.battleMode}'),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('lore-press-any-key')));
      await settle(tester);
      expect(logs, contains('${knight.name}는 치료되어 졌습니다.'));
      // The turn of the caster is spent: the next member chooses.
      expect(
        find.text('${knight.name}${LoreBattText.battleMode}'),
        findsOneWidget,
      );
    },
  );

  testWidgets('refusals are silent in battle and Esc still passes the turn', (
    tester,
  ) async {
    final mage = PartyMember.createPreset(3)
      ..magicLevel = 4
      ..sp = 100;
    final knight = PartyMember.createPreset(1); // unhurt
    final logs = <String>[];
    await open(tester, [mage, knight], logs);
    await tester.tap(find.byKey(const ValueKey('battle-cmd-5')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('lore-select-2')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('lore-select-1')));
    await settle(tester);
    // `치료할 필요가 없습니다` is guarded by `party.etc[6] = 0`: nothing printed,
    // only the two blank lines and the key wait remain.
    expect(find.textContaining('치료할 필요가'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('lore-press-any-key')));
    await settle(tester);
    expect(
      find.text('${knight.name}${LoreBattText.battleMode}'),
      findsOneWidget,
    );
    expect(mage.sp, 100);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/logic/lore_batt_text.dart';
import 'package:lore/logic/lore_sub_text.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/widgets/battle_viewport_view.dart';

/// LOREBATT.PAS BattleMode menu m[0..7] and the ReturnMessage prints.
void main() {
  Future<List<String>> open(
    WidgetTester tester,
    List<PartyMember> party,
  ) async {
    final logs = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BattleViewportView(
            partyMembers: party,
            enemies: [Monster.create(1)],
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
    return logs;
  }

  testWidgets('command labels are the source menu strings', (tester) async {
    final hero = PartyMember.createPreset(1)..weapon = 4;
    await open(tester, [hero]);
    String label(int n) => tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(ValueKey('battle-cmd-$n')),
            matching: find.byType(Text),
          ),
        )
        .data!;
    expect(label(1), '한 명의 적을 장검으로 공격');
    expect(label(2), '한 명의 적에게 마법 공격');
    expect(label(3), '모든 적에게 마법 공격');
    expect(label(4), '적에게 특수 마법 공격');
    expect(label(5), '일행을 치료');
    expect(label(6), '적에게 초능력 사용');
    expect(label(7), '일행에게 무조건 공격 할 것을 지시');
    hero.weapon = 1;
    await tester.pumpWidget(const SizedBox.shrink());
    final other = PartyMember.createPreset(3)..weapon = 1;
    await open(tester, [PartyMember.createPreset(1), other]);
    expect(label(1).startsWith('한 명의 적을 '), isTrue);
  });

  testWidgets(
    'a locked special spell prints ReturnMessage how 4, then refuses and spends the turn',
    (tester) async {
      LoreDialogueManager.instance.loadFlags({});
      final hero = PartyMember.createPreset(3)
        ..magicLevel = 20
        ..sp = 500;
      final other = PartyMember.createPreset(4);
      final logs = await open(tester, [hero, other]);
      await tester.tap(find.byKey(const ValueKey('battle-cmd-4')));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();
      expect(
        logs.first,
        LoreSubText.returnMessage(
          actor: hero.name,
          how: 4,
          what: 1,
          target: 'Orc',
        ),
      );
      expect(logs[1], LoreBattText.noAbility);
      // The turn was spent: the next party member is active.
      expect(
        find.text('${other.name}${LoreBattText.battleMode}'),
        findsOneWidget,
      );
    },
  );
}

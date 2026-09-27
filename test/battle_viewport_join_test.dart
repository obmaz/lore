import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_join.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/widgets/battle_viewport_view.dart';

void main() {
  testWidgets('전투 화면의 독심 성공은 적을 6번 슬롯에 즉시 합류시킨다', (tester) async {
    final caster = PartyMember.createPreset(3)
      ..espLevel = 20
      ..esp = 15
      ..accEsp = 100;
    final party = [
      caster,
      for (var i = 1; i < 5; i++) PartyMember.createPreset(i + 1),
    ];
    final enemy = Monster.create(10);
    int? joinedId;
    var victories = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BattleViewportView(
            partyMembers: party,
            enemies: [enemy],
            espAccessGranted: false,
            onLog: (_) {},
            onVictory: (_) => victories++,
            onTelepathyJoin: (id) {
              joinedId = id;
              LoreJoin.applyJoin(
                party,
                LoreJoin.telepathyRecruit(id),
                LoreJoin.forcedSixthSlotOption,
              );
            },
            onDefeat: () {},
            onRunAway: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('6.초능력'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('독심'));
    await tester.pump();

    expect(joinedId, 10);
    expect(party, hasLength(6));
    expect(party[5].name, Monster.create(10).name);
    expect(enemy.isDead, isTrue);
    expect(caster.esp, 0);
    expect(victories, 1);
  });
}

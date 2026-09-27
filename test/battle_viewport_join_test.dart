import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/battle_engine.dart';
import 'package:lore/logic/lore_join.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/widgets/battle_viewport_view.dart';

class _ZeroRandom implements Random {
  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}

class _OpeningTurnEngine extends BattleEngine {
  int monsterTurns = 0;

  @override
  List<AttackResult> executeMonsterTurn(
    Monster monster,
    List<PartyMember> party,
    List<Monster> allEnemies,
  ) {
    monsterTurns++;
    return const [AttackResult(outcome: AttackOutcome.miss, message: '적의 선공')];
  }
}

void main() {
  testWidgets('적 선공 전투는 파티 입력 전에 적 턴을 실행한다', (tester) async {
    final engine = _OpeningTurnEngine();
    final logs = <String>[];
    Widget battle(int serial) => MaterialApp(
      home: Scaffold(
        body: BattleViewportView(
          key: ValueKey(serial),
          partyMembers: [PartyMember.createPreset(1)],
          enemies: [Monster.create(1)],
          battleEngine: engine,
          enemyFirst: true,
          espAccessGranted: false,
          onLog: logs.add,
          onVictory: (_) {},
          onTelepathyJoin: (_) {},
          onDefeat: () {},
          onRunAway: () {},
        ),
      ),
    );
    await tester.pumpWidget(battle(1));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 200));
    expect(engine.monsterTurns, 1);
    expect(logs.first, '적의 선공');
    await tester.pumpWidget(battle(2));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 200));
    expect(engine.monsterTurns, 2); // 연속 전투도 첫 턴을 다시 실행한다.
    expect(tester.takeException(), isNull);
  });

  testWidgets('전투 턴 중 소환된 적은 다음 턴으로 미루고 화면 목록에 추가한다', (tester) async {
    final hero = PartyMember.createPreset(1)..hp = 10000;
    final caster = Monster.create(62).withOverrides(special: 0, castLevel: 0);
    final enemies = [caster];
    final logs = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BattleViewportView(
            partyMembers: [hero],
            enemies: enemies,
            battleEngine: BattleEngine(random: _ZeroRandom()),
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

    await tester.tap(find.text('1.무기공격'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(enemies, hasLength(2));
    expect(enemies.last.eNumber, 42);
    expect(logs.where((message) => message.contains('소환했다')), hasLength(1));
    expect(find.textContaining(enemies.last.name), findsWidgets);
  });

  testWidgets('전투 화면은 비워진 동료 슬롯과 HP 0 대원을 턴에서 제외한다', (tester) async {
    final party = [
      PartyMember.createPreset(1)..name = '',
      PartyMember.createPreset(3)..hp = 0,
      PartyMember.createPreset(4),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BattleViewportView(
            partyMembers: party,
            enemies: [Monster.create(1)],
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

    expect(find.text('▶ [${party[2].name}] 의 전투 턴'), findsOneWidget);
  });

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

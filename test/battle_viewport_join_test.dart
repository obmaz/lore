import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_batt_text.dart';
import 'package:lore/logic/lore_join.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/widgets/battle_viewport_view.dart';

import 'support/battle_keys.dart';

/// Every `random(n)` returns n - 1 (always misses / always the last choice).
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

void main() {
  testWidgets('파티와 적이 모두 행동 불능이면 원본 순서대로 패배한다', (tester) async {
    final hero = PartyMember.createPreset(1)..hp = 0;
    final enemy = Monster.create(1)..isUnconscious = true;
    var victories = 0;
    var defeats = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BattleViewportView(
            partyMembers: [hero],
            enemies: [enemy],
            enemyFirst: true,
            espAccessGranted: false,
            onLog: (_) {},
            onVictory: (_) => victories++,
            onTelepathyJoin: (_) {},
            onDefeat: () => defeats++,
            onRunAway: () {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    // `c := ReadKey` comes before the defeat is acted on.
    expect((defeats, victories), (0, 0));
    await pressBattleKey(tester);
    expect((defeats, victories), (1, 0));
  });

  testWidgets('기절한 중독 적도 적 턴에서 독으로 사망한다', (tester) async {
    final enemy = Monster.create(1)
      ..hp = 0
      ..isUnconscious = true
      ..isPoisoned = true;
    var victories = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BattleViewportView(
            partyMembers: [PartyMember.createPreset(1)],
            enemies: [enemy],
            enemyFirst: true,
            espAccessGranted: false,
            onLog: (_) {},
            onVictory: (_) => victories++,
            onTelepathyJoin: (_) {},
            onDefeat: () {},
            onRunAway: () {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await pressBattleKey(tester);
    expect(enemy.isDead, isTrue);
    expect(victories, 1);
  });

  testWidgets('적 선공 전투는 파티 입력 전에 적 단계를 실행한다 (BattleMode(FALSE))', (
    tester,
  ) async {
    final logs = <String>[];
    Widget battle(int serial) => MaterialApp(
      home: Scaffold(
        body: BattleViewportView(
          key: ValueKey(serial),
          partyMembers: [PartyMember.createPreset(1)],
          enemies: [Monster.create(1)],
          random: _MaxRandom(),
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
    // Orc 가 먼저 행동했다: `random(20) >= accuracy[1]` 이면 `빗맞추었다`.
    expect(logs.first, endsWith(LoreBattText.partyMissed));
    final first = logs.length;
    await tester.pumpWidget(battle(2));
    await tester.pump(const Duration(milliseconds: 300));
    expect(logs.length, greaterThan(first)); // 연속 전투도 첫 단계를 다시 실행한다.
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
            random: _ZeroRandom(),
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
    await tester.pumpAndSettle();
    await pressBattleKey(tester); // PressAnyKey after the party phase
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(enemies, hasLength(2));
    expect(enemies.last.eNumber, 42);
    expect(logs.where((message) => message.endsWith('를 생성시켰다')), hasLength(1));
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

    expect(
      find.text('${party[2].name}${LoreBattText.battleMode}'),
      findsOneWidget,
    );
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

    await tester.tap(find.byKey(const ValueKey('battle-cmd-6')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('독심'));
    await tester.pump();
    // 나머지 네 명도 명령을 고른 뒤에야 라운드가 실행된다.
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const ValueKey('battle-cmd-1')));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 1500));
    await pressBattleKey(tester); // PressAnyKey after the party phase
    await pressBattleKey(tester); // c := ReadKey after the enemy phase

    expect(joinedId, 10);
    expect(party, hasLength(6));
    expect(party[5].name, Monster.create(10).name);
    expect(enemy.isDead, isTrue);
    expect(caster.esp, 0);
    expect(victories, 1);
  });
}

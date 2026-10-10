import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_battle.dart';
import 'package:lore/logic/lore_game_option.dart';
import 'package:lore/logic/lore_transient_slots.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/party_member.dart';

class _Random implements Random {
  _Random(this.values);
  final List<int> values;
  final List<int> bounds = [];
  @override
  int nextInt(int max) {
    bounds.add(max);
    final value = values.removeAt(0);
    expect(value, inInclusiveRange(0, max - 1));
    return value;
  }

  @override
  bool nextBool() => throw UnimplementedError();
  @override
  double nextDouble() => throw UnimplementedError();
}

void main() {
  List<PartyMember> party() => [
    for (var i = 1; i <= 6; i++)
      PartyMember.createPreset(1)
        ..name = 'Player$i'
        ..endurance = i * 10
        ..battleLevel = i,
  ];

  final fixture = jsonDecode(
    File('test/fixtures/dos_recruit_storage.json').readAsStringSync(),
  );
  for (final row in fixture['mindCalls']) {
    test('DOS SpecialCastAttack pushes player ${row['k']} then enemy 6', () {
      expect([row['player'], row['enemy']], [row['k'], 6]);
    });
  }

  test(
    'short battle writes inactive enemy6, preserving active and older slots',
    () {
      final members = party();
      final slots = LoreTransientSlots();
      final oldThird = Monster.create(30)
        ..hp = -10
        ..isDead = true;
      slots.enemies[2] = oldThird;
      final foe = Monster.create(20)..specialCastLevel = 2;
      final active = [foe, Monster.create(1)];
      final random = _Random([1, 1, 0]);
      final messages = <String>[];
      final battle = LoreBattle(
        party: members,
        enemy: active,
        slots: slots,
        random: random,
        print: (_, s) => messages.add(s),
      );
      battle.specialCastAttack();
      expect(active, hasLength(3));
      expect(active[2], same(oldThird));
      expect(slots.enemies[5]!.name, 'Player3');
      expect(slots.enemies[5]!.hp, 90);
      expect(members[5].name, '');
      expect(messages.single, contains(oldThird.name));
      expect(random.bounds, [3, 3, 5]);
      // A shorter subsequent encounter does not overwrite the inactive record.
      LoreBattle(
        party: members,
        enemy: [Monster.create(1)],
        slots: slots,
        random: Random(1),
        print: (_, _) {},
      );
      expect(slots.enemies[5]!.name, 'Player3');
      expect(slots.enemies[2], same(oldThird));
    },
  );

  test('unwritten added slot stays zero instead of becoming an Orc', () {
    final slots = LoreTransientSlots();
    final battle = LoreBattle(
      party: party(),
      enemy: [Monster.create(20)..specialCastLevel = 2, Monster.create(1)],
      slots: slots,
      random: _Random([1, 1, 0]),
      print: (_, _) {},
    );
    battle.specialCastAttack();
    final added = battle.enemy[2];
    expect([added.eNumber, added.name, added.hp, added.level], [0, '', 0, 0]);
    expect(added.isDead, isFalse);
    expect(slots.enemies[5]!.name, 'Player3');
  });

  test('caster6 sees overwritten fields and does not perform death attack', () {
    final members = party();
    final slots = LoreTransientSlots();
    LoreGameOption.swap(members, 2, 3, slots: slots);
    // Move copied all fields; later edits to the moved party record do not alias.
    members[2].name = 'Changed after swap';
    expect(slots.seventhPlayer.name, 'Player2');
    final active = [for (var i = 0; i < 6; i++) Monster.create(20)];
    active[5]
      ..specialCastLevel = 3
      ..special = 2;
    final random = _Random([0, 0]);
    final messages = <String>[];
    final battle = LoreBattle(
      party: members,
      enemy: active,
      slots: slots,
      random: random,
      print: (_, s) => messages.add(s),
    )..person = 6;
    battle.specialCastAttack();
    expect(active, hasLength(7));
    expect(active[5].name, 'Player2');
    expect(active[5].hp, 40);
    expect(active[5].specialCastLevel, 0);
    expect(active[6].name, '');
    expect(messages.single, startsWith('Player2가'));
    expect(members[5].name, '');
    expect(members.take(5).every((p) => p.dead == 0), isTrue);
    expect(random.bounds, [3, 5]);
  });

  test('full battle uses lowest dead k as player index, writes enemy6', () {
    final members = party();
    final active = [for (var i = 0; i < 7; i++) Monster.create(20)];
    active[0].specialCastLevel = 2;
    active[2].isDead = true;
    final oldDead = active[2];
    final random = _Random([0, 0]);
    final battle = LoreBattle(
      party: members,
      enemy: active,
      random: random,
      print: (_, _) {},
    );
    battle.specialCastAttack();
    expect(active, hasLength(7));
    expect(active[2], same(oldDead));
    expect(active[5].name, 'Player3');
    expect(active[5].hp, 90);
    expect(members[5].name, '');
    expect(random.bounds, [3, 5]);
  });

  test('EnemyAttack reads replacement caster after SpecialCastAttack', () {
    final members = party();
    final slots = LoreTransientSlots();
    final caster = PartyMember.createPreset(1)
      ..name = 'Scratch'
      ..strength = 0
      ..mentality = 0
      ..accArms = 0
      ..accMagic = 0
      ..agility = 0;
    slots.rememberSwapPlayer(caster);
    final active = [for (var i = 0; i < 6; i++) Monster.create(20)];
    active[5]
      ..specialCastLevel = 3
      ..special = 2;
    final random = _Random([0, 0, 0, 0]);
    final battle = LoreBattle(
      party: members,
      enemy: active,
      slots: slots,
      random: random,
      print: (_, _) {},
    )..person = 6;
    battle.enemyAttack();
    expect(active[5].name, 'Scratch');
    expect(random.bounds, [
      3,
      5,
      1,
      1,
    ]); // Random(0) adapter advances via nextInt(1).
  });
}

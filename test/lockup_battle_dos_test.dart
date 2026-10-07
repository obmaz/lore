import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_battle.dart';
import 'package:lore/logic/lore_random.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/models/monster.dart';

import 'wivern_battle_dos_test.dart' show enemyRecord;

void main() {
  final f = jsonDecode(
    File('test/fixtures/dos_lockup_continuation.json').readAsStringSync(),
  );
  final inputs = [
    for (final s in f['segments'])
      if (s.containsKey('trace'))
        for (final b in s['trace'])
          if (b.containsKey('input')) b['input'],
  ];
  dynamic input(int n) =>
      inputs.singleWhere((i) => i['capture'] == 'lore_$n.png');
  for (final cfg in [(9422, 9424, false), (9679, 9701, true)]) {
    test(
      'native LOCKUP ${cfg.$3 ? 'Huge Dragon seven-slot rolls' : 'Minotaur'} enemy first preserves all records and RNG',
      () {
        final s = input(cfg.$1)['before'];
        final random = LoreRandom(s['seed']);
        final enemy = cfg.$3
            ? <Monster>[
                named(Monster.create(54), 'Huge Dragon'),
                named(Monster.create(39), "Dragon's tail")..ac = 8,
                for (var i = 0; i < 5; i++)
                  Monster.create(random.nextInt(3) + 30),
              ]
            : [Monster.create(53)];
        final b = LoreBattle(
          party: [
            for (final r in s['records'])
              PartyMember.fromJson(Map<String, dynamic>.from(r)),
          ],
          enemy: enemy,
          random: random,
          print: (_, _) {},
        );
        b.enemyPhase();
        final end = input(cfg.$2)['after'];
        expect(random.seed, end['seed']);
        expect(b.party.map((p) => p.toJson()).toList(), end['records']);
        expect(b.enemy.map(enemyRecord).toList(), end['enemyRecords']);
      },
    );
  }
  test('native Huge Dragon final roster earns original template gold41567 without RNG', () {
    final s = input(11260)['after'];
    final random = LoreRandom(s['seed']);
    final b = LoreBattle(
      party: [
        for (final r in s['records'])
          PartyMember.fromJson(Map<String, dynamic>.from(r)),
      ],
      enemy: [for (final r in s['enemyRecords']) Monster.create(r['eNumber'])],
      random: random,
      print: (_, _) {},
    );
    expect(b.plusGold(), 41567);
    expect(random.seed, s['seed']);
  });
}

Monster named(Monster m, String name) => Monster(
  eNumber: m.eNumber,
  name: name,
  strength: m.strength,
  mentality: m.mentality,
  endurance: m.endurance,
  resistance: m.resistance,
  agility: m.agility,
  accArms: m.accArms,
  accMagic: m.accMagic,
  ac: m.ac,
  special: m.special,
  castLevel: m.castLevel,
  specialCastLevel: m.specialCastLevel,
  level: m.level,
  hp: m.hp,
);

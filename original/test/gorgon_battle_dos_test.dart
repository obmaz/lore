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
    File('test/fixtures/dos_swamp_gate_continuation.json').readAsStringSync(),
  );
  final inputs = [
    for (final s in f['segments'])
      if (s.containsKey('trace'))
        for (final b in s['trace'])
          if (b.containsKey('input')) b['input'],
  ];
  dynamic row(int n) =>
      inputs.singleWhere((i) => i['capture'] == 'lore_$n.png');
  test('native Gorgon enemy-first phase preserves three overrides, all six records and RNG', () {
    final s = row(12570)['before'];
    final random = LoreRandom(s['seed']);
    final b = LoreBattle(
      party: [
        for (final r in s['records'])
          PartyMember.fromJson(Map<String, dynamic>.from(r)),
      ],
      enemy: [
        for (final id in [50, 51, 52])
          Monster.create(id).withOverrides(eNumber: 1),
      ],
      random: random,
      print: (_, _) {},
    );
    b.enemyPhase();
    final end = row(12570)['after'];
    expect(random.seed, end['seed']);
    expect(b.party.map((p) => p.toJson()).toList(), end['records']);
    expect(b.enemy.map(enemyRecord).toList(), end['enemyRecords']);
  });
  test('native Gorgon targeted round, corpse finish and next enemy phase preserve records and RNG', () {
    final s = row(12570)['after'];
    final random = LoreRandom(s['seed']);
    Monster enemy(dynamic r) => Monster(
      eNumber: r['eNumber'],
      name: r['name'],
      strength: r['strength'],
      mentality: r['mentality'],
      endurance: r['endurance'],
      resistance: r['resistance'],
      agility: r['agility'],
      accArms: r['accArms'],
      accMagic: r['accMagic'],
      ac: r['ac'],
      special: r['special'],
      castLevel: r['castLevel'],
      specialCastLevel: r['specialCastLevel'],
      level: r['level'],
      hp: r['hp'],
      isPoisoned: r['isPoisoned'],
      isUnconscious: r['isUnconscious'],
      isDead: r['isDead'],
    );
    final b = LoreBattle(
      party: [
        for (final r in s['records'])
          PartyMember.fromJson(Map<String, dynamic>.from(r)),
      ],
      enemy: [for (final r in s['enemyRecords']) enemy(r)],
      random: random,
      print: (_, _) {},
    );
    final commands = row(12595)['after']['commands'];
    for (var i = 1; i <= 6; i++) {
      b.battle[i] = [0, ...List<int>.from(commands[i - 1])];
    }
    for (var i = 1; i <= 6; i++) {
      if (b.exist(i)) b.executePerson(i);
    }
    final closed = f['segments'].lastWhere(
      (segment) => segment.containsKey('gap') as bool,
    )['gap']['after'];
    void check(dynamic end) {
      expect(random.seed, end['seed']);
      expect(b.party.map((p) => p.toJson()).toList(), end['records']);
      expect(b.enemy.map(enemyRecord).toList(), end['enemyRecords']);
    }

    check(closed);
    b.enemyPhase();
    check(row(12607)['before']);
  });
}

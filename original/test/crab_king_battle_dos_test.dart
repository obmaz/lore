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
    File('test/fixtures/dos_evil_god_first_attempt.json').readAsStringSync(),
  );
  final inputs = [
    for (final segment in f['segments'])
      if (segment.containsKey('trace'))
        for (final block in segment['trace'])
          if (block.containsKey('input')) block['input'],
  ];
  dynamic row(int n) =>
      inputs.singleWhere((i) => i['capture'] == 'lore_$n.png');
  test('native Crab King seven enemies and enemy-first phase preserve all records and RNG', () {
    final s = row(13309)['before'];
    final random = LoreRandom(s['seed']);
    final b = LoreBattle(
      party: [
        for (final r in s['records'])
          PartyMember.fromJson(Map<String, dynamic>.from(r)),
      ],
      enemy: [
        for (var i = 0; i < 7; i++)
          if (i < 3)
            Monster.create(59)
          else
            Monster.create(59).withOverrides(eNumber: 25, hp: 210, level: 7),
      ],
      random: random,
      print: (_, _) {},
    );
    b.enemyPhase();
    final end = row(13318)['before'];
    expect(random.seed, end['seed']);
    expect(b.party.map((p) => p.toJson()).toList(), end['records']);
    expect(b.enemy.map(enemyRecord).toList(), end['enemyRecords']);
  });
  test('native SWAMP KEEP exit guard enemy-first phase preserves all records and RNG', () {
    final s = row(12683)['before'];
    final random = LoreRandom(s['seed']);
    final b = LoreBattle(
      party: [
        for (final r in s['records'])
          PartyMember.fromJson(Map<String, dynamic>.from(r)),
      ],
      enemy: [
        for (final id in [55, 56, 35, 35, 35, 35, 35]) Monster.create(id),
      ],
      random: random,
      print: (_, _) {},
    );
    b.enemyPhase();
    final end = row(12709)['before'];
    expect(random.seed, end['seed']);
    expect(b.party.map((p) => p.toJson()).toList(), end['records']);
    expect(b.enemy.map(enemyRecord).toList(), end['enemyRecords']);
  });
  test('native Crab King targeted round and second enemy phase preserve all fields and RNG', () {
    final initial = row(13318)['before'];
    final random = LoreRandom(initial['seed']);
    final b = LoreBattle(
      party: [
        for (final r in initial['records'])
          PartyMember.fromJson(Map<String, dynamic>.from(r)),
      ],
      enemy: [
        for (var i = 0; i < 7; i++)
          if (i < 3)
            Monster.create(59)
          else
            Monster.create(59).withOverrides(eNumber: 25, hp: 210, level: 7),
      ],
      random: random,
      print: (_, _) {},
    );
    final commands = row(13332)['after']['commands'];
    for (var i = 1; i <= 6; i++) {
      b.battle[i] = [0, ...List<int>.from(commands[i - 1])];
    }
    for (var i = 1; i <= 6; i++) {
      if (b.exist(i)) b.executePerson(i);
    }
    final closed = inputs.firstWhere(
      (r) =>
          r['after']['seed'] == 1480930969 && r['after']['live']['person'] == 6,
    )['after'];
    void check(dynamic end) {
      expect(random.seed, end['seed']);
      expect(b.party.map((p) => p.toJson()).toList(), end['records']);
      expect(b.enemy.map(enemyRecord).toList(), end['enemyRecords']);
    }

    check(closed);
    b.enemyPhase();
    check(row(13348)['before']);
  });
}

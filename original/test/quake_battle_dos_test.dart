import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_battle.dart';
import 'package:lore/logic/lore_random.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/models/monster.dart';

void main() {
  final f = jsonDecode(
    File('test/fixtures/dos_quake_continuation.json').readAsStringSync(),
  );
  final inputs = [
    for (final e in f['epochs'])
      for (final b in e['trace'])
        if (b.containsKey('input')) b['input'],
  ];
  dynamic phase(int n) =>
      inputs.singleWhere((i) => i['capture'] == 'lore_$n.png')['after'];
  test('native QUAKE enemy opening, three targeted rounds, boss knockout and escapes', () {
    final s = phase(1260);
    final random = LoreRandom(s['seed']);
    final b = LoreBattle(
      party: [
        for (final r in s['records'])
          PartyMember.fromJson(Map<String, dynamic>.from(r)),
      ],
      enemy: [
        Monster.create(36).withOverrides(name: 'Zombie'),
        Monster.create(36).withOverrides(name: 'Zombie'),
        Monster.create(42).withOverrides(name: 'ArchiGagoyle'),
      ],
      random: random,
      print: (_, _) {},
    );
    void check(int n) {
      final s = phase(n);
      expect(random.seed, s['seed'], reason: 'phase $n seed');
      expect(
        b.party.map((p) => p.toJson()).toList(),
        s['records'],
        reason: 'phase $n party',
      );
      expect(
        b.enemy.map(enemyRecord).toList(),
        s['enemyRecords'],
        reason: 'phase $n enemy',
      );
    }

    void execute(int n) {
      final s = phase(n);
      for (var i = 1; i <= 6; i++) {
        b.battle[i] = [0, ...List<int>.from(s['commands'][i - 1])];
      }
      for (var i = 1; i <= 6; i++) {
        if (b.exist(i)) b.executePerson(i);
      }
      check(n);
    }

    b.enemyPhase();
    check(1263);
    execute(1317);
    b.enemyPhase();
    check(1323);
    execute(1349);
    b.enemyPhase();
    check(1357);
    execute(1373);
    expect(b.enemy[2].hp, 0);
    expect(b.enemy[2].isUnconscious, true);
    b.enemyPhase();
    check(1379);
    execute(1385);
    b.enemyPhase();
    check(1389);
    execute(1397);
    b.enemyPhase();
    check(1403);
    final s2 = phase(1409);
    b.battle[4] = [0, ...List<int>.from(s2['commands'][3])];
    expect(b.executePerson(4), true);
    check(1409);
  });
}

Map<String, dynamic> enemyRecord(Monster e) => {
  'eNumber': e.eNumber,
  'name': e.name,
  'strength': e.strength,
  'mentality': e.mentality,
  'endurance': e.endurance,
  'resistance': e.resistance,
  'agility': e.agility,
  'accArms': e.accArms,
  'accMagic': e.accMagic,
  'ac': e.ac,
  'special': e.special,
  'castLevel': e.castLevel,
  'specialCastLevel': e.specialCastLevel,
  'level': e.level,
  'hp': e.hp,
  'isPoisoned': e.isPoisoned,
  'isUnconscious': e.isUnconscious,
  'isDead': e.isDead,
};

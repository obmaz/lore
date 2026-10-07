import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_battle.dart';
import 'package:lore/logic/lore_random.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/models/monster.dart';

// Actual unmodified DOS phases, including Sphinx's retained template HP.
void main() {
  final f = jsonDecode(
    File('test/fixtures/dos_pyramid_battle.json').readAsStringSync(),
  );
  dynamic observed(int n) => (f['inputs'] as List).singleWhere(
    (s) => s['capture'] == 'lore_${n.toString().padLeft(3, '0')}.png',
  )['after'];
  List<Monster> enemies() => [
    for (var i = 0; i < 2; i++)
      Monster.create(35)
          .withOverrides(name: 'Sphinx', level: 4, special: 0, eNumber: 20),
    Monster.create(26).withOverrides(name: 'Major Mummy', ac: 1),
  ];
  List<PartyMember> party(dynamic s) => [
    for (final r in s['records'])
      PartyMember.fromJson(Map<String, dynamic>.from(r)),
  ];
  void check(LoreBattle b, LoreRandom random, dynamic s) {
    expect(random.seed, s['seed']);
    expect(b.party.map((p) => p.toJson()).toList(), s['records']);
    expect(b.enemy.map(_enemyRecord).toList(), s['enemyRecords']);
  }

  test('DOS PYRAMID enemy-first opening preserves full records and RNG', () {
    final start = observed(55);
    final random = LoreRandom(start['seed']);
    final b = LoreBattle(
      party: party(start),
      enemy: enemies(),
      random: random,
      print: (_, _) {},
    );
    b.enemyPhase();
    check(b, random, observed(64));
  });
  test('DOS PYRAMID two targeted rounds and failed escape preserve records and RNG', () {
    final start = observed(64);
    final random = LoreRandom(start['seed']);
    final b = LoreBattle(
      party: party(start),
      enemy: enemies(),
      random: random,
      print: (_, _) {},
    );
    void commandsFrom(int n) {
      final commands = observed(n)['commands'];
      for (var i = 1; i <= 6; i++) {
        b.battle[i] = [0, ...List<int>.from(commands[i - 1])];
      }
    }

    commandsFrom(78);
    for (var i = 1; i <= 6; i++) {
      if (b.exist(i)) b.executePerson(i);
    }
    check(b, random, observed(86));
    b.enemyPhase();
    check(b, random, observed(106));
    commandsFrom(108);
    for (var i = 1; i <= 6; i++) {
      if (b.exist(i)) b.executePerson(i);
    }
    check(b, random, observed(110));
    b.enemyPhase();
    check(b, random, observed(114));
    commandsFrom(116);
    expect(b.executePerson(6), false);
    check(b, random, observed(116));
    b.enemyPhase();
    check(b, random, observed(118));
    expect(b.endBattle(), 1);
  });
}

Map<String, dynamic> _enemyRecord(Monster e) => {
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

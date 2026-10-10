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
    File('test/fixtures/dos_notice_continuation.json').readAsStringSync(),
  );
  final inputs = [
    for (final b in f['trace'])
      if (b.containsKey('input')) b['input'],
  ];
  dynamic phase(int n) =>
      inputs.singleWhere((i) => i['capture'] == 'lore_$n.png')['after'];
  for (final cfg in [(8433, 8463, 8499, 8501), (9065, 9083, 9103, 0)]) {
    test(
      'native HIDRA party phase ${cfg.$1}: all records, corpse finish, retarget and RNG',
      () {
        final s = phase(cfg.$1);
        final random = LoreRandom(s['seed']);
        final b = LoreBattle(
          party: [
            for (final r in s['records'])
              PartyMember.fromJson(Map<String, dynamic>.from(r)),
          ],
          enemy: [
            for (final r in s['enemyRecords'])
              Monster(
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
              ),
          ],
          random: random,
          print: (_, _) {},
        );
        final commands = phase(cfg.$2)['commands'];
        for (var i = 1; i <= 6; i++) {
          b.battle[i] = [0, ...List<int>.from(commands[i - 1])];
        }
        void check(int n) {
          final end = phase(n);
          expect(random.seed, end['seed'], reason: 'phase $n seed');
          expect(
            b.party.map((p) => p.toJson()).toList(),
            end['records'],
            reason: 'phase $n party',
          );
          expect(
            b.enemy.map(enemyRecord).toList(),
            end['enemyRecords'],
            reason: 'phase $n enemy',
          );
        }

        for (var i = 1; i <= 6; i++) {
          if (b.exist(i)) b.executePerson(i);
        }
        check(cfg.$3);
        expect([
          for (var i = 1; i <= 6; i++) b.battle[i].skip(1).toList(),
        ], phase(cfg.$3)['commands']);
        if (cfg.$4 != 0) {
          b.enemyPhase();
          check(cfg.$4);
        }
      },
    );
  }
}

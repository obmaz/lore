import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_battle.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/logic/lore_spec_procedures.dart';
import 'package:lore/logic/lore_random.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/models/monster.dart';

void main() {
  final f = jsonDecode(
    File('test/fixtures/dos_wivern_continuation.json').readAsStringSync(),
  );
  final inputs = [
    for (final b in f['trace'])
      if (b.containsKey('input')) b['input'],
  ];
  dynamic phase(int n) =>
      inputs.singleWhere((i) => i['capture'] == 'lore_$n.png')['after'];
  test(
    'native WIVERN dead-slot progress produces the next 2/1/0 encounters',
    () {
      for (final pair in [(1812, 1813), (1895, 1896)]) {
        final before = phase(pair.$1);
        final after = phase(pair.$2);
        final engine = LoreScriptEngine();
        final run = LoreSpecProcedures.map16(
          20,
          10,
          ScriptContext(
            tileAtPlayer: 0,
            sourceEtc: {
              for (var i = 0; i < 100; i++)
                i + 1: before['partyRecord']['etc'][i],
            },
          ),
          engine,
        )!;
        final battle = run.acknowledgeScene();
        expect(battle.outcome.battleMonsters.length, before['enemyCount']);
        final dead = {
          for (var i = 0; i < before['enemyRecords'].length; i++)
            if (before['enemyRecords'][i]['isDead'] == true) i + 1,
        };
        final end = battle.continueAfterRunAway(defeatedEnemySlots: dead);
        expect(
          end.outcome.questChanges.single.set,
          after['partyRecord']['etc'][36],
        );
      }
      final run = LoreSpecProcedures.map16(
        20,
        10,
        const ScriptContext(sourceEtc: {37: 2}),
        LoreScriptEngine(),
      )!;
      expect(
        run
            .acknowledgeScene()
            .continueAfterBattle()
            .outcome
            .questChanges
            .single
            .set,
        phase(2054)['partyRecord']['etc'][36],
      );
    },
  );
  for (final cfg in [
    (1749, 1752, 1794, 1798, 1812, 3, 1776),
    (1834, 1837, 1879, 1885, 1895, 2, 1861),
  ]) {
    test(
      'native WIVERN ${cfg.$6} enemies, corpse finishing and escape preserve records/RNG',
      () {
        final s = phase(cfg.$1);
        final random = LoreRandom(s['seed']);
        final b = LoreBattle(
          party: [
            for (final r in s['records'])
              PartyMember.fromJson(Map<String, dynamic>.from(r)),
          ],
          enemy: [for (var i = 0; i < cfg.$6; i++) Monster.create(43)],
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

        void commands(int n) {
          final s = phase(n);
          for (var i = 1; i <= 6; i++) {
            b.battle[i] = [0, ...List<int>.from(s['commands'][i - 1])];
          }
        }

        b.enemyPhase();
        check(cfg.$2);
        // These are actual native commands before dead-target retargeting.
        // The later closed phase can already contain target count + 1.
        commands(cfg.$7);
        for (var i = 1; i <= 6; i++) {
          if (b.exist(i)) b.executePerson(i);
        }
        check(cfg.$3);
        expect([
          for (var i = 1; i <= 6; i++) b.battle[i].skip(1).toList(),
        ], phase(cfg.$3)['commands']);
        expect(b.enemy.last.isDead, true);
        b.enemyPhase();
        check(cfg.$4);
        commands(cfg.$5);
        var escaped = false;
        for (var i = 1; i <= 6; i++) {
          if (b.exist(i) && b.executePerson(i)) {
            escaped = true;
            break;
          }
        }
        expect(escaped, true);
        check(cfg.$5);
      },
    );
  }
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

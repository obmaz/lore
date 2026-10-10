import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_battle.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/party_member.dart';

class _Rolls implements Random {
  _Rolls(this.values);
  final List<int> values;
  final List<int> bounds = [];
  @override
  int nextInt(int max) {
    bounds.add(max);
    final v = values[bounds.length - 1];
    expect(v, lessThan(max));
    return v;
  }

  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
}

void main() {
  final f = jsonDecode(
    File('test/fixtures/dos_enemy_magic_arithmetic.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  for (final r in f['thresholds'] as List) {
    test(
      'native self threshold mode${r['mode']} ${r['endurance']}x${r['level']}',
      () {
        int calculate() =>
            LoreBattle.enemyHealThreshold(r['endurance'], r['level']);
        if (r['fault'] != null) {
          expect(calculate, throwsStateError);
          final me = PartyMember.createPreset(1);
          final before = me.toJson();
          final foe = Monster.create(1)
            ..endurance = r['endurance']
            ..level = r['level']
            ..castLevel = r['mode']
            ..hp = 100;
          final rng = _Rolls([]);
          final out = <String>[];
          final battle = LoreBattle(
            party: [me],
            enemy: [foe],
            random: rng,
            print: (_, s) => out.add(s),
          );
          expect(battle.castAttack, throwsStateError);
          expect(rng.bounds, isEmpty);
          expect(out, isEmpty);
          expect(foe.hp, 100);
          expect(me.toJson(), before);
        } else {
          expect(calculate(), r['threshold']);
        }
      },
    );
  }
  for (final r in f['heals'] as List) {
    test(
      'native healing amount ${r['kind']} ${r['level']}x${r['mentality']}',
      () {
        int calculate() => LoreBattle.enemyHealAmount(
          r['level'],
          r['mentality'],
          r['divisor'],
        );
        if (r['fault'] != null) {
          expect(calculate, throwsStateError);
        } else {
          expect(calculate(), r['amount']);
        }
      },
    );
  }
  for (final mode in [4, 5, 6]) {
    test('self healing source branch mode$mode', () {
      final foe = Monster(
        eNumber: 1,
        name: 'Healer',
        strength: 1,
        mentality: 20,
        endurance: 20,
        resistance: 0,
        agility: 0,
        accArms: 0,
        accMagic: 0,
        ac: 0,
        special: 0,
        castLevel: mode,
        specialCastLevel: 0,
        level: 20,
        hp: 0,
      );
      final me = PartyMember.createPreset(1);
      final before = me.toJson();
      final rng = _Rolls([0]);
      final out = <String>[];
      final battle = LoreBattle(
        party: [me],
        enemy: [foe],
        random: rng,
        print: (_, s) => out.add(s),
      );
      battle.castAttack();
      expect(foe.hp, 100);
      expect(rng.bounds, [mode == 4 ? 2 : 3]);
      expect(out.length, 1);
      expect(foe.isDead, false);
      expect(foe.isUnconscious, false);
      expect(me.toJson(), before);
    });
  }
  for (final r in f['groups'] as List) {
    test('native group healing mode${r['mode']} layout${r['index']}', () {
      final enemies = <Monster>[];
      for (final e in r['enemies'] as List) {
        enemies.add(
          Monster(
            eNumber: 1,
            name: 'Healer',
            strength: 1,
            mentality: 20,
            endurance: e['endurance'],
            resistance: 0,
            agility: 0,
            accArms: 0,
            accMagic: 0,
            ac: 0,
            special: 0,
            castLevel: r['mode'],
            specialCastLevel: 0,
            level: e['level'],
            hp: e['hp'],
          ),
        );
      }
      final actor = enemies.first;
      final mode = r['mode'];
      final eligible = r['healEligible'] == true;
      final values = <int>[];
      final bounds = <int>[];
      if (actor.hp < (r['selfThreshold'] as int)) {
        values.add(1);
        bounds.add(3);
      }
      if (mode == 5) {
        values.add(0);
        bounds.add(1);
      }
      if (eligible) {
        values.add(mode == 5 ? 0 : 1);
        bounds.add(mode == 5 ? 2 : 3);
      } else {
        if (mode == 6) {
          values.add(0);
          bounds.add(1);
        }
        values.add(0);
        bounds.add(20);
      }
      final me = PartyMember.createPreset(1)..ac = 0;
      final before = me.toJson();
      final rng = _Rolls(values);
      final out = <String>[];
      final battle = LoreBattle(
        party: [me],
        enemy: enemies,
        random: rng,
        print: (_, s) => out.add(s),
      );
      battle.castAttack();
      expect(enemies.map((e) => e.hp).toList(), r['afterHp']);
      expect(rng.bounds, bounds);
      expect(me.toJson(), before);
      expect(out.length, eligible ? enemies.length : 2);
      for (final e in enemies) {
        expect(e.isDead, false);
        expect(e.isUnconscious, false);
        expect(e.isPoisoned, false);
      }
    });
  }
}

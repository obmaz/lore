import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_battle.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/party_member.dart';

class _Rolls implements Random {
  _Rolls(this.row);
  final Map<String, dynamic> row;
  final List<int> bounds = [];
  @override
  int nextInt(int max) {
    bounds.add(max);
    if (max == 50) return 49;
    if (max == 10) {
      return bounds.where((b) => b == 10).length == 1
          ? row['attackRoll']
          : row['defenceRoll'];
    }
    return 0;
  }

  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
}

void main() {
  final fixture = jsonDecode(
    File('test/fixtures/dos_weapon_arithmetic.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  for (final r in fixture['cases'] as List) {
    test('native WeaponAttack ${r['strength']}x${r['level']} '
        'roll${r['attackRoll']} ${r['scenario']}', () {
      final me = PartyMember.createPreset(1)
        ..hp = r['hp']
        ..dead = r['dead']
        ..unconscious = r['unconscious']
        ..ac = r['ac']
        ..battleLevel = r['playerLevel']
        ..resistance = 0;
      final before = me.toJson();
      final foe = Monster(
        eNumber: 1,
        name: 'Soldier',
        strength: r['strength'],
        mentality: 0,
        endurance: 20,
        resistance: 0,
        agility: 0,
        accArms: 20,
        accMagic: 0,
        ac: 0,
        special: 0,
        castLevel: 0,
        specialCastLevel: 0,
        level: r['level'],
        hp: 30000,
      );
      final rng = _Rolls(Map<String, dynamic>.from(r));
      final out = <String>[];
      final battle = LoreBattle(
        party: [me],
        enemy: [foe],
        random: rng,
        print: (_, s) => out.add(s),
      );
      battle.weaponAttack();
      expect(me.hp, r['afterHp']);
      expect(me.dead, r['afterDead']);
      expect(me.unconscious, r['afterUnconscious']);
      final expected = Map<String, dynamic>.from(before)
        ..['hp'] = r['afterHp']
        ..['dead'] = r['afterDead']
        ..['unconscious'] = r['afterUnconscious'];
      expect(me.toJson(), expected);
      expect(
        rng.bounds,
        r['active'] == true ? [20, 1, 10, 50, 10] : [20, 1, 6, 10],
      );
      expect(out.length, 2);
      expect(foe.hp, 30000);
      expect(foe.isDead, false);
      expect(foe.isUnconscious, false);
    });
  }
}

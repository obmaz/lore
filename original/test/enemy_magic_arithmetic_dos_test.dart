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

Map<String, dynamic> _snapshot(Monster e) => {
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
  'isDead': e.isDead,
  'isUnconscious': e.isUnconscious,
};

void main() {
  final f = jsonDecode(
    File('test/fixtures/dos_enemy_magic_arithmetic.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  for (final r in f['magic'] as List) {
    test(
      'native enemy magic ${r['scenario']} power${r['power']} variance${r['variance']}',
      () {
        final me = PartyMember.createPreset(1)
          ..name = 'Hero'
          ..hp = r['hp']
          ..dead = r['dead']
          ..unconscious = r['unconscious']
          ..ac = r['ac']
          ..battleLevel = r['level']
          ..resistance = 0;
        final before = me.toJson();
        final foe = Monster.create(1)..accMagic = 20;
        final active = r['active'] == true;
        final rng = _Rolls(
          active
              ? [0, 49, r['variance'], r['defenceRoll']]
              : [0, r['variance']],
        );
        final out = <String>[];
        final battle = LoreBattle(
          party: [me],
          enemy: [foe],
          random: rng,
          print: (_, s) => out.add(s),
        );
        battle.castAttackSub(r['power'], 1);
        final expected = Map<String, dynamic>.from(before)
          ..['hp'] = r['afterHp']
          ..['dead'] = r['afterDead']
          ..['unconscious'] = r['afterUnconscious'];
        expect(me.toJson(), expected);
        final varianceBound = (r['power'] as int) ~/ 2;
        expect(
          rng.bounds,
          active
              ? [20, 50, varianceBound > 0 ? varianceBound : 1, 10]
              : [20, varianceBound > 0 ? varianceBound : 1],
        );
        expect(out.length, 1);
        expect(foe.isDead, false);
        expect(foe.isUnconscious, false);
      },
    );
  }
  for (final r in f['cures'] as List) {
    test(
      'native enemy cure hp${r['hp']} plus${r['plus']} '
      '${r['endurance']}x${r['level']} dead${r['dead']} unconscious${r['unconscious']}',
      () {
        final foe = Monster.create(1)
          ..hp = r['hp']
          ..endurance = r['endurance']
          ..level = r['level']
          ..isDead = r['dead']
          ..isUnconscious = r['unconscious'];
        final before = _snapshot(foe);
        final out = <String>[];
        final rng = _Rolls([]);
        final battle = LoreBattle(
          party: [PartyMember.createPreset(1)],
          enemy: [foe],
          random: rng,
          print: (_, s) => out.add(s),
        );
        battle.enemyCure(1, r['plus']);
        final expected = Map<String, dynamic>.from(before)
          ..['hp'] = r['afterHp']
          ..['isDead'] = r['afterDead']
          ..['isUnconscious'] = r['afterUnconscious'];
        expect(_snapshot(foe), expected);
        expect(rng.bounds, isEmpty);
        expect(out.length, 1);
      },
    );
  }
}

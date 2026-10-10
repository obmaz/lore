import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_battle.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/party_member.dart';

class _Rolls implements Random {
  _Rolls(this.defenceRoll);
  final int defenceRoll;
  final List<int> bounds = [];
  @override
  int nextInt(int max) {
    bounds.add(max);
    if (max == 10) return defenceRoll;
    if (max == 100) return 99;
    return 0;
  }

  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
}

/// Both procedures are exercised against independent shipped x86-16 results.
/// Magic cost/base inputs stay small; their overflow behavior is not asserted.
void main() {
  final fixture = jsonDecode(
    File('test/fixtures/dos_defence_arithmetic.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  for (final row in fixture['cases'] as List) {
    final magic = row['routine'] == 'CastOne';
    test('${row['routine']} native defence ${row['ac']}x${row['level']} '
        'roll ${row['random10']}', () {
      final me = PartyMember.createPreset(1)
        ..strength = 20
        ..weaPower = 75
        ..battleLevel = 20
        ..magicLevel = 200
        ..accArms = 20
        ..accMagic = 20
        ..sp = 1000;
      final foe = Monster.create(1)
        ..hp = 30000
        ..ac = row['ac']
        ..level = row['level']
        ..resistance = 0;
      final rng = _Rolls(row['random10']);
      final out = <String>[];
      final sounds = <String>[];
      final battle = LoreBattle(
        party: [me],
        enemy: [foe],
        random: rng,
        print: (_, text) => out.add(text),
        sound: sounds.add,
      );
      battle.battle[1] = [0, magic ? 2 : 1, 1, 1];
      if (magic) {
        battle.castOne();
      } else {
        battle.attackOne();
      }
      final net = (magic ? 400 : 1500) - (row['defence'] as int);
      final damage = net > 0 ? net : 0;
      expect(foe.hp, 30000 - damage);
      expect(foe.isUnconscious, false);
      expect(foe.isDead, false);
      expect(me.sp, magic ? 900 : 1000);
      expect(me.experience, 0);
      expect(out.length, 2);
      expect(sounds, damage > 0 ? ['hit'] : isEmpty);
      expect(rng.bounds, magic ? [20, 100, 10] : [20, 50, 100, 10]);
    });
  }
}

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_battle.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/party_member.dart';

class _Rolls implements Random {
  _Rolls(this.variance);
  final int variance;
  final List<int> bounds = [];
  @override
  int nextInt(int max) {
    bounds.add(max);
    return switch (bounds.length) {
      1 => 0,
      2 => variance,
      3 => 99,
      _ => 0,
    };
  }

  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
}

/// LOREBATT.PAS AttackOne arithmetic, independently executed original EXE bytes.
/// Defence is zero to isolate arithmetic; this is not a complete DOS battle.
void main() {
  final f = jsonDecode(
    File('test/fixtures/dos_attack_arithmetic.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  for (final row in f['cases'] as List) {
    final id = '${row['strength']}x${row['weaponPower']}x${row['level']}';
    final variations = row['variation'] as List? ?? [null];
    for (final variant in variations) {
      test(
        'native AttackOne $id variance ${variant?['random50'] ?? 'fault'}',
        () {
          final me = PartyMember.createPreset(1)
            ..strength = row['strength']
            ..weaPower = row['weaponPower']
            ..battleLevel = row['level']
            ..accArms = 20;
          final foe = Monster.create(1)
            ..hp = 30000
            ..ac = 0
            ..resistance = 0;
          final rng = _Rolls(variant?['random50'] ?? 0);
          final out = <String>[];
          final b = LoreBattle(
            party: [me],
            enemy: [foe],
            random: rng,
            print: (_, s) => out.add(s),
          );
          b.battle[1] = [0, 1, 1, 1];
          if (row['fault'] != null) {
            expect(b.attackOne, throwsStateError);
            expect(rng.bounds, [20]);
            expect(foe.hp, 30000);
            expect(foe.isUnconscious, false);
            expect(out.length, 1); // ReturnMessage precedes native arithmetic.
          } else {
            b.attackOne();
            expect(30000 - foe.hp, variant['damage']);
            expect(rng.bounds, [20, 50, 100, 10]);
            expect(foe.isUnconscious, false);
            expect(me.experience, 0);
          }
        },
      );
    }
  }
}

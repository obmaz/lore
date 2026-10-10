import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_battle.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/party_member.dart';

class _Miss implements Random {
  final List<int> bounds = [];
  @override
  int nextInt(int max) {
    bounds.add(max);
    return 0;
  }

  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
}

void main() {
  final fixture = jsonDecode(
    File('test/fixtures/dos_spell_arithmetic.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  for (final row in fixture['cases'] as List) {
    if (row['sp'] != 30000) continue;
    test('native damage level${row['level']} spell${row['spell']}', () {
      expect(LoreBattle.castDamage(row['level'], row['spell']), row['damage']);
      if (row['reachableCommand'] != true) return;
      final me = PartyMember.createPreset(1)
        ..magicLevel = row['level']
        ..sp = row['sp']
        ..accMagic = 20;
      final foe = Monster.create(1)
        ..hp = 30000
        ..ac = 0
        ..resistance = 0;
      final rng = _Miss();
      final out = <String>[];
      final battle = LoreBattle(
        party: [me],
        enemy: [foe],
        random: rng,
        print: (_, s) => out.add(s),
      );
      battle.battle[1] = [0, 2, row['spell'], 1];
      battle.castOne();
      expect(foe.hp, 30000 - (row['damage'] as int));
      expect(me.sp, row['afterSp']);
      expect(rng.bounds, [20, 100, 10]);
      expect(foe.isUnconscious, false);
      expect(foe.isDead, false);
      expect(me.experience, 0);
      expect(out.length, 2);
    });
  }
  for (final row in fixture['cases'] as List) {
    test(
      'native cost level${row['level']} spell${row['spell']} sp${row['sp']}',
      () {
        expect(LoreBattle.castCost(row['level'], row['spell']), row['cost']);
        // Invalid spell IDs are instruction boundaries only. Do not claim a
        // ReturnMessage or a complete original gameplay replay for those IDs.
        if (row['reachableCommand'] != true) return;
        final me = PartyMember.createPreset(1)
          ..magicLevel = row['level']
          ..sp = row['sp']
          ..accMagic = 0;
        final foe = Monster.create(1)..hp = 30000;
        final rng = _Miss();
        final out = <String>[];
        final battle = LoreBattle(
          party: [me],
          enemy: [foe],
          random: rng,
          print: (_, s) => out.add(s),
        );
        battle.battle[1] = [0, 2, row['spell'], 1];
        battle.castOne();
        expect(me.sp, row['afterSp']);
        expect(foe.hp, 30000);
        expect(foe.isDead, false);
        expect(foe.isUnconscious, false);
        expect(rng.bounds, row['canCast'] == true ? [20] : isEmpty);
        expect(out.length, 2);
      },
    );
  }
}

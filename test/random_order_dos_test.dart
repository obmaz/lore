import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_battle.dart';
import 'package:lore/logic/lore_lava_logic.dart';
import 'package:lore/logic/lore_random.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/party_member.dart';

class _DispatchBattle extends LoreBattle {
  _DispatchBattle(Monster foe, LoreRandom rng)
    : super(
        party: [PartyMember.createPreset(1)],
        enemy: [foe],
        random: rng,
        print: (_, _) {},
      );
  bool? weapon;
  @override
  void weaponAttack() => weapon = true;
  @override
  void castAttack() => weapon = false;
}

/// LOREMAIN.PAS enter_lava:83 and LOREBATT.PAS EnemyAttack:968.
/// Source expressions alone do not specify the compiler's operand evaluation
/// order; the fixture executes the unmodified EXE and its real Random routine.
void main() {
  final f = jsonDecode(
    File('test/fixtures/dos_random_order.json').readAsStringSync(),
  );
  for (final row in f['lava'] as List) {
    test('native lava seed ${row['seed']} luck ${row['luck']}', () {
      final rng = LoreRandom(row['seed']);
      final party = [
        for (final luck in row['luck']) PartyMember.blank()..luck = luck,
      ];
      expect(LoreLavaLogic.rollDamages(party, rng), row['damages']);
      expect(rng.seed, row['afterSeed']);
    });
  }
  for (final row in f['dispatch'] as List) {
    test(
      'native EnemyAttack seed ${row['seed']} accuracy ${row['arms']}/${row['magic']} strength ${row['strength']}',
      () {
        final rng = LoreRandom(row['seed']);
        final foe = Monster(
          eNumber: 1,
          name: 'Native dispatch',
          strength: row['strength'],
          mentality: 1,
          endurance: 1,
          resistance: 0,
          agility: 1,
          accArms: row['arms'],
          accMagic: row['magic'],
          ac: 0,
          special: 0,
          castLevel: 0,
          specialCastLevel: 0,
          level: 1,
        );
        final battle = _DispatchBattle(foe, rng)..person = 1;
        battle.enemyAttack();
        expect(battle.weapon, row['weapon']);
        expect(rng.seed, row['afterSeed']);
      },
    );
  }
}

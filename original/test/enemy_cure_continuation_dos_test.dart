import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_battle.dart';
import 'package:lore/logic/lore_random.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/party_member.dart';

class _Rng extends LoreRandom {
  _Rng(super.seed);
  final bounds = <int>[];
  @override
  int nextInt(int max) {
    bounds.add(max);
    return super.nextInt(max);
  }
}

class _CureBattle extends LoreBattle {
  _CureBattle(List<PartyMember> party, List<Monster> enemies, _Rng rng)
    : super(party: party, enemy: enemies, random: rng, print: (_, _) {});
  final cures = <List<int>>[];
  @override
  void enemyCure(int num, int plus) {
    cures.add([num, plus]);
    super.enemyCure(num, plus);
  }

  @override
  void castAttackOne(int num) => fail('Cure continuation must not attack');
  @override
  void castAttackAll() => fail('Cure continuation must not attack');
  @override
  void displayCondition() =>
      fail('Cure continuation must not enter armor effect');
}

/// LOREBATT.PAS:758,772,797. Native complete cure loops and return with actual
/// enemycure state branches; Print spans bypassed, rendered UI remains separate.
void main() {
  final fixture = jsonDecode(
    File('test/fixtures/dos_enemy_cure_continuation.json').readAsStringSync(),
  );
  test('native cure iteration/store/return: 112 status continuations', () {
    final rows = fixture['cases'] as List;
    expect(rows.length, 112);
    for (final row in rows) {
      final mask = row['mask'] as int;
      final party = [
        for (var slot = 0; slot < 6; slot++)
          PartyMember.zero()
            ..name = mask & (1 << slot) != 0 || row['blank'] == false ? 'X' : ''
            ..hp = mask & (1 << slot) != 0 ? fixture['partyHp'][slot] : 0
            ..unconscious = mask & (1 << slot) != 0 ? 0 : 1
            ..ac = row['ac'][slot],
      ];
      final enemies = <Monster>[
        for (final e in row['before'])
          Monster(
            eNumber: 1,
            name: 'Native cure',
            hp: e['hp'],
            endurance: e['endurance'],
            level: e['level'],
            mentality: e['mentality'],
            strength: 1,
            resistance: 0,
            agility: 0,
            accArms: 0,
            accMagic: 0,
            ac: 0,
            special: 0,
            castLevel: row['mode'],
            specialCastLevel: 0,
            isDead: e['dead'],
            isUnconscious: e['unconscious'],
          ),
      ];
      final beforeParty = party.map((p) => p.toJson()).toList();
      final rng = _Rng(row['seed']);
      final battle = _CureBattle(party, enemies, rng)..castAttack();
      final reason =
          'mode=${row['mode']} effect=${row['effect']} '
          'status=${row['status']} seed=${row['seed']}';
      expect(battle.cures, row['cures'], reason: reason);
      expect(
        [
          for (final e in enemies)
            {'hp': e.hp, 'dead': e.isDead, 'unconscious': e.isUnconscious},
        ],
        row['after'],
        reason: reason,
      );
      expect(rng.bounds, [
        for (final b in row['bounds']) b == 0 ? 1 : b,
      ], reason: reason);
      expect(rng.seed, row['afterSeed'], reason: reason);
      expect(
        party.map((p) => p.toJson()).toList(),
        beforeParty,
        reason: reason,
      );
      expect(
        enemies.map((e) => e.isPoisoned),
        everyElement(isFalse),
        reason: reason,
      );
    }
  });
}

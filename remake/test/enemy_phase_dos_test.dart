import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_battle.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/party_member.dart';

class _PhaseBattle extends LoreBattle {
  _PhaseBattle(List<Monster> enemies)
    : super(
        party: [PartyMember.createPreset(1)],
        enemy: enemies,
        random: Random(1),
        print: (_, _) {},
      );
  final attacks = <int>[];
  bool appendEnemy = false;
  @override
  void enemyAttack() {
    attacks.add(person);
    if (appendEnemy) {
      enemy.add(Monster.create(1));
    }
  }

  @override
  void displayCondition() {}
}

// LOREBATT.PAS BattleMode 1160..1169: signed DEC and cached FOR bound.
void main() {
  test(
    'all signed HP words, poison/status priorities and enemy counts match DOS',
    () {
      final data = jsonDecode(
        File('test/fixtures/dos_enemy_phase.json').readAsStringSync(),
      );
      expect(data['cases'].length, 66048);
      for (final r in data['cases']) {
        final enemies = [
          for (var i = 0; i < r['count']; i++)
            Monster.create(1)
              ..hp = r['hp']
              ..isPoisoned = (r['flags'] & 1) != 0
              ..isUnconscious = (r['flags'] & 2) != 0
              ..isDead = (r['flags'] & 4) != 0,
        ];
        final battle = _PhaseBattle(enemies);
        battle.enemyPhase();
        expect(battle.attacks, r['attacks']);
        expect([
          for (final e in enemies)
            [
              e.hp,
              e.isPoisoned ? 1 : 0,
              e.isUnconscious ? 1 : 0,
              e.isDead ? 1 : 0,
            ],
        ], r['records']);
      }
    },
  );
  test('summoned enemies do not act until the next phase', () {
    final battle = _PhaseBattle([Monster.create(1), Monster.create(1)])
      ..appendEnemy = true;
    expect(battle.enemyPhaseSteps().toList(), [1, 2]);
    expect(battle.attacks, [1, 2]);
    expect(battle.enemy.length, 4);
    battle.appendEnemy = false;
    battle.attacks.clear();
    expect(battle.enemyPhaseSteps().toList(), [1, 2, 3, 4]);
  });
}

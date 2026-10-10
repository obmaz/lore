import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_random.dart';
import 'package:lore/logic/lore_battle.dart';
import 'package:lore/logic/lore_encounter_logic.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/game/lore_map_manager.dart';

/// LOREMAIN.PAS:113-141 and LOREBATT.PAS:111-169,515-524,1005-1188,1191-1257.
/// Actual native MENACE encounter, manual attacks and successful member flee.
void main() {
  final f = jsonDecode(
    File('test/fixtures/dos_menace_center.json').readAsStringSync(),
  );
  test(
    'native MENACE movement rolls three original enemies with the same RNG',
    () {
      final random = LoreRandom(f['initial']['seed']);
      for (final (i, step) in (f['movement'] as List).indexed) {
        expect(random.seed, step['seedBefore']);
        final encounter = LoreEncounterLogic.shouldEncounter(
          14,
          TileCategory.walkable,
          random,
          frequency: 5,
        );
        expect(encounter, i == f['movement'].length - 1);
        if (encounter) {
          expect(LoreEncounterLogic.rollMonsters(14, random, maxEnemies: 3), [
            10,
            12,
            10,
          ]);
        }
        expect(random.seed, step['seedAfter']);
      }
    },
  );
  test('native failed evasion, attack round and member flee preserve full records and RNG', () {
    final party = [
      for (final r in f['encounter']['records'])
        PartyMember.fromJson(Map<String, dynamic>.from(r)),
    ];
    final enemies = [
      for (final r in f['encounter']['enemyRecords'])
        Monster.create(r['eNumber']),
    ];
    final random = LoreRandom(f['encounter']['seed']);
    final battle = LoreBattle(
      party: party,
      enemy: enemies,
      random: random,
      print: (_, _) {},
    );
    expect(LoreEncounterLogic.decide(EncounterChoice.flee, party, enemies), (
      escaped: false,
      enemyFirst: true,
    ));
    void check(dynamic state) {
      expect(random.seed, state['seed']);
      expect(party.map((p) => p.toJson()).toList(), state['records']);
      expect(enemies.map(_enemyRecord).toList(), state['enemyRecords']);
    }

    battle.enemyPhase();
    check(f['enemyFirst']);
    for (var i = 1; i <= 6; i++) {
      battle.battle[i].setRange(
        1,
        4,
        List<int>.from(f['round']['commands'][i - 1]),
      );
    }
    for (var i = 1; i <= 6; i++) {
      if (battle.exist(i)) expect(battle.executePerson(i), false);
    }
    check(f['round']['partyPhase']);
    battle.enemyPhase();
    check(f['round']['enemyPhase']);
    for (var i = 1; i <= 6; i++) {
      battle.battle[i].setRange(
        1,
        4,
        List<int>.from(f['runAway']['commands'][i - 1]),
      );
    }
    var escaped = false;
    for (var i = 1; i <= 6; i++) {
      if (battle.exist(i) && battle.executePerson(i)) {
        escaped = true;
        break;
      }
    }
    expect(escaped, true);
    check(f['runAway']['wait']);
    expect(random.seed, f['runAway']['afterKey']['seed']);
  });
}

Map<String, dynamic> _enemyRecord(Monster e) => {
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

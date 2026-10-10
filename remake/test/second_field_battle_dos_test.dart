import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_random.dart';
import 'package:lore/logic/lore_battle.dart';
import 'package:lore/logic/lore_encounter_logic.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/logic/town_logic.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/models/monster.dart';

void main() {
  test('second actual DOS battle automatic and manual rounds preserve records and RNG', () {
    final f = jsonDecode(
      File('test/fixtures/dos_second_field_battle.json').readAsStringSync(),
    );
    final party = [
      for (final r in f['initial']['records'])
        PartyMember.fromJson(Map<String, dynamic>.from(r)),
    ];
    final enemies = [
      for (final r in f['initial']['enemyRecords'])
        Monster.create(r['eNumber']),
    ];
    final random = LoreRandom(f['initial']['seed']);
    final b = LoreBattle(
      party: party,
      enemy: enemies,
      random: random,
      print: (_, _) {},
    );
    for (final round in f['rounds']) {
      if (round['commands'] == null) {
        for (var i = 1; i <= 6; i++) {
          if (b.exist(i)) b.autoSelect(i);
        }
      } else {
        for (var i = 1; i <= 6; i++) {
          b.battle[i].setRange(1, 4, List<int>.from(round['commands'][i - 1]));
        }
      }
      for (var i = 1; i <= 6; i++) {
        if (b.exist(i)) b.executePerson(i);
      }
      expect(random.seed, round['partyPhase']['seed']);
      expect(
        party.map((p) => p.toJson()).toList(),
        round['partyPhase']['records'],
      );
      expect(
        enemies.map(_enemyRecord).toList(),
        round['partyPhase']['enemyRecords'],
      );
      if (round['enemyPhase'] != null) {
        b.enemyPhase();
        expect(random.seed, round['enemyPhase']['seed']);
        expect(
          party.map((p) => p.toJson()).toList(),
          round['enemyPhase']['records'],
        );
        expect(
          enemies.map(_enemyRecord).toList(),
          round['enemyPhase']['enemyRecords'],
        );
      }
    }
    expect(b.endBattle(), 0);
    expect(
      f['initial']['partyRecord']['gold'] + b.plusGold(),
      f['victory']['partyRecord']['gold'],
    );
    expect(party.map((p) => p.toJson()).toList(), f['victory']['records']);
    for (var i = 1; i <= 6; i++) {
      if (b.exist(i)) {
        expect(
          b.battle[i].skip(1).toList(),
          f['rounds'].last['completedCommands'][i - 1],
        );
      }
    }
  });
  test(
    'four actual post-battle rests preserve recovery, food and field RNG',
    () {
      final f = jsonDecode(
        File('test/fixtures/dos_second_field_battle.json').readAsStringSync(),
      );
      final party = [
        for (final r in f['victory']['records'])
          PartyMember.fromJson(Map<String, dynamic>.from(r)),
      ];
      var food = f['victory']['partyRecord']['food'] as int;
      var torch = f['victory']['partyRecord']['etc'][0] as int;
      final random = LoreRandom(f['victory']['seed']);
      for (final rest in f['rests']) {
        final result = TownLogic.rest(party, food, torchSteps: torch);
        food = result.food;
        torch = result.torchSteps;
        expect(party.map((p) => p.toJson()).toList(), rest['wait']['records']);
        expect(food, rest['wait']['partyRecord']['food']);
        expect(torch, rest['wait']['partyRecord']['etc'][0]);
        expect(random.seed, rest['wait']['seed']);
        expect(
          LoreEncounterLogic.shouldEncounter(1, TileCategory.walkable, random),
          false,
        );
        expect(random.seed, rest['afterKey']['seed']);
      }
    },
  );
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

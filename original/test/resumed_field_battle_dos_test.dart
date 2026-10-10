import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_random.dart';
import 'package:lore/logic/lore_battle.dart';
import 'package:lore/logic/lore_encounter_logic.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/game/lore_map_manager.dart';

void main() {
  test('actual departure reload route preserves native encounter RNG', () {
    final f = jsonDecode(
      File('test/fixtures/dos_resumed_field_battle.json').readAsStringSync(),
    );
    final random = LoreRandom(f['initial']['seed']);
    for (final (i, s) in (f['movement'] as List).indexed) {
      expect(random.seed, s['seedBefore']);
      final hit = LoreEncounterLogic.shouldEncounter(
        1,
        TileCategory.walkable,
        random,
      );
      expect(hit, i == f['movement'].length - 1);
      if (hit) {
        expect(LoreEncounterLogic.rollMonsters(1, random), [1, 9, 6, 9]);
      }
      expect(random.seed, s['seedAfter']);
    }
  });

  test('resumed actual DOS battle enemy magic, failed member flee and manual rounds preserve records and RNG', () {
    final f = jsonDecode(
      File('test/fixtures/dos_resumed_field_battle.json').readAsStringSync(),
    );
    final party = [
      for (final r in f['encounter']['records'])
        PartyMember.fromJson(Map<String, dynamic>.from(r)),
    ];
    final enemies = [
      for (final r in f['encounter']['enemyRecords'])
        Monster.create(r['eNumber']),
    ];
    final random = LoreRandom(f['encounter']['seed']);
    final b = LoreBattle(
      party: party,
      enemy: enemies,
      random: random,
      print: (_, _) {},
    );
    expect(LoreEncounterLogic.enemyActsFirst(party, enemies), true);
    b.enemyPhase();
    expect(random.seed, f['enemyFirst']['seed']);
    expect(party.map((p) => p.toJson()).toList(), f['enemyFirst']['records']);
    expect(enemies.map(_enemyRecord).toList(), f['enemyFirst']['enemyRecords']);
    for (final round in f['rounds']) {
      for (var i = 1; i <= 6; i++) {
        b.battle[i][1] = 0;
      }
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
        if (b.exist(i)) expect(b.executePerson(i), false);
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
      expect([
        for (var i = 1; i <= 6; i++) b.battle[i].skip(1).toList(),
      ], round['completedCommands']);
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
      f['encounter']['partyRecord']['gold'] + b.plusGold(),
      f['victory']['partyRecord']['gold'],
    );
    expect(random.seed, f['victory']['seed']);
    expect(party.map((p) => p.toJson()).toList(), f['victory']['records']);
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

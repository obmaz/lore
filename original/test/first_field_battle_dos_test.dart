import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_random.dart';
import 'package:lore/logic/lore_encounter_logic.dart';
import 'package:lore/logic/lore_battle.dart';
import 'package:lore/logic/lore_battle_progress.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/models/monster.dart';

void main() {
  final f = jsonDecode(
    File('test/fixtures/dos_first_field_battle.json').readAsStringSync(),
  );
  test('actual cold-created DOS field route reproduces the encounter RNG', () {
    final random = LoreRandom(f['initial']['seed']);
    for (final (i, step) in (f['movement'] as List).indexed) {
      expect(random.seed, step['seedBefore']);
      final encounter = LoreEncounterLogic.shouldEncounter(
        1,
        TileCategory.walkable,
        random,
      );
      expect(encounter, i == (f['movement'] as List).length - 1);
      if (encounter) {
        expect(LoreEncounterLogic.rollMonsters(1, random), [4]);
      }
      expect(random.seed, step['seedAfter']);
    }
  });
  test('actual DOS automatic first party phase preserves records and RNG', () {
    final state = f['encounter'];
    final party = [
      for (final r in state['records'])
        PartyMember.fromJson(Map<String, dynamic>.from(r)),
    ];
    final enemies = [Monster.create(4)];
    expect(LoreEncounterLogic.enemyActsFirst(party, enemies), false);
    expect(enemies.map(_enemyRecord).toList(), state['enemyRecords']);
    final random = LoreRandom(state['seed']);
    final b = LoreBattle(
      party: party,
      enemy: enemies,
      random: random,
      print: (_, _) {},
    );
    for (var i = 1; i <= 6; i++) {
      if (b.exist(i)) b.autoSelect(i);
    }
    for (var i = 1; i <= 6; i++) {
      if (b.exist(i)) b.executePerson(i);
    }

    expect(random.seed, f['checkpoints']['partyPhaseWait']['seed']);
    expect(
      enemies.map(_enemyRecord).toList(),
      f['checkpoints']['partyPhaseWait']['enemyRecords'],
    );
    expect(
      party.map((p) => p.toJson()).toList(),
      f['checkpoints']['partyPhaseWait']['records'],
    );
    b.enemyPhase();
    expect(b.endBattle(), 0);
    expect(random.seed, f['checkpoints']['enemyPhaseReadKey']['seed']);
    expect(
      enemies.map(_enemyRecord).toList(),
      f['checkpoints']['enemyPhaseReadKey']['enemyRecords'],
    );
    final before = f['checkpoints']['partyCommandWait']['partyRecord'];
    final result = LoreBattleProgress.resolve(
      LoreBattleProgressState(
        gold: before['gold'],
        lastBattleResult: before['etc'][5],
        flags: const {},
      ),
      end: LoreBattleEnd.victory,
      enemyNames: enemies.map((e) => e.name),
      goldEarned: b.plusGold(),
    );
    expect(
      result.state.gold,
      f['checkpoints']['victory']['partyRecord']['gold'],
    );
    expect(
      result.state.lastBattleResult,
      f['checkpoints']['victory']['partyRecord']['etc'][5],
    );
    expect(
      party.map((p) => p.toJson()).toList(),
      f['checkpoints']['victory']['records'],
    );
  });
  test('actual DOS failed pre-battle escape reproduces the enemy phase', () {
    final second = f['secondEncounter'];
    final state = second['encounter'];
    final party = [
      for (final r in state['records'])
        PartyMember.fromJson(Map<String, dynamic>.from(r)),
    ];
    final enemies = [
      for (final r in state['enemyRecords']) Monster.create(r['eNumber']),
    ];
    expect(LoreEncounterLogic.decide(EncounterChoice.flee, party, enemies), (
      escaped: false,
      enemyFirst: true,
    ));
    expect(enemies.map(_enemyRecord).toList(), state['enemyRecords']);
    final random = LoreRandom(state['seed']);
    final b = LoreBattle(
      party: party,
      enemy: enemies,
      random: random,
      print: (_, _) {},
    );
    b.enemyPhase();
    expect(random.seed, second['enemyPhaseReadKey']['seed']);
    expect(
      enemies.map(_enemyRecord).toList(),
      second['enemyPhaseReadKey']['enemyRecords'],
    );
    expect(
      party.map((p) => p.toJson()).toList(),
      second['enemyPhaseReadKey']['records'],
    );
  });

  test(
    'second real field route preserves RNG and the three-enemy selection',
    () {
      final second = f['secondEncounter'];
      final random = LoreRandom(second['initial']['seed']);
      for (final (i, step) in (second['movement'] as List).indexed) {
        expect(random.seed, step['seedBefore']);
        final encounter = LoreEncounterLogic.shouldEncounter(
          1,
          TileCategory.walkable,
          random,
        );
        expect(encounter, i == (second['movement'] as List).length - 1);
        if (encounter) {
          expect(LoreEncounterLogic.rollMonsters(1, random), [2, 3, 10]);
        }
        expect(random.seed, step['seedAfter']);
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

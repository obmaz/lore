import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_battle.dart';
import 'package:lore/logic/lore_random.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/party_member.dart';

/// Independent shipped BattleMode k=8 instructions, not a Dart-derived oracle.
void main() {
  final fixture = jsonDecode(
    File('test/fixtures/dos_auto_select.json').readAsStringSync(),
  );
  for (final cls in PlayerClass.values) {
    test(
      'native auto command ${cls.name}, all byte magic levels and six slots',
      () {
        for (final row in fixture['classes'] as List) {
          if (row['classId'] != cls.id) continue;
          final party = [
            for (var i = 0; i < 6; i++) PartyMember.createPreset(1),
          ];
          final who = row['person'] as int;
          party[who - 1]
            ..playerClass = cls
            ..magicLevel = row['level']
            ..weapon = row['weapon'];
          final enemies = [for (var i = 0; i < 4; i++) Monster.create(1)];
          enemies[1].isDead = true;
          enemies[2].isUnconscious = true;
          final rng = LoreRandom(0xdeadbeef);
          final battle = LoreBattle(
            party: party,
            enemy: enemies,
            random: rng,
            print: (_, _) {},
          );
          battle.autoSelect(who);
          expect(
            battle.battle[who].sublist(1),
            row['command'],
            reason: '${cls.name} level ${row['level']} slot $who',
          );
          expect(rng.seed, 0xdeadbeef);
        }
      },
    );
  }
  for (var count = 1; count <= 7; count++) {
    test('native esper target with $count enemies, all availability masks', () {
      for (final row in fixture['targets'] as List) {
        final states = row['states'] as List;
        if (states.length != count) continue;
        final party = [for (var i = 0; i < 6; i++) PartyMember.createPreset(1)];
        party[5].playerClass = PlayerClass.esper;
        final enemies = [
          for (final state in states)
            Monster.create(1)
              ..isDead = state == 'dead'
              ..isUnconscious = state == 'unconscious',
        ];
        final rng = LoreRandom(1);
        final battle = LoreBattle(
          party: party,
          enemy: enemies,
          random: rng,
          print: (_, _) {},
        );
        battle.autoSelect(6);
        expect(battle.battle[6].sublist(1), row['command'], reason: '$states');
        expect(rng.seed, 1);
      }
    });
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_battle.dart';
import 'package:lore/logic/lore_random.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/party_member.dart';

/// LORESUB.PAS:789 ReturnMessage: all branches, source labels and name slots.
/// Out-of-array memory reads are explicit faults, not reconstructed memory.
void main() {
  final data = jsonDecode(
    File('test/fixtures/dos_return_message.json').readAsStringSync(),
  );
  test('10010 original strings match the actual battle message owner', () {
    expect(data['cases'].length, 10010);
    final battles = <LoreBattle>[];
    for (final profile in data['profiles']) {
      final players = [
        for (final row in profile['players'])
          PartyMember.createPreset(1)
            ..name = row['name']
            ..weapon = row['weapon'],
      ];
      final enemies = [
        for (final name in profile['enemies'])
          Monster.create(1).withOverrides(name: name),
      ];
      final battle = LoreBattle(
        party: players.take(6).toList(),
        enemy: enemies,
        random: LoreRandom(1993),
        print: (_, _) {},
      );
      battle.slots.seventhPlayer = players[6];
      battles.add(battle);
    }
    for (final row in data['cases']) {
      final battle = battles[row['profile']];
      final actor = battle.p(row['who']);
      if (row['weapon'] != null) actor.weapon = row['weapon'];
      final before = actor.toJson();
      expect(
        battle.returnMessage(row['who'], row['how'], row['what'], row['whom']),
        row['text'],
        reason: 'who=${row['who']} how=${row['how']} what=${row['what']}',
      );
      expect(actor.toJson(), before);
      // Source arguments are integer stores, not unbounded Dart parameters.
      expect(
        battle.returnMessage(
          row['who'] + 65536,
          row['how'] + 65536,
          row['what'] + 65536,
          row['whom'] + 65536,
        ),
        row['text'],
      );
    }
    for (final battle in battles) {
      expect((battle.random as LoreRandom).seed, 1993);
      expect(
        battle.enemy.map((e) => e.hp),
        List.filled(7, Monster.create(1).hp),
      );
    }
  });

  test(
    'source pointer reads outside declared arrays become explicit range faults',
    () {
      final battle = LoreBattle(
        party: [PartyMember.createPreset(1)],
        enemy: [Monster.create(1)],
        random: LoreRandom(1993),
        print: (_, _) {},
      );
      for (final row in data['outOfArrayReads']) {
        // Native synthetic surrounding memory becomes visible in the message.
        expect(row['text'], contains('OtherMemory'));
        expect(
          () => battle.returnMessage(
            row['who'],
            row['how'],
            row['what'],
            row['whom'],
          ),
          throwsRangeError,
        );
      }
      for (final who in [-32768, -1, 0, 8, 32767]) {
        expect(() => battle.returnMessage(who, 0, 0, 0), throwsRangeError);
      }
      for (var how = 1; how <= 6; how++) {
        for (final whom in [-32768, -1, 0, 8, 32767]) {
          expect(() => battle.returnMessage(1, how, 1, whom), throwsRangeError);
        }
      }
      expect(battle.returnMessage(1, 7, 0, 0), '일행은 도망을 시도했다');
      expect(battle.returnMessage(1, 0, 0, 0), contains('잠시 주저했다'));
      expect(() => battle.returnMessage(1, 2, 0, 1), throwsStateError);
    },
  );
}

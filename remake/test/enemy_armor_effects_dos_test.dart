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
  final luckRolls = <int>[];
  @override
  int nextInt(int max) {
    bounds.add(max);
    final result = super.nextInt(max);
    if (max == 21) luckRolls.add(result);
    return result;
  }
}

class _ArmorBattle extends LoreBattle {
  _ArmorBattle(List<PartyMember> party, _Rng rng, List<(int, String)> messages)
    : super(
        party: party,
        enemy: [
          Monster.create(1)
            ..castLevel = 6
            ..hp = 400
            ..endurance = 20
            ..level = 20,
        ],
        random: rng,
        print: (color, text) => messages.add((color, text)),
      );
  int displays = 0;
  @override
  void displayCondition() => displays++;
  @override
  void castAttackOne(int num) => fail('Expected armor effect, not an attack');
  @override
  void castAttackAll() => fail('Expected armor effect, not a group attack');
  @override
  void enemyCure(int num, int plus) =>
      fail('Expected armor effect, not healing');
}

/// LOREBATT.PAS:781-789 native armor slot loop/RNG/luck/AC stores.
/// Native string/Print spans are bypassed; BGI and display_condition are separate.
void main() {
  final fixture = jsonDecode(
    File('test/fixtures/dos_enemy_armor_effects.json').readAsStringSync(),
  );
  test('native mode6 armor effects: 1064 slot/luck boundary scenarios', () {
    final rows = fixture['cases'] as List;
    expect(rows.length, 1064);
    for (final row in rows) {
      final mask = row['mask'] as int;
      final party = [
        for (var slot = 0; slot < 6; slot++)
          PartyMember.zero()
            ..name = mask & (1 << slot) != 0 || row['blank'] == false
                ? 'Slot${slot + 1}'
                : ''
            ..hp = mask & (1 << slot) != 0 ? fixture['partyHp'][slot] : 0
            ..unconscious = mask & (1 << slot) != 0 ? 0 : 1
            ..luck = row['luck'][slot]
            ..ac = row['ac'][slot],
      ];
      final before = party.map((p) => p.toJson()).toList();
      final messages = <(int, String)>[];
      final rng = _Rng(row['seed']);
      final battle = _ArmorBattle(party, rng, messages)..castAttack();
      final reason =
          'mask=$mask blank=${row['blank']} ac=${row['ac']} '
          'pattern=${row['pattern']}';
      expect(party.map((p) => p.ac).toList(), row['afterAc'], reason: reason);
      expect(rng.bounds, row['bounds'], reason: reason);
      expect(rng.luckRolls, [
        for (final roll in row['rolls']) roll[1],
      ], reason: reason);
      expect(rng.seed, row['afterSeed'], reason: reason);
      expect(messages.map((m) => m.$1).toList(), [
        for (final m in row['messages']) m[1],
      ], reason: reason);
      for (var i = 0; i < messages.length; i++) {
        final slot = row['messages'][i][0];
        if (messages[i].$1 != 7) {
          expect(messages[i].$2, contains('Slot$slot'), reason: reason);
        }
      }
      expect(battle.displays, 1, reason: reason);
      expect(battle.enemy.single.hp, 400, reason: reason);
      for (var slot = 0; slot < 6; slot++) {
        final after = party[slot].toJson();
        after['ac'] = before[slot]['ac'];
        expect(after, before[slot], reason: reason);
      }
    }
  });
}

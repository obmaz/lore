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
  final rolls = <List<Object>>[];
  @override
  int nextInt(int max) {
    bounds.add(max);
    final value = super.nextInt(max);
    if ([40, 50, 60].contains(max)) rolls.add(['agility', value]);
    if (max == 20) rolls.add(['luck', value]);
    return value;
  }
}

class _Battle extends LoreBattle {
  _Battle(
    List<PartyMember> party,
    Monster foe,
    _Rng rng,
    void Function(int, String) emit,
  ) : super(party: party, enemy: [foe], random: rng, print: emit);
  int lastSlot = 0;
  @override
  PartyMember p(int i) {
    lastSlot = i;
    return super.p(i);
  }
}

Map<String, Object> _state(PartyMember p) => {
  'name': p.name.isNotEmpty,
  'hp': p.hp,
  'poison': p.poison,
  'unconscious': p.unconscious,
  'dead': p.dead,
};

/// LOREBATT.PAS:817-893. Native SpecialAttack selection, actual RNG, status/HP
/// stores and exits. String/Print spans bypassed; rendered DOS UI is not covered.
void main() {
  final fixture = jsonDecode(
    File('test/fixtures/dos_enemy_special_attack.json').readAsStringSync(),
  );
  for (final mode in [1, 2, 3, 0]) {
    test(
      'native SpecialAttack ${mode == 0 ? 'unsupported byte modes' : 'mode $mode'}',
      () {
        final rows = (fixture['cases'] as List).where(
          (r) => mode == 0 ? r['pattern'] == -1 : r['mode'] == mode,
        );
        expect(rows.length, mode == 0 ? 253 : 6144);
        for (final row in rows) {
          final party = <PartyMember>[
            for (var slot = 0; slot < 6; slot++)
              PartyMember.zero()
                ..name = row['before'][slot]['name'] ? 'Slot${slot + 1}' : ''
                ..hp = row['before'][slot]['hp']
                ..poison = row['before'][slot]['poison']
                ..unconscious = row['before'][slot]['unconscious']
                ..dead = row['before'][slot]['dead']
                ..luck = row['luck'],
          ];
          final before = party.map((p) => p.toJson()).toList();
          final foe = Monster.create(1)
            ..special = row['mode']
            ..agility = row['agility'];
          final enemyHp = foe.hp;
          final rng = _Rng(row['seed']);
          final events = <List<int>>[];
          late _Battle battle;
          battle = _Battle(party, foe, rng, (color, _) {
            events.add([battle.lastSlot, color]);
          });
          battle.specialAttack();
          final reason =
              'mode=${row['mode']} mask=${row['mask']} blank=${row['blank']} '
              'seed=${row['seed']} pattern=${row['pattern']}';
          expect(party.map(_state).toList(), row['after'], reason: reason);
          expect(rng.bounds, [
            for (final b in row['bounds']) b == 0 ? 1 : b,
          ], reason: reason);
          expect(rng.rolls, row['rolls'], reason: reason);
          expect(rng.seed, row['afterSeed'], reason: reason);
          expect(events, row['events'], reason: reason);
          expect(foe.hp, enemyHp, reason: reason);
          for (var slot = 0; slot < 6; slot++) {
            final after = party[slot].toJson();
            for (final field in ['hp', 'poison', 'unconscious', 'dead']) {
              after[field] = before[slot][field];
            }
            expect(after, before[slot], reason: reason);
          }
        }
      },
    );
  }
}

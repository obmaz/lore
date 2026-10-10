import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_battle.dart';
import 'package:lore/logic/lore_random.dart';
import 'package:lore/logic/lore_transient_slots.dart';
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

class _Battle extends LoreBattle {
  _Battle(
    List<PartyMember> party,
    List<Monster> enemy,
    _Rng rng,
    LoreTransientSlots slots,
    this.colors,
  ) : super(
        party: party,
        enemy: enemy,
        random: rng,
        slots: slots,
        print: (color, _) => colors.add(color),
      );
  final List<Object> colors;
  @override
  void displayCondition() {
    colors.add('condition');
    super.displayCondition();
  }
}

String _name(List<int> bytes, int offset) =>
    latin1.decode(bytes.sublist(offset + 1, offset + 1 + bytes[offset]));
ByteData _words(List<int> bytes) =>
    ByteData.sublistView(Uint8List.fromList(bytes));
PartyMember _player(List<int> r) {
  final d = _words(r);
  return PartyMember.zero()
    ..name = _name(r, 0)
    ..sex = Gender.values[r[18]]
    ..playerClass = PlayerClass.fromId(r[19])
    ..strength = r[20]
    ..mentality = r[21]
    ..concentration = r[22]
    ..endurance = r[23]
    ..resistance = r[24]
    ..agility = r[25]
    ..accArms = r[26]
    ..accMagic = r[27]
    ..accEsp = r[28]
    ..luck = r[29]
    ..poison = r[30]
    ..unconscious = d.getInt16(31, Endian.little)
    ..dead = d.getInt16(33, Endian.little)
    ..hp = d.getInt16(35, Endian.little)
    ..sp = d.getInt16(37, Endian.little)
    ..esp = d.getInt16(39, Endian.little)
    ..battleLevel = r[41]
    ..magicLevel = r[42]
    ..espLevel = r[43]
    ..ac = r[44]
    ..experience = d.getInt32(45, Endian.little)
    ..weapon = r[49]
    ..shield = r[50]
    ..armor = r[51]
    ..weaPower = r[52]
    ..shiPower = r[53]
    ..armPower = r[54];
}

Monster _enemy(List<int> r) => Monster(
  eNumber: r[0],
  name: _name(r, 1),
  strength: r[18],
  mentality: r[19],
  endurance: r[20],
  resistance: r[21],
  agility: r[22],
  accArms: r[23],
  accMagic: r[24],
  ac: r[25],
  special: r[26],
  castLevel: r[27],
  specialCastLevel: r[28],
  level: r[29],
  hp: _words(r).getInt16(30, Endian.little),
  isPoisoned: r[32] != 0,
  isUnconscious: r[33] != 0,
  isDead: r[34] != 0,
);
List<Object> _enemyState(Monster e) => [
  e.eNumber,
  e.name,
  e.strength,
  e.mentality,
  e.endurance,
  e.resistance,
  e.agility,
  e.accArms,
  e.accMagic,
  e.ac,
  e.special,
  e.castLevel,
  e.specialCastLevel,
  e.level,
  e.hp,
  e.isPoisoned,
  e.isUnconscious,
  e.isDead,
];

/// LOREBATT.PAS SpecialCastAttack native RNG, active/inactive slot stores,
/// joinenemy/turn_mind and condition continuation; glyphs/graphics excluded.
/// LORESUB.PAS turn_mind, joinenemy and ReturnCondition are executed natively.
void main() {
  final fixture = jsonDecode(
    File('test/fixtures/dos_enemy_special_cast.json').readAsStringSync(),
  );
  final partyRecords = [
    for (final r in fixture['partyRecords']) List<int>.from(r),
  ];
  final enemyRecords = [
    for (final r in fixture['enemyRecords']) List<int>.from(r),
  ];
  for (final count in [1, 2, 3, 4, 5, 6, 7]) {
    test('native SpecialCastAttack $count active slots', () {
      final rows = (fixture['cases'] as List).where((r) => r['count'] == count);
      expect(rows, isNotEmpty);
      for (final row in rows) {
        final beforeParty = [
          for (final id in row['beforeParty']) _player(partyRecords[id]),
        ];
        final beforeEnemy = [
          for (final id in row['beforeEnemy']) _enemy(enemyRecords[id]),
        ];
        final slots = LoreTransientSlots()..seventhPlayer = beforeParty[6];
        for (var i = 0; i < 7; i++) {
          slots.enemies[i] = beforeEnemy[i];
        }
        final party = beforeParty.take(6).toList();
        final enemies = beforeEnemy.take(count).toList();
        final rng = _Rng(row['seed']);
        final colors = <Object>[];
        final battle = _Battle(party, enemies, rng, slots, colors)
          ..person = row['caster'];
        battle.specialCastAttack();
        final reason =
            'count=$count caster=${row['caster']} mode=${row['mode']} '
            'mask=${row['mask']} seed=${row['seed']} blank=${row['blankMask']}';
        expect(battle.enemynumber, row['afterCount'], reason: reason);
        expect(
          [
            for (final p in [...party, slots.seventhPlayer]) p.toJson(),
          ],
          [
            for (final id in row['afterParty'])
              _player(partyRecords[id]).toJson(),
          ],
          reason: reason,
        );
        expect(
          [for (var i = 0; i < 7; i++) _enemyState(slots.enemyAt(i))],
          [
            for (final id in row['afterEnemy'])
              _enemyState(_enemy(enemyRecords[id])),
          ],
          reason: reason,
        );
        expect(rng.bounds, row['bounds'], reason: reason);
        expect(rng.seed, row['afterSeed'], reason: reason);
        expect(colors, [for (final e in row['events']) e[0]], reason: reason);
      }
    });
  }
}

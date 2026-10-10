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

Monster _record(List<int> r) => Monster(
  eNumber: r[0],
  name: ascii.decode(r.sublist(2, 2 + r[1])),
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
  hp: ByteData.sublistView(Uint8List.fromList(r)).getInt16(30, Endian.little),
  isPoisoned: r[32] != 0,
  isUnconscious: r[33] != 0,
  isDead: r[34] != 0,
);

List<Object> _values(Monster e) => [
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

/// LOREBATT.PAS:904,905 SpecialCastAttack and LORESUB.PAS JoinEnemy.
/// Undefined template zero is a deliberate RangeError, not DOS adjacent memory.
void main() {
  final fixture = jsonDecode(
    File('test/fixtures/dos_summon_bounds.json').readAsStringSync(),
  );
  test('native append/reuse and RNG precede either defined summon or explicit fault', () {
    for (final row in fixture['cases']) {
      final records = [
        for (final r in row['before']) _record(List<int>.from(r)),
      ];
      final slots = LoreTransientSlots();
      for (var i = 0; i < 7; i++) {
        slots.enemies[i] = records[i];
      }
      final active = records.take(row['count'] as int).toList();
      final rng = _Rng(row['seed']);
      final lines = <String>[];
      final party = [for (var i = 0; i < 6; i++) PartyMember.zero()];
      final beforeParty = jsonEncode([for (final p in party) p.toJson()]);
      final battle = LoreBattle(
        party: party,
        enemy: active,
        slots: slots,
        random: rng,
        print: (_, s) => lines.add(s),
      )..person = 1;
      final template = row['call'][1];
      if (template == 0) {
        expect(battle.specialCastAttack, throwsRangeError);
        expect(lines, isEmpty);
        for (var i = 0; i < 7; i++) {
          expect(
            _values(slots.enemies[i]!),
            _values(_record(List<int>.from(row['beforeRead'][i]))),
          );
        }
        final nativeTarget = _record(
          List<int>.from(row['after'][row['call'][0] - 1]),
        );
        expect(nativeTarget.name, row['marker']);
        expect(nativeTarget.eNumber, 0);
      } else {
        battle.specialCastAttack();
        expect(lines, hasLength(1));
        for (var i = 0; i < 7; i++) {
          expect(
            _values(slots.enemies[i]!),
            _values(_record(List<int>.from(row['after'][i]))),
          );
        }
      }
      expect(battle.enemynumber, row['afterCount']);
      expect(rng.bounds, row['bounds']);
      expect(rng.seed, row['afterSeed']);
      expect(jsonEncode([for (final p in party) p.toJson()]), beforeParty);
    }
  });
  test('changing synthetic adjacent memory changes only the undefined native result', () {
    final rows = fixture['cases'] as List;
    for (final a in rows.where(
      (r) => r['marker'] == 'FAKE' && r['call'][1] == 0,
    )) {
      final b = rows.singleWhere(
        (r) =>
            r['count'] == a['count'] &&
            r['seed'] == a['seed'] &&
            r['marker'] == 'OTHER',
      );
      expect(a['beforeRead'], b['beforeRead']);
      expect(a['afterSeed'], b['afterSeed']);
      expect(a['after'], isNot(equals(b['after'])));
    }
  });
}

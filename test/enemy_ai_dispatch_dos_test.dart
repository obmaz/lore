import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_battle.dart';
import 'package:lore/logic/lore_random.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/party_member.dart';

class _EffectBoundary implements Exception {}

class _BoundaryRandom extends LoreRandom {
  _BoundaryRandom(super.seed, this.expectedBounds, this.expectedEffect);
  final List<int> expectedBounds;
  final String expectedEffect;
  final bounds = <int>[];
  bool armor = false;

  @override
  int nextInt(int max) {
    if (bounds.length == expectedBounds.length && expectedEffect == 'armor') {
      expect(max, 21, reason: 'Stop at first armor luck roll, before effects');
      armor = true;
      throw _EffectBoundary();
    }
    expect(bounds.length, lessThan(expectedBounds.length));
    expect(max, expectedBounds[bounds.length]);
    bounds.add(max);
    return super.nextInt(max);
  }
}

class _Dispatch extends LoreBattle {
  _Dispatch(List<PartyMember> party, List<Monster> enemies, _BoundaryRandom rng)
    : super(party: party, enemy: enemies, random: rng, print: (_, _) {});
  String? effect;
  int? target;
  int? amount;
  @override
  void castAttackOne(int num) {
    effect = 'one';
    target = num;
    throw _EffectBoundary();
  }

  @override
  void castAttackAll() {
    effect = 'all';
    throw _EffectBoundary();
  }

  @override
  void enemyCure(int num, int plus) {
    effect = 'cure';
    target = num;
    amount = plus;
    throw _EffectBoundary();
  }
}

/// LOREBATT.PAS:724-815. Independent original EXE dispatch through the first
/// effect boundary, not full spell/armor/cure effects or presentation parity.
void main() {
  final fixture = jsonDecode(
    File('test/fixtures/dos_enemy_ai_dispatch.json').readAsStringSync(),
  );
  for (final mode in [4, 5, 6]) {
    test('native seeded CastAttack mode $mode decision scenarios', () {
      final rows = (fixture['cases'] as List).where((r) => r['mode'] == mode);
      expect(rows.length, mode == 6 ? 3784 : 3584);
      for (final row in rows) {
        final mask = row['mask'] as int;
        final party = [
          for (var slot = 0; slot < 6; slot++)
            PartyMember.zero()
              ..name = mask & (1 << slot) != 0 || row['blank'] == false
                  ? 'X'
                  : ''
              ..hp = mask & (1 << slot) != 0 ? fixture['partyHp'][slot] : 0
              ..unconscious = mask & (1 << slot) != 0 ? 0 : 1
              ..ac = fixture['armors'][row['armor']][slot],
        ];
        final enemies = <Monster>[
          for (final e in fixture['layouts'][row['layout']])
            Monster(
              eNumber: 1,
              name: 'Native AI',
              hp: e[0],
              endurance: e[1],
              level: e[2],
              mentality: e[3],
              strength: 1,
              resistance: 0,
              agility: 0,
              accArms: 0,
              accMagic: 0,
              ac: 0,
              special: 0,
              castLevel: mode,
              specialCastLevel: 0,
            ),
        ];
        final beforeParty = party.map((p) => p.toJson()).toList();
        final beforeEnemy = enemies.map((e) => e.hp).toList();
        final rng = _BoundaryRandom(row['seed'], [
          for (final b in row['bounds']) b == 0 ? 1 : b as int,
        ], row['effect']);
        final battle = _Dispatch(party, enemies, rng);
        final reason =
            'mode=$mode mask=$mask blank=${row['blank']} '
            'layout=${row['layout']} seed=${row['seed']}';
        if (row['effect'] == 'armor-division-zero') {
          expect(battle.castAttack, throwsStateError, reason: reason);
        } else {
          expect(
            battle.castAttack,
            throwsA(isA<_EffectBoundary>()),
            reason: reason,
          );
          expect(
            rng.armor ? 'armor' : battle.effect,
            (row['effect'] as String).endsWith('cure') ? 'cure' : row['effect'],
            reason: reason,
          );
          expect(battle.target, row['target'], reason: reason);
          expect(battle.amount, row['amount'], reason: reason);
        }
        expect(rng.bounds.length, rng.expectedBounds.length, reason: reason);
        expect(rng.seed, row['afterSeed'], reason: reason);
        expect(
          party.map((p) => p.toJson()).toList(),
          beforeParty,
          reason: reason,
        );
        expect(enemies.map((e) => e.hp).toList(), beforeEnemy, reason: reason);
      }
    });
  }
  test(
    'native CastAttack selector: every unsupported byte mode is a no-op',
    () {
      final rows = (fixture['cases'] as List).where(
        (r) => r['effect'] == 'none',
      );
      expect(rows.map((r) => r['mode']).toList(), [
        0,
        ...List.generate(249, (i) => i + 7),
      ]);
      for (final row in rows) {
        final party = [for (var i = 0; i < 6; i++) PartyMember.createPreset(1)];
        final before = party.map((p) => p.toJson()).toList();
        final enemy = Monster.create(1)..castLevel = row['mode'];
        final beforeHp = enemy.hp;
        final rng = _BoundaryRandom(row['seed'], [], 'none');
        final battle = _Dispatch(party, [enemy], rng)..castAttack();
        expect(battle.effect, isNull, reason: 'mode=${row['mode']}');
        expect(rng.bounds, isEmpty);
        expect(rng.seed, row['afterSeed']);
        expect(enemy.hp, beforeHp);
        expect(party.map((p) => p.toJson()).toList(), before);
      }
    },
  );
}

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_battle.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/party_member.dart';

/// LOREBATT.PAS:685-722, CastAttack modes 1..3. These are source-derived
/// dispatch expectations, not an independent DOS capture of a complete attack.
class _Draws implements Random {
  _Draws(this.calls);
  final List<(int, int)> calls;
  int used = 0;

  @override
  int nextInt(int max) {
    expect(used, lessThan(calls.length), reason: 'Unexpected RNG consumption');
    final (bound, value) = calls[used++];
    expect(max, bound);
    expect(value, inInclusiveRange(0, max - 1));
    return value;
  }

  @override
  bool nextBool() => throw UnsupportedError('Pascal integer Random only');
  @override
  double nextDouble() => throw UnsupportedError('Pascal integer Random only');
}

class _Dispatch extends LoreBattle {
  _Dispatch(List<PartyMember> party, int mode, _Draws random)
    : super(
        party: party,
        enemy: [Monster.create(1)..castLevel = mode],
        random: random,
        print: (_, _) => fail('Dispatch must not emit attack text'),
      );

  final targets = <int>[];
  int all = 0;

  @override
  void castAttackOne(int num) => targets.add(num);
  @override
  void castAttackAll() => all++;
}

List<PartyMember> _party(int mask) => [
  for (var slot = 0; slot < 6; slot++)
    PartyMember.createPreset(1)
      ..name = 'Slot${slot + 1}'
      ..hp = mask & (1 << slot) != 0 ? 20 : 0
      ..unconscious = mask & (1 << slot) != 0 ? 0 : 1,
];

void main() {
  for (final hasSixth in [false, true]) {
    test(
      'mode 1 retries once across every first/second slot (sixth=$hasSixth)',
      () {
        final bound = hasSixth ? 6 : 5;
        for (var first = 1; first <= bound; first++) {
          for (var second = 1; second <= bound; second++) {
            for (final firstAlive in [false, true]) {
              final party = _party(firstAlive ? 1 << (first - 1) : 0);
              if (!hasSixth) party[5].name = '';
              final before = party.map((p) => p.toJson()).toList();
              final random = _Draws([
                (bound, first - 1),
                if (!firstAlive) (bound, second - 1),
              ]);
              final battle = _Dispatch(party, 1, random)..castAttack();
              expect(battle.targets, [firstAlive ? first : second]);
              expect(battle.all, 0);
              expect(random.used, random.calls.length);
              expect(party.map((p) => p.toJson()).toList(), before);
            }
          }
        }
      },
    );
  }

  test('mode 2 selects every living rank for all 64 availability masks', () {
    for (var mask = 0; mask < 64; mask++) {
      final live = [
        for (var slot = 1; slot <= 6; slot++)
          if (mask & (1 << (slot - 1)) != 0) slot,
      ];
      for (var rank = 0; rank < max(1, live.length); rank++) {
        final random = _Draws([
          (max(1, live.length), rank),
          if (live.isEmpty) (6, 5),
        ]);
        final battle = _Dispatch(_party(mask), 2, random)..castAttack();
        expect(battle.targets, [live.isEmpty ? 6 : live[rank]]);
        expect(battle.all, 0);
        expect(random.used, random.calls.length);
      }
    }
  });

  test(
    'mode 3 splits at roll 2 and keeps source selection draws for all masks',
    () {
      for (var mask = 0; mask < 64; mask++) {
        final live = [
          for (var slot = 1; slot <= 6; slot++)
            if (mask & (1 << (slot - 1)) != 0) slot,
        ];
        final bound = max(1, live.length);
        for (var choice = 0; choice < bound; choice++) {
          for (var rank = 0; rank < (choice < 2 ? bound : 1); rank++) {
            final random = _Draws([
              (bound, choice),
              if (choice < 2) (bound, rank),
              if (choice < 2 && live.isEmpty) (6, 5),
            ]);
            final battle = _Dispatch(_party(mask), 3, random)..castAttack();
            expect(
              battle.targets,
              choice < 2 ? [live.isEmpty ? 6 : live[rank]] : isEmpty,
            );
            expect(battle.all, choice < 2 ? 0 : 1);
            expect(random.used, random.calls.length);
          }
        }
      }
    },
  );

  for (final mode in [2, 3]) {
    test(
      'mode $mode no living members uses zero, six, then five-slot fallback',
      () {
        final random = _Draws([if (mode == 3) (1, 0), (1, 0), (6, 5), (5, 2)]);
        final battle = _Dispatch(
          [for (var i = 0; i < 7; i++) PartyMember.zero()],
          mode,
          random,
        )..castAttack();
        expect(battle.targets, [3]);
        expect(battle.all, 0);
        expect(random.used, random.calls.length);
      },
    );
  }

  test('alive but blank, poisoned, unconscious, dead and seventh slots are distinct', () {
    final party = [for (var i = 0; i < 7; i++) PartyMember.createPreset(1)];
    party[0].name = '';
    party[1].unconscious = 1;
    party[2].dead = 1;
    party[3].hp = 0;
    party[4].poison = 1; // Poison alone does not make exist false.
    final random = _Draws([(2, 0)]);
    final battle = _Dispatch(party, 2, random)..castAttack();
    expect(battle.targets, [5]);
    expect(random.used, 1);
  });

  for (final mode in [2, 3]) {
    test('mode $mode fallback retries an empty name only once', () {
      for (var first = 1; first <= 6; first++) {
        for (var second = 1; second <= 5; second++) {
          for (final emptyFirst in [false, true]) {
            final party = _party(0);
            if (emptyFirst) party[first - 1].name = '';
            final random = _Draws([
              if (mode == 3) (1, 0),
              (1, 0),
              (6, first - 1),
              if (emptyFirst) (5, second - 1),
            ]);
            final battle = _Dispatch(party, mode, random)..castAttack();
            expect(battle.targets, [emptyFirst ? second : first]);
            expect(battle.all, 0);
            expect(random.used, random.calls.length);
          }
        }
      }
    });
  }
}

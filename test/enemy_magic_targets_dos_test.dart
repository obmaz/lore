import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_battle.dart';
import 'package:lore/logic/lore_random.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/party_member.dart';

class _RecordedRandom extends LoreRandom {
  _RecordedRandom(super.seed);
  final bounds = <int>[];
  @override
  int nextInt(int max) {
    bounds.add(max);
    return super.nextInt(max);
  }
}

class _TargetBattle extends LoreBattle {
  _TargetBattle(List<PartyMember> party, int mode, _RecordedRandom rng)
    : super(
        party: party,
        enemy: [Monster.create(1)..castLevel = mode],
        random: rng,
        print: (_, _) => fail('Target dispatch must not enter spell effects'),
      );
  int? target;
  bool all = false;
  @override
  void castAttackOne(int num) {
    expect(target, isNull);
    target = num;
  }

  @override
  void castAttackAll() {
    expect(all, isFalse);
    all = true;
  }
}

/// Actual original EXE target dispatch, Exist and RNG; stops before spell effects.
void main() {
  final fixture = jsonDecode(
    File('test/fixtures/dos_enemy_magic_targets.json').readAsStringSync(),
  );
  for (final mode in [1, 2, 3]) {
    test('native CastAttack mode $mode: 512 party/seed combinations', () {
      final rows = (fixture['cases'] as List).where((r) => r['mode'] == mode);
      expect(rows.length, 512);
      for (final row in rows) {
        final mask = row['mask'] as int;
        final party = [
          for (var slot = 0; slot < 6; slot++)
            PartyMember.zero()
              ..name = mask & (1 << slot) != 0 || row['blank'] == false
                  ? 'X'
                  : ''
              ..hp = mask & (1 << slot) != 0 ? 20 : 0
              ..unconscious = mask & (1 << slot) != 0 ? 0 : 1,
        ];
        final before = party.map((p) => p.toJson()).toList();
        final rng = _RecordedRandom(row['seed']);
        final battle = _TargetBattle(party, mode, rng)..castAttack();
        final reason =
            'mode=$mode mask=$mask blank=${row['blank']} seed=${row['seed']}';
        expect(battle.target, row['target'], reason: reason);
        expect(battle.all, row['all'], reason: reason);
        // LoreBattle normalizes Random(0) to nextInt(1), consuming the same seed.
        expect(rng.bounds, [
          for (final bound in row['bounds']) bound == 0 ? 1 : bound,
        ], reason: reason);
        expect(rng.seed, row['afterSeed'], reason: reason);
        expect(party.map((p) => p.toJson()).toList(), before, reason: reason);
      }
    });
  }
}

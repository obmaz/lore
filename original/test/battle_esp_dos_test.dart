import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_battle.dart';
import 'package:lore/logic/lore_random.dart';
import 'package:lore/logic/lore_transient_slots.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/party_member.dart';

import 'support/native_battle_records.dart';

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
    this.calls,
    this.messages,
    bool learned,
  ) : super(
        party: party,
        enemy: enemy,
        random: rng,
        slots: slots,
        espBit: learned,
        print: (color, text) {
          colors.add(color);
          messages.add((color, text));
        },
        onTelepathyJoin: (id) {
          calls.add(['join', id, 6]);
          party[5] = PartyMember.fromMonsterTemplate(
            Monster.create(id),
            previousExperience: party[5].experience,
          );
        },
      );
  final List<Object> colors;
  final List<List<Object>> calls;
  final List<(int, String)> messages;
  @override
  void plusExperience(int who, int foe) {
    calls.add(['xp', who, foe]);
    super.plusExperience(who, foe);
  }

  @override
  void displayCondition() {
    colors.add('condition');
    super.displayCondition();
  }
}

/// LOREBATT.PAS BattleESP and LORESUB.PAS join/ReturnCondition. Native full
/// game-state stores, XP/recruitment, actual RNG and returns; DOS UI excluded.
void main() {
  final fixture = jsonDecode(
    File('test/fixtures/dos_battle_esp.json').readAsStringSync(),
  );
  final partyRecords = [
    for (final r in fixture['partyRecords']) List<int>.from(r),
  ];
  final enemyRecords = [
    for (final r in fixture['enemyRecords']) List<int>.from(r),
  ];
  final cases = fixture['cases'] as List;
  String group(dynamic r) => r['action'] == 3
      ? 'mind'
      : [1, 2, 4].contains(r['action'])
      ? 'blocked'
      : r['level'] <= 10
      ? 'ordinary low level'
      : r['level'] <= 17
      ? 'ordinary middle level'
      : 'ordinary high level';
  for (final family in [
    'mind',
    'blocked',
    'ordinary low level',
    'ordinary middle level',
    'ordinary high level',
  ]) {
    test('native BattleESP $family', () {
      final rows = cases.where((r) => group(r) == family);
      expect(rows, isNotEmpty);
      for (final row in rows) {
        final beforeParty = [
          for (final id in row['beforeParty']) nativePlayer(partyRecords[id]),
        ];
        final beforeEnemy = [
          for (final id in row['beforeEnemy']) nativeMonster(enemyRecords[id]),
        ];
        final slots = LoreTransientSlots()..seventhPlayer = beforeParty[6];
        for (var i = 0; i < 7; i++) {
          slots.enemies[i] = beforeEnemy[i];
        }
        final party = beforeParty.take(6).toList();
        final enemies = beforeEnemy.take(row['count']).toList();
        final rng = _Rng(row['seed']);
        final colors = <Object>[];
        final calls = <List<Object>>[];
        final messages = <(int, String)>[];
        final battle = _Battle(
          party,
          enemies,
          rng,
          slots,
          colors,
          calls,
          messages,
          (row['bits'] & 1) != 0,
        )..person = row['person'];
        battle.battle[row['person']][2] = row['action'];
        battle.battle[row['person']][3] = row['count'];
        battle.battleESP();
        final reason =
            'action=${row['action']} class=${row['cls']} '
            'bits=${row['bits']} level=${row['level']} seed=${row['seed']} '
            'k=${row['k']} status=${row['status']} hp=${row['hpMode']}';
        expect(
          [
            for (final p in [...party, slots.seventhPlayer]) p.toJson(),
          ],
          [
            for (final id in row['afterParty'])
              nativePlayer(partyRecords[id]).toJson(),
          ],
          reason: reason,
        );
        expect(
          [for (var i = 0; i < 7; i++) nativeMonsterState(slots.enemyAt(i))],
          [
            for (final id in row['afterEnemy'])
              nativeMonsterState(nativeMonster(enemyRecords[id])),
          ],
          reason: reason,
        );
        expect(rng.bounds, [
          for (final b in row['bounds']) b == 0 ? 1 : b,
        ], reason: reason);
        expect(rng.seed, row['afterSeed'], reason: reason);
        expect(calls, row['calls'], reason: reason);
        expect(colors, row['colors'], reason: reason);
        if ((row['messageKinds'] as List).isNotEmpty) {
          final templates = fixture['sourceMessages']['templates'];
          final expected = [
            for (final kind in row['messageKinds'])
              for (final text in templates['$kind'])
                (text as String)
                    .replaceAll('{target}', beforeEnemy[row['count'] - 1].name)
                    .replaceAll('{sex}', row['sexData']),
          ];
          expect(
            messages.where((m) => m.$1 == 7).map((m) => m.$2).toList(),
            expected,
            reason: reason,
          );
        }
      }
    });
  }
}

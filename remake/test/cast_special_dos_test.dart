import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_battle.dart';
import 'package:lore/logic/lore_random.dart';
import 'package:lore/logic/lore_transient_slots.dart';

import 'support/native_battle_records.dart';

class _Random extends LoreRandom {
  _Random(super.seed);
  final bounds = <int>[];
  @override
  int nextInt(int max) {
    bounds.add(max);
    return super.nextInt(max);
  }
}

// LOREBATT.PAS CastSpecial: full native stores, messages, RNG and early returns.
void main() {
  final data = jsonDecode(
    File('test/fixtures/dos_cast_special.json').readAsStringSync(),
  );
  final players = [for (final r in data['partyRecords']) List<int>.from(r)];
  final monsters = [for (final r in data['enemyRecords']) List<int>.from(r)];
  for (var action = 0; action <= 6; action++) {
    test('native CastSpecial action $action', () {
      for (final row in (data['cases'] as List).where(
        (r) => action == 0
            ? r['action'] == 0 || r['action'] > 6
            : r['action'] == action,
      )) {
        final party = [
          for (final id in row['beforeParty']) nativePlayer(players[id]),
        ];
        final enemies = [
          for (final id in row['beforeEnemy']) nativeMonster(monsters[id]),
        ];
        final slots = LoreTransientSlots()..seventhPlayer = party[6];
        for (var i = 0; i < 7; i++) {
          slots.enemies[i] = enemies[i];
        }
        final rng = _Random(row['seed']);
        final messages = <List<Object>>[];
        final battle = LoreBattle(
          party: party.take(6).toList(),
          enemy: enemies,
          random: rng,
          slots: slots,
          specialMagicLearned: (row['bits'] & 1) != 0,
          print: (color, text) => messages.add([color, text]),
        )..person = row['person'];
        battle.battle[row['person']][2] = row['action'];
        battle.battle[row['person']][3] = row['target'];
        battle.castSpecial();
        final reason =
            'action=${row['action']} res=${row['resistance']} acc=${row['accuracy']} seed=${row['seed']} ac=${row['ac']}';
        expect(
          [for (final p in party) p.toJson()],
          [
            for (final id in row['afterParty'])
              nativePlayer(players[id]).toJson(),
          ],
          reason: reason,
        );
        expect(
          [for (final e in enemies) nativeMonsterState(e)],
          [
            for (final id in row['afterEnemy'])
              nativeMonsterState(nativeMonster(monsters[id])),
          ],
          reason: reason,
        );
        expect(rng.bounds, row['bounds'], reason: reason);
        expect(rng.seed, row['afterSeed'], reason: reason);
        expect(messages, row['messages'], reason: reason);
      }
    });
  }
}

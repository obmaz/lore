import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_battle.dart';
import 'package:lore/logic/lore_random.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/models/monster.dart';

import 'wivern_battle_dos_test.dart' show enemyRecord;

void main() {
  test(
    'native Frost gate complete enemy-first phase matches all records and RNG',
    () {
      final f = jsonDecode(
        File('test/fixtures/dos_frost_battle_phase.json').readAsStringSync(),
      );
      final continuation = jsonDecode(
        File('test/fixtures/dos_frost_continuation.json').readAsStringSync(),
      );
      expect(continuation['saves']['arrival']['partyRecord']['etc'][43], 1);
      final s = f['initial'];
      final r = LoreRandom(s['seed']);
      final b = LoreBattle(
        party: [
          for (final p in s['records'])
            PartyMember.fromJson(Map<String, dynamic>.from(p)),
        ],
        enemy: [
          for (final e in s['enemyRecords']) Monster.create(e['eNumber']),
        ],
        random: r,
        print: (_, _) {},
      );
      b.enemyPhase();
      expect(r.seed, f['closed']['seed']);
      expect(b.party.map((p) => p.toJson()).toList(), f['closed']['records']);
      expect(b.enemy.map(enemyRecord).toList(), f['closed']['enemyRecords']);
    },
  );
}

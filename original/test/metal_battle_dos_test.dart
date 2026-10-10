import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_battle.dart';
import 'package:lore/logic/lore_random.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/logic/script_party_reducer.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/models/monster.dart';

import 'wivern_battle_dos_test.dart' show enemyRecord;

void main() {
  test('native metal guardian complete enemy-first phase matches all records and RNG', () {
    final f = jsonDecode(
      File('test/fixtures/dos_metal_battle_phase.json').readAsStringSync(),
    );
    final s = f['initial'];
    final r = LoreRandom(s['seed']);
    final b = LoreBattle(
      party: [
        for (final p in s['records'])
          PartyMember.fromJson(Map<String, dynamic>.from(p)),
      ],
      enemy: [for (final id in f['battleEnemyIds']) Monster.create(id)],
      random: r,
      print: (_, _) {},
    );
    b.enemyPhase();
    expect(r.seed, f['closed']['seed']);
    expect(b.party.map((p) => p.toJson()).toList(), f['closed']['records']);
    expect(b.enemy.map(enemyRecord).toList(), f['closed']['enemyRecords']);
  });
  test(
    'native metal victory changes class10 only for all six original records',
    () {
      final f = jsonDecode(
        File('test/fixtures/dos_metal_continuation.json').readAsStringSync(),
      );
      final rows = [
        for (final s in f['segments'])
          for (final b in s['trace'])
            if (b.containsKey('input')) b['input'],
      ];
      final row = rows.singleWhere((r) => r['capture'] == 'lore_20531.png');
      final party = [
        for (final p in row['before']['records'])
          PartyMember.fromJson(Map<String, dynamic>.from(p)),
      ];
      final updated = ScriptPartyReducer.applyProgress(
        party,
        ScriptOutcome(partyClassId: 10),
      );
      expect(updated.map((p) => p.toJson()).toList(), row['after']['records']);
      expect(row['before']['seed'], row['after']['seed']);
    },
  );
}

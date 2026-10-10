import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_battle.dart';
import 'package:lore/logic/lore_ent_procedures.dart';
import 'package:lore/logic/lore_random.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/models/monster.dart';

import 'wivern_battle_dos_test.dart' show enemyRecord;

void main() {
  test('native chamber complete party-first turn and enemy phase match every field and RNG', () {
    final f = jsonDecode(
      File('test/fixtures/dos_chamber_battle_phase.json').readAsStringSync(),
    );
    final s = f['initial'], r = LoreRandom(s['seed']);
    final b = LoreBattle(
      party: [
        for (final p in s['records'])
          PartyMember.fromJson(Map<String, dynamic>.from(p)),
      ],
      enemy: [for (final id in f['battleEnemyIds']) Monster.create(id)],
      random: r,
      print: (_, _) {},
      espBit: true,
    );
    for (var i = 1; i <= 6; i++) {
      b.battle[i] = [0, ...List<int>.from(f['commands'][i - 1])];
    }
    for (var i = 1; i <= 6; i++) {
      b.executePerson(i);
    }
    b.enemyPhase();
    expect(r.seed, f['closed']['seed']);
    expect(b.party.map((p) => p.toJson()).toList(), f['closed']['records']);
    expect(b.enemy.map(enemyRecord).toList(), f['closed']['enemyRecords']);
  });
  test('native chamber victory has actual map26 save and source entrance wall rectangle', () {
    final f = jsonDecode(
      File('test/fixtures/dos_chamber_continuation.json').readAsStringSync(),
    );
    final s = f['saves']['chamberWon'];
    final portal = LoreEntProcedures.entranceAt(25, 25, 27)!;
    expect(portal.targetMapId, s['partyRecord']['mapId']);
    expect(
      [portal.targetX, portal.targetY],
      [s['partyRecord']['x'], s['partyRecord']['y']],
    );
    final hex = s['files']['SAVE1.MAP']['hex'] as String;
    final raw = [
      for (var i = 0; i < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16),
    ];
    final writes = <(int, int, int)>[];
    LoreEntProcedures.afterMapLoadTiles(
      fromMap: 25,
      toMap: 26,
      partyNames: {},
      flags: {},
      questSteps: {},
      setTile: (x, y, v) => writes.add((x, y, v)),
    );
    expect(writes.length, 12);
    for (final (x, y, v) in writes) {
      expect(v, raw[2 + (y - 1) * raw[0] + x - 1]);
    }
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/logic/lore_battle.dart';
import 'package:lore/logic/lore_mirror_enemy.dart';
import 'package:lore/logic/lore_ent_procedures.dart';
import 'package:lore/logic/lore_random.dart';
import 'package:lore/logic/lore_spec_procedures.dart';
import 'package:lore/logic/script_world_reducer.dart';
import 'package:lore/models/party_member.dart';

import 'wivern_battle_dos_test.dart' show enemyRecord;

void main() {
  final f = jsonDecode(
    File('test/fixtures/dos_keep3_continuation.json').readAsStringSync(),
  );
  final inputs = [
    for (final s in f['segments'])
      for (final b in s['trace'])
        if (b.containsKey('input')) b['input'],
  ];
  dynamic row(int n) =>
      inputs.singleWhere((r) => r['capture'] == 'lore_$n.png');
  test(
    'native six mind mirrors and complete enemy-first phase match every field',
    () {
      final s = row(18287)['after'];
      final party = [
        for (final p in s['records'])
          PartyMember.fromJson(Map<String, dynamic>.from(p)),
      ];
      final enemies = createMindMirrorEnemies(party);
      expect(enemies.map(enemyRecord).toList(), s['enemyRecords']);
      final r = LoreRandom(s['seed']);
      final b = LoreBattle(
        party: party,
        enemy: enemies,
        random: r,
        print: (_, _) {},
      );
      b.enemyPhase();
      final after = row(18294)['before'];
      expect(r.seed, after['seed']);
      expect(party.map((p) => p.toJson()).toList(), after['records']);
      expect(enemies.map(enemyRecord).toList(), after['enemyRecords']);
    },
  );
  test(
    'native sign and lever match entire saved map before acknowledgement',
    () {
      List<int> bytes(String tag) => [
        for (
          var i = 0;
          i < (f['saves'][tag]['files']['SAVE1.MAP']['hex'] as String).length;
          i += 2
        )
          int.parse(
            (f['saves'][tag]['files']['SAVE1.MAP']['hex'] as String).substring(
              i,
              i + 2,
            ),
            radix: 16,
          ),
      ];
      final raw = bytes('impostorWon');
      final w = raw[0], h = raw[1];
      final grid = [
        for (var y = 0; y < h; y++) raw.sublist(2 + y * w, 2 + (y + 1) * w),
      ];
      LoreEntProcedures.sign(
        mapId: 23,
        x: 29,
        y: 43,
        messageFor: (_, _, _) => null,
        display: (_) {},
        setTile: (x, y, v) => grid[y - 1][x - 1] = v,
      );
      expect(grid[26][24], 52);
      final run = LoreSpecProcedures.map23(
        25,
        27,
        const ScriptContext(tileAtPlayer: 52),
        LoreScriptEngine(),
      )!;
      final map = ScriptWorldReducer.applyMap(
        ScriptMapState(mapId: 23, x: 25, y: 27, direction: 1, grid: grid),
        run.outcome,
      );
      expect([w, h, ...map.grid.expand((r) => r)], bytes('leverOpen'));
      expect(run.hasPendingScene, isTrue);
    },
  );
  test('native named intro remains Print13 and chant preserves Print15', () {
    var run = LoreSpecProcedures.map23(
      25,
      26,
      const ScriptContext(tileAtPlayer: 52),
      LoreScriptEngine(),
    )!;
    final named = run.pendingScene!.withPartyNames(['Hero']);
    expect(named.lines.first, ' 잘도 여기까지 찾아왔구나 Hero.');
    expect(named.lineColors, {0: 13, 1: 13, 2: 13, 3: 13});
    run = run.acknowledgeScene();
    expect(run.pendingScene!.lineColors, {
      0: 13,
      1: 13,
      2: 13,
      3: 13,
      4: 15,
      5: 15,
    });
  });
}

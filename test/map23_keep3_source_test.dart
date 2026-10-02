import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dungeon_event_manager.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/game/lore_world_manager.dart';
import 'package:lore/logic/lore_battle_progress.dart';
import 'package:lore/logic/lore_ent_procedures.dart';
import 'package:lore/logic/lore_special_event_dispatcher.dart';
import 'package:lore/logic/lore_spec_procedures.dart';
import 'package:lore/logic/lore_tile_protocol.dart';
import 'package:lore/logic/script_battle_session.dart';
import 'package:lore/logic/script_world_reducer.dart';

class NoKeep3Random implements Random {
  @override
  int nextInt(int max) =>
      throw StateError('LORESPEC.PAS:1880-1979 has no random draw');
  @override
  bool nextBool() => throw StateError('Unexpected random Boolean');
  @override
  double nextDouble() => throw StateError('Unexpected random double');
}

/// LORESPEC.PAS `case 23` (KEEP3): the y = 26 impostor Necromancer and the
/// (25,27) lever, replayed against facts extracted from the Pascal source by
/// tool/source_map23_keep3.py and the original KEEP3.MAP.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final source = jsonDecode(
    File('test/fixtures/map23_keep3_parity.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  List<String> strings(Object? raw) => (raw as List).cast<String>();
  List<String> lines(String key) => strings(source[key]);
  final victory = source['victoryWrites'] as Map<String, dynamic>;
  final lever = source['lever'] as Map<String, dynamic>;
  late LoreMapData original;

  setUpAll(() async {
    original = await LoreMapData.loadFromAsset('KEEP3', category: 'keep');
  });

  ScriptRun? startAt(
    int x,
    int y, {
    int? tile = 52,
    LoreScriptEngine? engine,
    Set<String> flags = const {},
  }) => LoreSpecProcedures.map23(
    x,
    y,
    ScriptContext(tileAtPlayer: tile, flags: flags),
    engine ?? LoreScriptEngine(random: NoKeep3Random()),
  );
  ScriptRun start({LoreScriptEngine? engine, Set<String> flags = const {}}) =>
      startAt(25, 26, engine: engine, flags: flags)!;

  ScriptMapState stateAt(int x, int y, List<List<int>> grid) => ScriptMapState(
    mapId: 23,
    x: x,
    y: y,
    direction: 1,
    grid: [for (final row in grid) List<int>.from(row)],
  );

  String sceneKind(ScriptScene scene) {
    final kinds = {
      'intro': lines('introLines'),
      'illusion': lines('illusionLines'),
      'retry': lines('retryLines'),
      'duel': lines('duelLines'),
      'victory': lines('victoryLines'),
      'end': lines('endLines'),
    };
    for (final entry in kinds.entries) {
      if (scene.lines.join('\n') == entry.value.join('\n')) return entry.key;
    }
    throw StateError('Scene is not in the Pascal source: ${scene.lines}');
  }

  String writeToken(ScriptStep op) => op.kind == 'setTile'
      ? 'write:tile:${op.tileX},${op.tileY}=${op.tileValue}'
      : 'write:area:${op.tileX}-${op.tileXMax},${op.tileY}-${op.tileYMax}'
            '=${op.tileValue}';

  /// Plays the run through successive BattleMode results (etc[6]), returning
  /// the observable event tokens and the map after every applied effect.
  ({List<String> events, ScriptMapResult map}) drive(
    List<int> results, {
    LoreScriptEngine? engine,
  }) {
    final initial = stateAt(25, 26, original.grid);
    final events = <String>[];
    final queue = List<int>.of(results);
    var run = start(engine: engine);
    var previous = const ScriptOutcome();
    var mirrorBattles = 0;
    while (true) {
      for (final op in run.outcome.since(previous).tileOperations) {
        events.add(writeToken(op));
      }
      previous = run.outcome;
      if (run.hasPendingScene) {
        events.add('scene:${sceneKind(run.pendingScene!)}');
        run = run.acknowledgeScene();
        continue;
      }
      if (!run.awaitingBattle) break;
      final code = queue.removeAt(0);
      final outcome = run.outcome;
      final mirror = outcome.battleMirrorParty;
      events.add('battle:${mirror ? 'mirror' : 'duel'}:$code');
      if (mirror) {
        expect(outcome.battleMonsters, [
          for (var i = 0; i < source['mirrorCount']; i++)
            source['mirrorEmptySlotMonster'],
        ]);
        expect(outcome.battleEnemyFirst, source['mirrorEnemyFirst']);
        expect(outcome.battleOverrides, isEmpty);
        // The retry keeps the same enemy objects (LORESPEC.PAS:1923-1933).
        expect(outcome.battleReuseExisting, mirrorBattles > 0);
        mirrorBattles++;
      } else {
        expect(outcome.battleMonsters, [source['impostorMonster']]);
        expect(outcome.battleEnemyFirst, source['duelEnemyFirst']);
        expect(outcome.battleOverrides, [
          {
            'index': 1,
            'name': source['impostorName'],
            'eNumber': source['impostorENumber'],
          },
        ]);
        expect(outcome.battleReuseExisting, isFalse);
      }
      final end = code == 0
          ? LoreBattleEnd.victory
          : code == 255
          ? LoreBattleEnd.defeat
          : LoreBattleEnd.runAway;
      final next = ScriptBattleSession.resolve(
        before: const LoreBattleProgressState(
          gold: 100,
          lastBattleResult: 0,
          flags: {},
        ),
        end: end,
        enemies: const [],
        pendingScript: run,
      ).continuation;
      if (next == null) break;
      run = next;
    }
    expect(queue, isEmpty, reason: 'every scripted battle result was used');
    final map = ScriptWorldReducer.applyMap(initial, run.outcome);
    final dx = map.x - initial.x;
    final dy = map.y - initial.y;
    if (dx != 0 || dy != 0) events.add('nudge:$dx,$dy');
    return (events: events, map: map);
  }

  test('source result replay: mirror loop, duel escape/defeat and victory', () {
    for (final raw in source['cases'] as List<dynamic>) {
      final item = raw as Map<String, dynamic>;
      final results = (item['results'] as List).cast<int>();
      expect(drive(results).events, item['events'], reason: '$results');
    }
  });

  test(
    'the same direct procedure runs with or without the JSON script pack',
    () {
      final json = LoreScriptEngine(random: NoKeep3Random())
        ..loadFromJson(File('assets/data/scripts.json').readAsStringSync());
      for (final raw in source['cases'] as List<dynamic>) {
        final item = raw as Map<String, dynamic>;
        final results = (item['results'] as List).cast<int>();
        expect(drive(results, engine: json).events, item['events']);
      }
    },
  );

  test(
    'escape from the duel moves y + 1 and writes nothing; defeat just exits',
    () {
      final escape = drive([0, 7]);
      expect(
        [escape.map.x, escape.map.y],
        [25, 26 + (source['escapeDy'] as int)],
      );
      expect(escape.map.grid, original.grid);
      final defeat = drive([0, 255]);
      expect([defeat.map.x, defeat.map.y], [25, 26]);
      expect(defeat.map.grid, original.grid);
    },
  );

  test(
    'greeting reads player[1] when presented and ends with the source suffix',
    () {
      final intro = start().pendingScene!;
      expect(intro.lines, lines('introLines'));
      expect(intro.appendPartyNameSlot, source['greetingSlot']);
      expect(intro.appendPartyNameLine, 0);
      expect(intro.appendPartyNameSuffix, source['greetingSuffix']);
      final head = lines('introLines').first;
      expect(intro.withPartyNames(['아린', '둘째']).lines.first, '$head아린.');
      expect(intro.withPartyNames(['', '둘째']).lines.first, '$head.');
      expect(intro.withPartyNames(['같은', '같은']).lines.first, '$head같은.');
      expect(
        intro.withPartyNames(['아린']).lines.skip(1),
        lines('introLines').skip(1),
      );
    },
  );

  test('victory writes the source tiles in place; revisits are decided by those tiles', () {
    final result = drive([0, 0]);
    final expected = [for (final row in original.grid) List<int>.from(row)];
    final tile = (victory['tile'] as List).cast<int>();
    expected[tile[1] - 1][tile[0] - 1] = tile[2];
    final area = victory['area'] as Map<String, dynamic>;
    final xs = (area['x'] as List).cast<int>();
    final ys = (area['y'] as List).cast<int>();
    for (var j = ys[0]; j <= ys[1]; j++) {
      for (var i = xs[0]; i <= xs[1]; i++) {
        expected[j - 1][i - 1] = area['value'] as int;
      }
    }
    expect(result.map.grid, expected);
    // Both impostor cells became ordinary floor, so LOREMAIN never calls
    // specialevent there again; no cleared flag exists in the source.
    for (final x in [25, 26]) {
      expect(original.grid[25][x - 1], 52);
      expect(
        LoreTileProtocol.classify('keep', result.map.grid[25][x - 1]),
        LoreTileAction.walk,
      );
    }
  });

  test(
    'stale clear flags and consumed ids never suppress a source trigger',
    () {
      final engine = LoreScriptEngine(random: NoKeep3Random())
        ..consumedScripts.addAll(['keep3-necromancer-y26', 'keep3-trap-25-27']);
      const stale = {'keep3NecromancerCleared', 'keep3TrapCleared'};
      expect(start(engine: engine, flags: stale).hasPendingScene, isTrue);
      expect(
        startAt(25, 27, engine: engine, flags: stale)!.hasPendingScene,
        isTrue,
      );
      final finished = drive([0, 0]);
      expect(finished.events.last, 'scene:end');
      final run = start();
      expect(run.outcome.setFlags, isEmpty);
      expect(run.outcome.sourceEtcWrites, isEmpty);
    },
  );

  test('tile 0 is a no-op on every real KEEP3 row 26 cell; only tile 52 fights', () {
    final results = <int, bool>{};
    for (var x = 1; x <= 50; x++) {
      final tile = original.grid[25][x - 1];
      if (tile != 0 && tile != 52) continue;
      expect(
        LoreTileProtocol.classify('keep', tile),
        LoreTileAction.special,
        reason: 'x=$x',
      );
      for (final engine in [
        LoreScriptEngine(random: NoKeep3Random()),
        LoreScriptEngine(random: NoKeep3Random())
          ..loadFromJson(File('assets/data/scripts.json').readAsStringSync()),
      ]) {
        final dispatch = LoreSpecialEventDispatcher.resolve(
          action: LoreTileAction.special,
          mapId: 23,
          x: x,
          y: 26,
          context: ScriptContext(tileAtPlayer: tile),
          party: const [],
          scripts: engine,
          legacy: LoreDungeonEventManager.instance,
        );
        // One runtime owner: no JSON/legacy fallback even when it returns null.
        expect(dispatch.legacy, isNull, reason: 'x=$x');
        results[x] = dispatch.script != null;
      }
    }
    expect(results.keys.toList()..sort(), [12, 13, 25, 26, 38, 39]);
    expect(results, {
      12: false,
      13: false,
      25: true,
      26: true,
      38: false,
      39: false,
    });
    for (final tile in [1, 34, 46, 51, 53, 54]) {
      expect(startAt(25, 26, tile: tile), isNull, reason: 'tile $tile');
    }
  });

  test('sign read sets the lever tile, then the lever writes the map before it prints', () {
    final won = drive([0, 0]).map.grid;
    expect(won[42][28], (victory['tile'] as List)[2]);
    // LOREENT.PAS sign: map[25,27] := 52 for every map 23 sign.
    LoreEntProcedures.sign(
      mapId: 23,
      x: 29,
      y: 43,
      messageFor: (_, _, _) => null,
      display: (_) {},
      setTile: (x, y, tile) => won[y - 1][x - 1] = tile,
    );
    final leverX = lever['x'] as int;
    final leverY = lever['y'] as int;
    expect(won[leverY - 1][leverX - 1], 52);
    expect(
      LoreTileProtocol.classify('keep', won[leverY - 1][leverX - 1]),
      LoreTileAction.special,
    );

    final dispatch = LoreSpecialEventDispatcher.resolve(
      action: LoreTileAction.special,
      mapId: 23,
      x: leverX,
      y: leverY,
      context: const ScriptContext(tileAtPlayer: 52),
      party: const [],
      scripts: LoreScriptEngine(random: NoKeep3Random()),
      legacy: LoreDungeonEventManager.instance,
    );
    final run = dispatch.script!;
    expect(dispatch.legacy, isNull);
    // Writes come first and the closing PressAnyKey is the only boundary.
    expect(run.outcome.tileOperations.map(writeToken), [
      for (final tile in lever['tiles'] as List<dynamic>)
        'write:tile:${tile[0]},${tile[1]}=${tile[2]}',
      'write:area:12-39,7-34=39',
      for (final x in [25, 26]) 'write:tile:$x,12=54',
    ]);
    expect(run.pendingScene!.lines, strings(lever['lines']));
    expect(run.outcome.setFlags, isEmpty);
    expect(run.acknowledgeScene().hasPendingScene, isFalse);

    final after = ScriptWorldReducer.applyMap(
      stateAt(leverX, leverY, won),
      run.outcome,
    ).grid;
    final expected = [for (final row in won) List<int>.from(row)];
    for (var j = 7; j <= 34; j++) {
      for (var i = 12; i <= 39; i++) {
        if (won[j - 1][i - 1] == 0) expected[j - 1][i - 1] = 39;
      }
    }
    expected[leverY - 1][leverX - 1] = 46;
    expected[42][28] = 44;
    for (final x in [25, 26]) {
      expected[11][x - 1] = 54;
    }
    expect(after, expected);
    expect(
      LoreTileProtocol.classify('keep', after[leverY - 1][leverX - 1]),
      LoreTileAction.walk,
    );
    // Entrances created by the lever are the DUNGEON OF EVIL portal cells.
    expect(
      LoreTileProtocol.classify('keep', after[11][24]),
      LoreTileAction.enter,
    );
    expect(won.expand((row) => row).where((t) => t == 0).length, 274);
    expect(after.expand((row) => row).where((t) => t == 0), isEmpty);
  });

  test('lever branch needs the exact cell and a special tile; y = 46 is the portal', () {
    expect(startAt(25, 27, tile: 0), isNull);
    expect(startAt(25, 27, tile: 46), isNull);
    expect(startAt(26, 27), isNull);
    expect(startAt(25, 28), isNull);
    expect(startAt(25, 46), isNull);
    expect(startAt(30, 12), isNull);
  });

  test('map 23 and 25 exits use the exact y = 46 wantexit boundary', () {
    final manager = LoreWorldManager.instance;
    final exit = source['exit'] as Map<String, dynamic>;
    for (final x in [24, 25, 26, 27]) {
      final portal = manager.findPortal(23, x, 46)!;
      expect(
        [portal.targetMapId, portal.targetX, portal.targetY],
        [exit['targetMap'], exit['targetX'], exit['targetY']],
      );
    }
    expect(manager.findPortal(23, 25, 47), isNull);
    expect(exit['rejectDy'], -1);
  });
}

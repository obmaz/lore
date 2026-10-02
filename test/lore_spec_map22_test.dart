import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dungeon_event_manager.dart';
import 'package:lore/game/lore_world_manager.dart';
import 'package:lore/logic/lore_portal_session.dart';
import 'package:lore/logic/lore_spec_procedures.dart';
import 'package:lore/logic/lore_special_event_dispatcher.dart';
import 'package:lore/logic/lore_tile_protocol.dart';

/// Replays chosen random results and records every bound requested.
class SeqRandom implements Random {
  SeqRandom(this.values);
  final List<int> values;
  final calls = <int>[];
  @override
  int nextInt(int max) {
    calls.add(max);
    return values.removeAt(0);
  }

  @override
  bool nextBool() => throw StateError('Unexpected random Boolean');
  @override
  double nextDouble() => throw StateError('Unexpected random double');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LoreScriptEngine scripts;

  setUp(() {
    scripts = LoreScriptEngine()
      ..loadFromJson(File('assets/data/scripts.json').readAsStringSync());
  });

  ScriptRun? dispatchSpecial({
    required int mapId,
    required int x,
    required int y,
    int tile = 0,
    Set<String> flags = const {},
    Map<String, int> questSteps = const {},
  }) {
    final result = LoreSpecialEventDispatcher.resolve(
      action: LoreTileAction.special,
      mapId: mapId,
      x: x,
      y: y,
      context: ScriptContext(
        tileAtPlayer: tile,
        flags: flags,
        questSteps: questSteps,
      ),
      party: const [],
      scripts: scripts,
      legacy: LoreDungeonEventManager.instance,
    );
    expect(result.legacy, isNull);
    return result.script;
  }

  // ASCII facts read straight from the Pascal source (Korean text aside).
  final pascal = latin1
      .decode(File('repo_source/LORE_1993_src/LORESPEC.PAS').readAsBytesSync())
      .replaceAll('\r\n', '\n');
  final arm = RegExp(
    r'\n\s+22 : begin(.*?)\n\s+23 : begin',
    dotAll: true,
  ).firstMatch(pascal)!.group(1)!;

  ScriptRun? at(
    int x,
    int y, {
    int etc43 = 0,
    Random? random,
    Set<String> flags = const {},
  }) => LoreSpecProcedures.map22(
    x,
    y,
    ScriptContext(tileAtPlayer: 0, sourceEtc: {43: etc43}, flags: flags),
    LoreScriptEngine(random: random ?? SeqRandom([])),
  );

  group('LORESPEC 맵 22 KEEP2 분기 (LORESPEC.PAS:1816-1879)', () {
    test('source facts used below are still in the Pascal arm', () {
      for (final fact in [
        'j := random(5) + 42;',
        'if j = 42 then j := 35;',
        'for i := 1 to 6 do joinenemy(i,j);',
        'joinenemy(7,66);',
        'if enemy[7].dead then party.etc[43] := party.etc[43] or bit3;',
        'xaxis := 15; yaxis := 32; map := 5;',
        'joinenemy(random(5)+1,63);',
        'if party.etc[6] = 0 then party.etc[43] := party.etc[43] or bit2;',
        'joinenemy(1,61);',
        'battlemode(TRUE);',
        'if party.etc[6] = 0 then party.etc[43] := party.etc[43] or bit1;',
        'map[x,y] := 40;',
      ]) {
        expect(arm, contains(fact));
      }
    });

    test(
      'Death Knight: one random(5) picks the 63 slot; only victory sets bit2',
      () {
        for (var r = 0; r < 5; r++) {
          final random = SeqRandom([r]);
          final run = at(25, 18, random: random)!;
          expect(random.calls, [5]);
          expect(run.pendingScene!.lines.first, ' 나는 이 요새의 Wraith를 조종하는 죽음의 기');
          final battle = run.acknowledgeScene();
          expect(battle.outcome.battleMonsters, [
            for (var i = 0; i < 5; i++) i == r ? 63 : 60,
          ]);
          expect(battle.outcome.battleEnemyFirst, isTrue);
          expect(battle.continueAfterBattle().outcome.setFlags, ['etc43_bit2']);
          expect(battle.continueAfterRunAway().outcome.setFlags, isEmpty);
          expect(battle.continueAfterDefeat(), isNull);
        }
      },
    );

    test(
      'raw etc[43] decides every fight for all 256 bytes; stale aliases do not',
      () {
        const stale = {
          'keep2AmbushCleared',
          'keep2GuardsCleared',
          'etc43_bit1',
          'etc43_bit2',
        };
        for (var b = 0; b < 256; b++) {
          final bit1 = b & 1 != 0;
          final bit2 = b & 2 != 0;
          expect(
            at(25, 18, etc43: b, random: SeqRandom([0]), flags: stale) == null,
            bit2,
          );
          expect(at(25, 25, etc43: b, flags: stale) == null, bit1);
          expect(at(10, 10, etc43: b, flags: stale) == null, bit2);
        }
      },
    );

    test('guards fight first with the fixed roster and no random draw', () {
      for (final x in [24, 25, 26]) {
        final run = at(x, 25)!;
        expect(run.outcome.battleMonsters, [61, 58, 56, 55, 60]);
        expect(run.outcome.battleEnemyFirst, isFalse);
        expect(run.continueAfterBattle().outcome.setFlags, ['etc43_bit1']);
        expect(run.continueAfterRunAway().outcome.setFlags, isEmpty);
      }
      expect(at(23, 25)!.outcome.battleMonsters, [60, 60, 60, 60, 60]);
    });

    test('other special tiles: Wraith ambush, tile 40 after victory or escape, no flag', () {
      final run = at(10, 10)!;
      expect(run.outcome.battleMonsters, [60, 60, 60, 60, 60]);
      expect(run.outcome.battleEnemyFirst, isTrue);
      for (final next in [
        run.continueAfterBattle(),
        run.continueAfterRunAway(),
      ]) {
        final delta = next.outcome.since(run.outcome);
        expect(delta.tileChanges.map((t) => [t.x, t.y, t.tile]), [
          [10, 10, 40],
        ]);
        expect(delta.setFlags, isEmpty);
      }
      expect(at(25, 46), isNull);
    });

    test('exit guard: after wantexit, random(5)+42 (42 -> 35), bit3 iff enemy 7 died, exit always', () {
      const pick = [35, 43, 44, 45, 46];
      for (var r = 0; r < 5; r++) {
        final random = SeqRandom([r]);
        final guard = LoreSpecProcedures.keep2ExitGuard(
          const ScriptContext(sourceEtc: {43: 0}),
          random.nextInt,
        )!;
        expect(random.calls, [5]);
        final run = LoreScriptEngine().startProcedure(
          guard,
          const ScriptContext(),
        );
        expect(
          run.pendingScene!.withPartyNames(['아린']).lines.single,
          '아린, 나의 힘을 보여주겠다.',
        );
        final battle = run.acknowledgeScene();
        expect(battle.outcome.battleMonsters, [...List.filled(6, pick[r]), 66]);
        expect(battle.outcome.battleEnemyFirst, isTrue);
        final won = battle.continueAfterBattle();
        expect(won.outcome.setFlags, ['etc43_bit3']);
        expect(won.awaitingBattle || won.hasPendingScene, isFalse);
        final fledKilled = battle.continueAfterRunAway(defeatedEnemySlots: {7});
        expect(fledKilled.outcome.setFlags, ['etc43_bit3']);
        final fled = battle.continueAfterRunAway(
          defeatedEnemySlots: {1, 2, 3, 4, 5, 6},
        );
        expect(fled.outcome.setFlags, isEmpty);
        expect(fled.awaitingBattle || fled.hasPendingScene, isFalse);
      }
      for (var b = 0; b < 256; b++) {
        final guard = LoreSpecProcedures.keep2ExitGuard(
          ScriptContext(sourceEtc: {43: b}),
          SeqRandom([0]).nextInt,
        );
        expect(guard == null, b & 4 != 0);
      }
    });

    test('exit boundary: y=46 asks first, refusal y=45, cleared bit3 loads directly', () {
      final portal = LoreWorldManager.instance.findPortal(22, 25, 46)!;
      expect([portal.targetMapId, portal.targetX, portal.targetY], [5, 15, 32]);
      expect(LoreWorldManager.instance.findPortal(22, 25, 47), isNull);
      expect(LoreWorldManager.sourceExitRejectY(22, 46), 45);
      ScriptContext ctx(int b) => ScriptContext(sourceEtc: {43: b});
      expect(
        LorePortalSession.begin(
          confirmed: false,
          portal: portal,
          context: ctx(0),
          scripts: LoreScriptEngine(random: SeqRandom([])),
        ).action,
        LorePortalAction.cancelled,
      );
      final engine = LoreScriptEngine(random: SeqRandom([2]));
      final plan = LorePortalSession.begin(
        confirmed: true,
        portal: portal,
        context: ctx(0),
        scripts: engine,
      );
      expect(plan.action, LorePortalAction.runPreScript);
      expect(
        plan.preScript!.acknowledgeScene().outcome.battleMonsters.first,
        44,
      );
      expect(
        LorePortalSession.begin(
          confirmed: true,
          portal: portal,
          context: ctx(4),
          scripts: LoreScriptEngine(random: SeqRandom([])),
        ).action,
        LorePortalAction.loadMap,
      );
    });

    test('dispatcher owns map 22 with or without JSON', () {
      expect(
        dispatchSpecial(mapId: 22, x: 25, y: 25)!.outcome.battleMonsters.length,
        5,
      );
      final noJson = LoreSpecialEventDispatcher.resolve(
        action: LoreTileAction.special,
        mapId: 22,
        x: 25,
        y: 25,
        context: const ScriptContext(tileAtPlayer: 0),
        party: const [],
        scripts: LoreScriptEngine(),
        legacy: LoreDungeonEventManager.instance,
      );
      expect(noJson.legacy, isNull);
      expect(noJson.script!.outcome.battleMonsters, [61, 58, 56, 55, 60]);
    });
  });
}

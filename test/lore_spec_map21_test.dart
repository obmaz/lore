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

  final pascal = latin1
      .decode(File('repo_source/LORE_1993_src/LORESPEC.PAS').readAsBytesSync())
      .replaceAll('\r\n', '\n');
  final arm = RegExp(
    r'\n\s+21 : begin(.*?)\n\s+22 : begin',
    dotAll: true,
  ).firstMatch(pascal)!.group(1)!;

  ScriptRun? at(
    int x,
    int y, {
    int tile = 0,
    Map<int, int> etc = const {40: 0, 41: 0},
    Random? random,
    Set<String> flags = const {},
  }) => LoreSpecProcedures.map21(
    x,
    y,
    ScriptContext(tileAtPlayer: tile, sourceEtc: etc, flags: flags),
    LoreScriptEngine(random: random ?? SeqRandom([])),
  );

  group('LORESPEC 맵 21 KEEP1 분기 (LORESPEC.PAS:1760-1815)', () {
    test('source facts used below are still in the Pascal arm', () {
      for (final fact in [
        'if party.etc[42] and bit1 = 0 then begin',
        'joinenemy(j,55);',
        'joinenemy(j,56);',
        'party.etc[42] := party.etc[42] or bit1;\n                          exit;',
        'for i := j to j+4 do joinenemy(i,35);',
        'if enemy[1].dead then party.etc[42] := party.etc[42] or bit3;',
        'if enemy[2].dead then party.etc[42] := party.etc[42] or bit4;',
        'xaxis := 48; yaxis := 36; map := 4;',
        'if not (odd(party.etc[40]) and odd(party.etc[41])) then begin',
        'enemynumber := random(4)+3;',
        'joinenemy(i,58);',
        'if j = 0 then map[x,y] := 40 else map[x,y] := 46;',
      ]) {
        expect(arm, contains(fact));
      }
    });

    test(
      'lava gate refuses unless both seal bytes are odd, then pushes y + 1',
      () {
        for (final a in [0, 1, 2, 3, 254, 255]) {
          for (final b in [0, 1, 2, 3, 254, 255]) {
            final run = at(25, 20, etc: {40: a, 41: b});
            if (a.isOdd && b.isOdd) {
              expect(run, isNull);
              continue;
            }
            expect(run!.pendingScene!.lines.first, ' 당신은 아직 라바 게이트를 열수가 없다');
            final done = run.acknowledgeScene();
            expect(done.outcome.nudges.single.dy, 1);
          }
        }
        // Raw zero beats stale aliases.
        expect(
          at(
            25,
            20,
            etc: {40: 0, 41: 1},
            flags: {'evilSealRoomCleared', 'sealPuzzleA'},
          ),
          isNotNull,
        );
      },
    );

    test('other specials: one random(4)+3 group of 58, tile 0 -> 40 else 46 after victory or escape', () {
      for (var r = 0; r < 4; r++) {
        for (final tile in [0, 52]) {
          final random = SeqRandom([r]);
          final run = at(10, 10, tile: tile, random: random)!;
          expect(random.calls, [4]);
          expect(run.outcome.battleMonsters, List.filled(r + 3, 58));
          expect(run.outcome.battleEnemyFirst, isTrue);
          for (final next in [
            run.continueAfterBattle(),
            run.continueAfterRunAway(),
          ]) {
            expect(
              next.outcome
                  .since(run.outcome)
                  .tileChanges
                  .map((t) => [t.x, t.y, t.tile]),
              [
                [10, 10, tile == 0 ? 40 : 46],
              ],
            );
          }
          expect(run.continueAfterDefeat(), isNull);
        }
      }
      expect(at(25, 46), isNull);
    });

    test('exit guard bosses, slot-based bits and the no-boss early exit for all 256 bytes', () {
      for (var b = 0; b < 256; b++) {
        final guard = LoreSpecProcedures.keep1ExitGuard(
          ScriptContext(sourceEtc: {42: b}),
          25,
          46,
        );
        if (b & 1 != 0) {
          expect(guard, isNull);
          continue;
        }
        final run = LoreScriptEngine().startProcedure(
          guard!,
          const ScriptContext(),
        );
        final bosses = [if (b & 4 == 0) 55, if (b & 8 == 0) 56];
        if (bosses.isEmpty) {
          expect(run.awaitingBattle, isFalse);
          expect(run.outcome.setFlags, ['etc42_bit1']);
          expect(run.outcome.blockMove, isTrue);
          expect([run.outcome.teleportX, run.outcome.teleportY], [25, 46]);
          continue;
        }
        expect(run.outcome.battleMonsters, [...bosses, 35, 35, 35, 35, 35]);
        expect(run.outcome.battleEnemyFirst, isTrue);
        expect(run.outcome.battleVictoryFlags, ['etc42_bit1']);
        expect(run.continueAfterBattle().outcome.setFlags, [
          'etc42_bit3',
          'etc42_bit4',
        ]);
        expect(
          run.continueAfterRunAway(defeatedEnemySlots: {1}).outcome.setFlags,
          ['etc42_bit3'],
        );
        expect(
          run.continueAfterRunAway(defeatedEnemySlots: {2, 3}).outcome.setFlags,
          ['etc42_bit4'],
        );
        expect(
          run.continueAfterRunAway(defeatedEnemySlots: {1, 2}).outcome.setFlags,
          ['etc42_bit3', 'etc42_bit4', 'etc42_bit1'],
        );
        final fled = run.continueAfterRunAway();
        expect(fled.outcome.setFlags, isEmpty);
        expect(fled.awaitingBattle || fled.outcome.blockMove, isFalse);
      }
    });

    test(
      'exit boundary and portal session order: ask, then guard or direct load',
      () {
        final portal = LoreWorldManager.instance.findPortal(21, 25, 46)!;
        expect(
          [portal.targetMapId, portal.targetX, portal.targetY],
          [4, 48, 36],
        );
        expect(LoreWorldManager.instance.findPortal(21, 25, 47), isNull);
        expect(LoreWorldManager.sourceExitRejectY(21, 46), 45);
        LorePortalPlan begin(bool yes, int b) => LorePortalSession.begin(
          confirmed: yes,
          portal: portal,
          context: ScriptContext(sourceEtc: {42: b}),
          scripts: LoreScriptEngine(random: SeqRandom([])),
          x: 25,
          y: 46,
        );
        expect(begin(false, 0).action, LorePortalAction.cancelled);
        expect(begin(true, 0).action, LorePortalAction.runPreScript);
        expect(begin(true, 1).action, LorePortalAction.loadMap);
        final early = begin(true, 12).preScript!;
        expect(
          LorePortalSession.afterPreScript(
            completed: true,
            waitingForBattle: false,
            blockMove: early.outcome.blockMove,
          ),
          LorePortalAction.blocked,
        );
      },
    );

    test('dispatcher owns map 21 with or without JSON', () {
      expect(dispatchSpecial(mapId: 21, x: 25, y: 20)!.hasPendingScene, isTrue);
      final noJson = LoreSpecialEventDispatcher.resolve(
        action: LoreTileAction.special,
        mapId: 21,
        x: 25,
        y: 20,
        context: const ScriptContext(
          tileAtPlayer: 0,
          sourceEtc: {40: 1, 41: 1},
        ),
        party: const [],
        scripts: LoreScriptEngine(),
        legacy: LoreDungeonEventManager.instance,
      );
      expect(noJson.legacy, isNull);
      expect(noJson.script, isNull);
    });
  });
}

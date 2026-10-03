import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_world_manager.dart';
import 'package:lore/logic/lore_portal_session.dart';
import 'package:lore/logic/lore_spec_procedures.dart';

/// After `GameOver` reloads a defeat, `BattleMode` returns into its caller.
/// LORESPEC.PAS / LOREENT.PAS arms without an `etc[6] = 255` check keep running
/// on the loaded game, whose position `Load` copies into the globals x, y.
void main() {
  final scripts = LoreScriptEngine();

  ScriptRun drain(ScriptRun run) {
    var current = run;
    while (current.hasPendingScene) {
      current = current.acknowledgeScene();
    }
    return current;
  }

  group('arms that stop on etc[6] = 255 run nothing', () {
    test('map 20 y=13 dragons and mud men, map 22 Death Knight and guards', () {
      final dragons = drain(
        LoreSpecProcedures.map20(
          24,
          13,
          const ScriptContext(tileAtPlayer: 0, sourceEtc: {41: 0, 1: 1}),
          scripts,
        )!,
      );
      expect(dragons.outcome.battleMonsters, [54, 54, 54]);
      expect(dragons.continueAfterDefeat(), isNull);
      final knight = drain(
        LoreSpecProcedures.map22(
          25,
          18,
          const ScriptContext(sourceEtc: {43: 0}),
          scripts,
        )!,
      );
      expect(knight.continueAfterDefeat(), isNull);
      final guards = LoreSpecProcedures.map22(
        25,
        25,
        const ScriptContext(sourceEtc: {43: 0}),
        scripts,
      )!;
      expect(guards.continueAfterDefeat(), isNull);
    });
  });

  group('unchecked arms run their escape path', () {
    test('map 20 Astral Mud: enemy 7 dead -> bit1 and map 4, else y + 1', () {
      final astral = drain(
        LoreSpecProcedures.map20(
          24,
          13,
          const ScriptContext(tileAtPlayer: 0, sourceEtc: {41: 6, 1: 1}),
          scripts,
        )!,
      );
      expect(astral.outcome.battleMonsters.last, 57);
      final won = astral.continueAfterDefeat(defeatedEnemySlots: {7})!;
      expect(won.outcome.setFlags, contains('etc41_bit1'));
      expect(won.outcome.teleportMap, 4);
      final lost = astral.continueAfterDefeat(defeatedEnemySlots: {1, 2})!;
      expect(lost.outcome.since(astral.outcome).nudges, [(dx: 0, dy: 1)]);
    });

    test('KEEP1 / KEEP2 exit guards: slot bits, then the exit continues', () {
      final keep1 = scripts.startProcedure(
        LoreSpecProcedures.keep1ExitGuard(
          const ScriptContext(sourceEtc: {42: 0}),
          25,
          46,
        )!,
        const ScriptContext(),
      );
      expect(
        keep1.continueAfterDefeat(defeatedEnemySlots: {1, 2})!.outcome.setFlags,
        containsAll(['etc42_bit3', 'etc42_bit4', 'etc42_bit1']),
      );
      final keep2 = scripts.startProcedure(
        LoreSpecProcedures.keep2ExitGuard(
          const ScriptContext(sourceEtc: {43: 0}),
          (_) => 0,
        )!,
        const ScriptContext(),
      );
      final next = drain(keep2);
      expect(
        next.continueAfterDefeat(defeatedEnemySlots: {7})!.outcome.setFlags,
        ['etc43_bit3'],
      );
      expect(
        next.continueAfterDefeat(defeatedEnemySlots: {1})!.outcome.blockMove,
        isFalse,
      );
    });

    test(
      'LOREENT lava gate and dungeon: entrance continues, chamber stops',
      () {
        LorePortalPlan begin(PortalInfo portal, Set<String> flags) =>
            LorePortalSession.begin(
              confirmed: true,
              portal: portal,
              context: ScriptContext(flags: flags),
              scripts: scripts,
            );
        const lavaGate = PortalInfo(
          targetMapId: 22,
          targetX: 25,
          targetY: 6,
          name: 'IMPERIUM MINOR',
          scriptId: 'portal-21-22-lavagate',
        );
        final gate = begin(lavaGate, {
          'lavaGateKeyLeft',
          'lavaGateKeyRight',
        }).preScript!;
        final afterGate = gate.continueAfterDefeat(defeatedEnemySlots: {1})!;
        expect(afterGate.outcome.setFlags, ['lavaGateLeftGuardianDefeated']);
        expect(afterGate.outcome.blockMove, isFalse);
        const dungeon = PortalInfo(
          targetMapId: 25,
          targetX: 25,
          targetY: 45,
          name: 'DUNGEON OF EVIL',
          scriptId: 'portal-23-25-dungeon',
        );
        final guard = drain(begin(dungeon, {}).preScript!);
        expect(guard.continueAfterDefeat()!.outcome.blockMove, isTrue);
        expect(
          guard.continueAfterDefeat(defeatedEnemySlots: {3})!.outcome.setFlags,
          contains('dungeonOfEvilCleared'),
        );
        const chamber = PortalInfo(
          targetMapId: 26,
          targetX: 25,
          targetY: 15,
          name: 'CHAMBER OF NECROMANCER',
          scriptId: 'portal-25-26-chamber',
        );
        expect(
          drain(begin(chamber, {}).preScript!).continueAfterDefeat(),
          isNull,
        );
      },
    );
  });

  group(
    'afterReload: the later checks of the same case arm on the loaded x, y',
    () {
      test(
        'map 18 after the Minotaur: Spica at (37,31), Huge Dragon on x = 31',
        () {
          const context = ScriptContext(
            tileAtPlayer: 40,
            sourceEtc: {39: 0, 15: 0},
          );
          expect(
            LoreSpecProcedures.afterReload(
              18,
              37,
              31,
              context,
              scripts,
            )!.script.id,
            'spica-first-meeting',
          );
          expect(
            LoreSpecProcedures.afterReload(
              18,
              31,
              20,
              context,
              scripts,
            )!.script.id,
            'map18-huge-dragon',
          );
          expect(
            LoreSpecProcedures.afterReload(18, 21, 41, context, scripts),
            isNull,
          );
          expect(
            LoreSpecProcedures.afterReload(18, 22, 41, context, scripts),
            isNull,
          );
          expect(
            LoreSpecProcedures.afterReload(18, 10, 95, context, scripts),
            isNull,
          );
        },
      );

      test('map 19 after the guardians: only the y = 6 seal rooms', () {
        const context = ScriptContext(tileAtPlayer: 40, sourceEtc: {40: 4});
        expect(
          LoreSpecProcedures.afterReload(
            19,
            14,
            6,
            context,
            scripts,
          )!.script.id,
          'evil-seal-room-wrong-1',
        );
        expect(
          LoreSpecProcedures.afterReload(19, 14, 10, context, scripts),
          isNull,
        );
        expect(
          LoreSpecProcedures.afterReload(19, 11, 40, context, scripts),
          isNull,
        );
      });

      test('map 20 after the Minotaur: only y = 13', () {
        const context = ScriptContext(
          tileAtPlayer: 40,
          sourceEtc: {41: 0, 1: 1},
        );
        expect(
          LoreSpecProcedures.afterReload(
            20,
            5,
            13,
            context,
            scripts,
          )!.script.id,
          'den7-final-y13',
        );
        expect(
          LoreSpecProcedures.afterReload(20, 25, 48, context, scripts),
          isNull,
        );
        expect(
          LoreSpecProcedures.afterReload(20, 25, 18, context, scripts),
          isNull,
        );
        expect(
          LoreSpecProcedures.afterReload(21, 5, 13, context, scripts),
          isNull,
        );
      });
    },
  );
}

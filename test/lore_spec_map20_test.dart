import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dungeon_event_manager.dart';
import 'package:lore/logic/lore_spec_procedures.dart';
import 'package:lore/logic/lore_special_event_dispatcher.dart';
import 'package:lore/logic/lore_tile_protocol.dart';

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

  group('LORESPEC 맵 20 DEN5 / ASTRAL DEN 분기 검증 (LORESPEC.PAS:1475-1759)', () {
    test('원본 DEN7 y=18 특수 타일은 횃불을 켠다', () {
      final bytes = File('assets/maps/DEN7.MAP').readAsBytesSync();
      final width = bytes[0];
      expect(bytes[2 + (18 - 1) * width + 24 - 1], 0);
      final run = dispatchSpecial(mapId: 20, x: 24, y: 18, tile: 0)!;
      expect(run.script.id, 'den7-torch-y18');
      expect(run.outcome.torchLit, isTrue);
      expect(run.outcome.setFlags, isNot(contains('etc1')));
    });

    test('y=88 및 y=71 퀴즈 문은 타일 0이면 통과 워프, 아니면 동굴 밖으로 퇴장시킨다', () {
      // LoreSpecProcedures.map20 직접 호출 검증 (타일 0 통과)
      final directPass = LoreSpecProcedures.map20(
        8,
        88,
        const ScriptContext(tileAtPlayer: 0),
        scripts,
      )!;
      expect(directPass.outcome.teleportY, 80);

      // y=88 통과
      final pass88 = dispatchSpecial(mapId: 20, x: 8, y: 88, tile: 0)!;
      expect(pass88.outcome.teleportY, 80);

      // y=88 실패 퇴장
      final fail88 = dispatchSpecial(mapId: 20, x: 8, y: 88, tile: 52)!;
      expect(
        (
          fail88.outcome.teleportMap,
          fail88.outcome.teleportX,
          fail88.outcome.teleportY,
        ),
        (4, 82, 17),
      );

      // y=71 통과
      final pass71 = dispatchSpecial(mapId: 20, x: 8, y: 71, tile: 0)!;
      expect(pass71.outcome.teleportY, 63);

      // y=71 실패 퇴장
      final fail71 = dispatchSpecial(mapId: 20, x: 8, y: 71, tile: 52)!;
      expect(
        (
          fail71.outcome.teleportMap,
          fail71.outcome.teleportX,
          fail71.outcome.teleportY,
        ),
        (4, 82, 17),
      );
    });

    test('y=48 Minotaur: torch only when 0, bit4 after victory or escape, raw bits decide', () {
      for (var b = 0; b < 256; b++) {
        final run = LoreSpecProcedures.map20(
          25,
          48,
          ScriptContext(tileAtPlayer: 0, sourceEtc: {41: b, 1: 0}),
          scripts,
        );
        expect(run == null, b & 8 != 0);
      }
      final run = LoreSpecProcedures.map20(
        25,
        48,
        const ScriptContext(tileAtPlayer: 0, sourceEtc: {41: 0, 1: 0}),
        scripts,
      )!;
      expect(run.outcome.sourceEtcWrites.map((w) => [w.index, w.value]), [
        [1, 1],
      ]);
      expect(run.pendingScene!.lines, ['미로속에서 소를 닮은 괴물이 나타났다']);
      final battle = run.acknowledgeScene();
      expect(battle.outcome.battleMonsters, [53]);
      expect(battle.outcome.battleEnemyFirst, isTrue);
      expect(battle.continueAfterBattle().outcome.setFlags, ['etc41_bit4']);
      expect(battle.continueAfterRunAway().outcome.setFlags, ['etc41_bit4']);
      // No etc[6] check: after a GameOver reload the escape path runs.
      expect(battle.continueAfterDefeat()!.outcome.setFlags, ['etc41_bit4']);
      expect(battle.resumesAfterReload, isTrue);
      final lit = LoreSpecProcedures.map20(
        25,
        48,
        const ScriptContext(tileAtPlayer: 0, sourceEtc: {41: 0, 1: 9}),
        scripts,
      )!;
      expect(lit.outcome.sourceEtcWrites, isEmpty);
    });

    test('y=13 chains dragons -> mud men -> Astral Mud on raw etc[41]; escapes push y+1', () {
      ScriptRun at(int b) => LoreSpecProcedures.map20(
        24,
        13,
        ScriptContext(tileAtPlayer: 0, sourceEtc: {41: b, 1: 1}),
        scripts,
      )!;
      var run = at(0);
      expect(run.pendingScene!.lines, isEmpty);
      run = run.acknowledgeScene();
      expect(run.outcome.battleMonsters, [54, 54, 54]);
      expect(run.continueAfterRunAway().outcome.nudges.single.dy, 1);
      run = run.continueAfterBattle();
      expect(run.outcome.setFlags, ['etc41_bit2']);
      expect(run.outcome.battleMonsters, List.filled(7, 31));
      expect(run.continueAfterRunAway().outcome.nudges.single.dy, 1);
      run = run.continueAfterBattle();
      expect(run.outcome.setFlags, ['etc41_bit2', 'etc41_bit3']);
      expect(run.pendingScene!.title, 'Astral Mud');
      run = run.acknowledgeScene();
      expect(run.outcome.battleMonsters, [...List.filled(6, 31), 57]);
      expect(run.isVictoryAfterRunAway({7}), isTrue);
      expect(
        run
            .continueAfterRunAway(defeatedEnemySlots: {1, 2})
            .outcome
            .nudges
            .single
            .dy,
        1,
      );
      final won = run.continueAfterRunAway(defeatedEnemySlots: {7});
      expect(won.outcome.setFlags.last, 'etc41_bit1');
      expect(
        [won.outcome.teleportMap, won.outcome.teleportX, won.outcome.teleportY],
        [4, 82, 17],
      );
      expect(won.pendingScene!.lines.first, ' 당신은 이 동굴에 보관되어 있는 봉인을 발견');
      // Already-won bits skip their fights; all three set leaves for map 4.
      expect(at(2).outcome.battleMonsters, List.filled(7, 31));
      expect(at(6).pendingScene!.title, 'Astral Mud');
      final done = at(7);
      expect(done.awaitingBattle || done.hasPendingScene, isFalse);
      expect(
        [
          done.outcome.teleportMap,
          done.outcome.teleportX,
          done.outcome.teleportY,
        ],
        [4, 82, 17],
      );
      expect(at(1).outcome.teleportMap, isNull);
    });

    test(
      'quizzes draw one random(8) and write the row and doors before waiting',
      () {
        for (final y in [91, 75]) {
          for (var r = 0; r < 8; r++) {
            final engine = LoreScriptEngine(random: _Fixed(r));
            final run = LoreSpecProcedures.map20(
              25,
              y,
              const ScriptContext(tileAtPlayer: 0),
              engine,
            )!;
            final door = y == 91 ? 88 : 71;
            expect(
              run.outcome.tileOperations.map(
                (o) => [o.kind, o.tileX, o.tileY, o.tileValue],
              ),
              [
                ['setTileArea', 23, y, 44],
                ['setTile', 8, door, r < 4 ? 52 : 0],
                ['setTile', 43, door, r < 4 ? 0 : 52],
              ],
            );
            expect(run.pendingScene!.lines.length, 4);
          }
        }
      },
    );

    test('y=54 quiz: Escape moves y+1, right answer opens rows 49..52, wrong answer leaves', () {
      for (var r = 0; r < 8; r++) {
        final run = LoreSpecProcedures.map20(
          24,
          54,
          const ScriptContext(tileAtPlayer: 0),
          LoreScriptEngine(random: _Fixed(r)),
        )!;
        expect(run.outcome.messages.last, startsWith('문> '));
        expect(run.hasCancelSteps, isTrue);
        final cancelled = run.cancel();
        expect(cancelled.outcome.nudges.single.dy, 1);
        expect(cancelled.outcome.tileOperations, isEmpty);
        final right = run.choose(r > 3 ? 0 : 1);
        expect(right.outcome.teleportMap, isNull);
        expect(right.outcome.tileOperations.length, 13);
        final wrong = run.choose(r > 3 ? 1 : 0);
        expect(
          [
            wrong.outcome.teleportMap,
            wrong.outcome.teleportX,
            wrong.outcome.teleportY,
          ],
          [4, 82, 17],
        );
        expect(
          wrong.outcome.messages.where(
            (m) => m.contains('정답') || m.contains('오답'),
          ),
          isEmpty,
        );
      }
    });

    test('y=96 belongs to the exit boundary', () {
      expect(
        LoreSpecProcedures.map20(
          25,
          96,
          const ScriptContext(tileAtPlayer: 0),
          scripts,
        ),
        isNull,
      );
    });

    test('특수 사건 위치가 아닌 곳은 null을 반환한다', () {
      final normal = dispatchSpecial(mapId: 20, x: 1, y: 1);
      expect(normal, isNull);
    });
  });
}

class _Fixed implements Random {
  _Fixed(this.value);
  final int value;
  var used = false;
  @override
  int nextInt(int max) {
    if (used) throw StateError('more than one random draw');
    used = true;
    expect(max, 8);
    return value;
  }

  @override
  bool nextBool() => throw StateError('Unexpected random Boolean');
  @override
  double nextDouble() => throw StateError('Unexpected random double');
}

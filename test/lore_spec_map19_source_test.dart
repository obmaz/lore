import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/game/lore_dungeon_event_manager.dart';
import 'package:lore/logic/lore_battle_progress.dart';
import 'package:lore/logic/lore_spec_procedures.dart';
import 'package:lore/logic/lore_special_event_dispatcher.dart';
import 'package:lore/logic/lore_tile_protocol.dart';
import 'package:lore/logic/script_battle_session.dart';
import 'package:lore/logic/script_world_reducer.dart';

class RecordingRandom implements Random {
  final int value;
  final List<int> bounds = [];
  RecordingRandom(this.value);
  @override
  int nextInt(int max) {
    bounds.add(max);
    expect(value, inInclusiveRange(0, max - 1));
    return value;
  }

  @override
  bool nextBool() => throw StateError('Unexpected random Boolean');
  @override
  double nextDouble() => throw StateError('Unexpected random double');
}

ScriptProgressState progress(int value) => ScriptProgressState(
  flags: const {},
  quests: const {},
  sourceEtc: {40: value},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Independent expectations are LORESPEC.PAS:1378-1473, not JSON outcomes.
  test(
    'both levers use etc[3], for all byte values; etc[4] does not block',
    () {
      for (var value = 0; value < 256; value++) {
        for (final (x, y) in [(11, 40), (41, 39)]) {
          final random = RecordingRandom(0);
          final run = LoreSpecProcedures.map19(
            x,
            y,
            ScriptContext(
              tileAtPlayer: 0,
              flags: const {'swampWalkActive', 'levitationActive'},
              sourceEtc: {3: value, 4: 255, 40: 0},
            ),
            LoreScriptEngine(random: random),
          )!;
          expect(run.outcome.tileOperations.isEmpty, value != 0);
          expect(random.bounds, x == 41 && value == 0 ? [7] : isEmpty);
        }
      }
    },
  );

  test(
    'lever B replaces even etc[40], preserves odd bytes and exact write order',
    () {
      for (var before = 0; before < 256; before++) {
        for (var draw = 0; draw < 7; draw++) {
          final random = RecordingRandom(draw);
          final run = LoreSpecProcedures.map19(
            41,
            39,
            ScriptContext(sourceEtc: {3: 0, 40: before}),
            LoreScriptEngine(random: random),
          )!;
          final after = ScriptWorldReducer.applyProgress(
            progress(before),
            run.outcome,
          );
          expect(after.sourceEtc[40], before.isOdd ? before : (draw + 1) * 2);
          expect(random.bounds, before.isOdd ? isEmpty : [7]);
          final writes = run.outcome.tileOperations
              .map((s) => (s.tileX, s.tileY, s.tileValue))
              .toList();
          expect(writes, [
            (41, 39, 49),
            if (before.isEven) ...[
              for (var j = 27; j <= 36; j++) ...[(24, j, 25), (28, j, 23)],
              (24, 37, 17),
              (28, 37, 19),
              for (var j = 27; j <= 37; j++)
                for (var i = 25; i <= 27; i++) (i, j, 44),
            ],
          ]);
        }
      }
    },
  );

  test(
    'guardian random(3)+3 overrides each slot and closes tile on every result',
    () {
      for (var draw = 0; draw < 3; draw++) {
        for (final end in LoreBattleEnd.values) {
          final random = RecordingRandom(draw);
          final run = LoreSpecProcedures.map19(
            14,
            10,
            const ScriptContext(sourceEtc: {40: 6}),
            LoreScriptEngine(random: random),
          )!;
          expect(random.bounds, [3]);
          expect(run.outcome.battleMonsters, List.filled(draw + 3, 59));
          expect(run.outcome.battleEnemyFirst, isFalse);
          expect(run.outcome.battleOverrides, [
            for (var slot = 1; slot <= draw + 3; slot++)
              {'index': slot, 'eNumber': 25, 'hp': 210, 'level': 7},
          ]);
          expect(run.outcome.tileOperations, isEmpty);
          final result = ScriptBattleSession.resolve(
            before: const LoreBattleProgressState(
              gold: 0,
              lastBattleResult: 0,
              flags: {},
            ),
            end: end,
            enemies: const [],
            pendingScript: run,
          );
          expect(result.delta.tileChanges.single, (
            map: null,
            x: 14,
            y: 10,
            tile: 49,
            ifZero: null,
          ));
          expect(result.delta.sourceEtcWrites, isEmpty);
          expect(result.delta.nudges, isEmpty);
          expect(random.bounds, [3]);
        }
      }
    },
  );

  test(
    'shr/div room test keeps full encoded byte and source division boundaries',
    () {
      for (var byte = 0; byte < 256; byte++) {
        for (var x = 1; x <= 50; x++) {
          final random = RecordingRandom(0);
          final run = LoreSpecProcedures.map19(
            x,
            6,
            ScriptContext(sourceEtc: {40: byte}),
            LoreScriptEngine(random: random),
          );
          if (byte.isOdd) {
            expect(run, isNull);
          } else {
            final correct = (byte >> 1) == ((x - 10) ~/ 4);
            expect(run!.awaitingBattle, correct);
            expect(run.outcome.tileChanges.first, (
              map: null,
              x: x,
              y: 5,
              tile: 49,
              ifZero: null,
            ));
            if (!correct) {
              expect(run.outcome.tileChanges.last, (
                map: null,
                x: x,
                y: 6,
                tile: 49,
                ifZero: null,
              ));
              expect(run.outcome.nudges, isEmpty);
            }
          }
          expect(random.bounds, isEmpty);
        }
      }
    },
  );

  test('boss has seven original slots; victory ORs bit, escape increments y, defeat exits', () {
    for (var room = 1; room <= 7; room++) {
      final byte = room << 1;
      final run = LoreSpecProcedures.map19(
        room * 4 + 10,
        6,
        ScriptContext(sourceEtc: {40: byte}),
        LoreScriptEngine(),
      )!;
      expect(run.outcome.battleMonsters, List.filled(7, 59));
      expect(run.outcome.battleEnemyFirst, isTrue);
      expect(run.outcome.battleOverrides, [
        for (var slot = 4; slot <= 7; slot++)
          {'index': slot, 'eNumber': 25, 'hp': 210, 'level': 7},
      ]);
      final won = run.continueAfterBattle().outcome.since(run.outcome);
      expect(won.sourceEtcWrites, [(index: 40, value: byte | 1)]);
      expect(won.nudges, isEmpty);
      expect(won.tileOperations, isEmpty);
      final fled = run.continueAfterRunAway().outcome.since(run.outcome);
      expect(fled.nudges, [(dx: 0, dy: 1)]);
      expect(fled.sourceEtcWrites, isEmpty);
      expect(fled.messages, isEmpty);
      expect(run.continueAfterDefeat(), isNull);
      final applied = ScriptWorldReducer.applyProgress(progress(byte), won);
      final manager = LoreDialogueManager.instance;
      manager.loadSaveFlags({'etc40': applied.sourceEtc[40]});
      final saved = manager.getSaveFlags();
      manager.loadSaveFlags({});
      manager.loadSaveFlags(saved);
      expect(manager.partyEtc.read(40), byte | 1);
      expect(
        LoreSpecProcedures.map19(
          14,
          10,
          ScriptContext(sourceEtc: manager.partyEtc.snapshot()),
          LoreScriptEngine(),
        ),
        isNull,
      );
    }
    LoreDialogueManager.instance.loadSaveFlags({});
  });

  test('direct map 19 owns no-op and active branches with or without JSON', () {
    for (final json in [false, true]) {
      final engine = LoreScriptEngine();
      if (json) {
        engine.loadFromJson(
          File('assets/data/scripts.json').readAsStringSync(),
        );
      }
      for (final cleared in [false, true]) {
        final result = LoreSpecialEventDispatcher.resolve(
          action: LoreTileAction.special,
          mapId: 19,
          x: 14,
          y: 10,
          context: ScriptContext(
            tileAtPlayer: 0,
            sourceEtc: {40: cleared ? 7 : 6},
          ),
          party: const [],
          scripts: engine,
          legacy: LoreDungeonEventManager.instance,
        );
        expect(result.legacy, isNull);
        expect(result.script == null, cleared);
      }
    }
  });

  test('explicit zero ignores stale legacy room and completion flags', () {
    final run = LoreSpecProcedures.map19(
      22,
      6,
      const ScriptContext(
        sourceEtc: {40: 0},
        flags: {'evilSealRoom3', 'evilSealRoomCleared', 'etc40_bit1'},
      ),
      LoreScriptEngine(),
    )!;
    expect(run.awaitingBattle, isFalse);
    expect(run.outcome.messages.single, contains('발견되지 않았다'));
  });
}

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dungeon_event_manager.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/game/lore_world_manager.dart';
import 'package:lore/logic/lore_battle_progress.dart';
import 'package:lore/logic/lore_ent_procedures.dart';
import 'package:lore/logic/lore_portal_session.dart';
import 'package:lore/logic/lore_spec_procedures.dart';
import 'package:lore/logic/lore_special_event_dispatcher.dart';
import 'package:lore/logic/lore_tile_protocol.dart';
import 'package:lore/logic/script_battle_session.dart';
import 'package:lore/logic/script_world_reducer.dart';
import 'package:lore/models/monster.dart';

class NoFinalRandom implements Random {
  @override
  int nextInt(int max) => throw StateError('Map 26 has no Random call');
  @override
  bool nextBool() => throw StateError('Unexpected Random');
  @override
  double nextDouble() => throw StateError('Unexpected Random');
}

/// LORESPEC.PAS:1997-2201 and LOREENT.PAS:323-364 source replay boundaries.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final source = jsonDecode(
    File('test/fixtures/map26_final_parity.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  ScriptRun intro(int x, {LoreScriptEngine? engine}) =>
      LoreSpecProcedures.map26(
        x,
        15,
        const ScriptContext(
          tileAtPlayer: 0,
          flags: {'bossNecromancerDefeated'},
        ),
        engine ?? LoreScriptEngine(random: NoFinalRandom()),
      )!;

  test(
    'source movement keeps three decrements, east loop and final face',
    () async {
      final map = await LoreMapData.loadFromAsset('K_DEN2', category: 'town');
      for (final raw in source['movements'] as List) {
        final item = raw as Map<String, dynamic>;
        final run = intro(item['start'][0] as int);
        final changed = ScriptWorldReducer.applyMap(
          ScriptMapState(
            mapId: 26,
            x: item['start'][0] as int,
            y: 15,
            direction: 0,
            grid: map.grid,
          ),
          run.outcome,
        );
        expect([changed.x, changed.y], item['end']);
        expect(changed.grid, map.grid);
        expect(run.outcome.nudges.take(3), [
          (dx: 0, dy: -1),
          (dx: 0, dy: -1),
          (dx: 0, dy: -1),
        ]);
        expect(
          run.outcome.events
              .where((e) => e.kind == 'sourceFace')
              .map((e) => e.face)
              .toList(),
          source['faces'],
        );
        expect(run.pendingScene!.lines, source['introLines']);
        expect(run.awaitingBattle, isFalse);
        final game = LoreGame(initialMapId: 26)..currentMapName = 'K_DEN2';
        for (final face in source['faces'] as List) {
          game.applySourceFace(face as int);
        }
        expect(game.playerDirection, 1);
        expect(game.playerSpriteIndex, 5);
        final battle = run.acknowledgeScene();
        expect(battle.outcome.battleMonsters, source['monsters']);
        expect(battle.outcome.battleEnemyFirst, source['enemyFirst']);
        expect(battle.outcome.since(run.outcome).nudges, isEmpty);
      }
    },
  );

  test('source byte results: defeat wins priority; slot 7 death admits farewell on escape', () {
    final battle = intro(25).acknowledgeScene();
    for (final raw in source['results'] as List) {
      final item = raw as Map<String, dynamic>;
      final roster = [for (var id = 69; id <= 75; id++) Monster.create(id)];
      if (item['keyDead'] == true) roster[6].isDead = true;
      final code = item['result'] as int;
      final session = ScriptBattleSession.resolve(
        before: const LoreBattleProgressState(
          gold: 100,
          lastBattleResult: 0,
          flags: {},
        ),
        end: code == 255
            ? LoreBattleEnd.defeat
            : code == 0
            ? LoreBattleEnd.victory
            : LoreBattleEnd.runAway,
        enemies: roster,
        pendingScript: battle,
      );
      expect(session.delta.nudges, isEmpty);
      expect(session.delta.tileOperations, isEmpty);
      expect(session.delta.setFlags, isEmpty);
      expect(session.delta.events.any((e) => e.kind == 'endDemo'), isFalse);
      switch (item['path']) {
        case 'exit':
          expect(session.continuation, isNull);
        case 'retry':
          final scene = session.continuation!;
          expect(scene.pendingScene!.lines, source['retryLines']);
          expect(scene.awaitingBattle, isFalse);
          final retry = scene.acknowledgeScene();
          final delta = retry.outcome.since(scene.outcome);
          expect(retry.awaitingBattle, isTrue);
          expect(delta.battleReuseExisting, isTrue);
          expect(delta.battleMonsters, source['monsters']);
          expect(delta.battleEnemyFirst, isTrue);
          expect(delta.nudges, isEmpty);
        case 'farewell':
          final scene = session.continuation!;
          expect(scene.pendingScene!.lines, source['farewellLines']);
          final finished = scene.acknowledgeScene();
          expect(
            finished.outcome.since(scene.outcome).events.single.kind,
            'endDemo',
          );
          expect(finished.hasPendingScene, isFalse);
          expect(finished.awaitingBattle, isFalse);
      }
    }
  });

  test('repeated escapes retain reuse through each acknowledgement without replaying movement', () {
    var battle = intro(24).acknowledgeScene();
    for (var turn = 0; turn < 4; turn++) {
      final retryScene = battle.continueAfterRunAway(
        defeatedEnemySlots: {1, 4},
      );
      expect(retryScene.pendingScene!.lines, source['retryLines']);
      final next = retryScene.acknowledgeScene();
      expect(next.outcome.since(battle.outcome).battleReuseExisting, isTrue);
      expect(next.outcome.since(battle.outcome).nudges, isEmpty);
      battle = next;
    }
    expect(
      battle.continueAfterRunAway(defeatedEnemySlots: {7}).pendingScene!.lines,
      source['farewellLines'],
    );
    expect(battle.continueAfterDefeat(), isNull);
  });

  test('direct owner ignores obsolete clear/once markers with or without JSON; no-op has no fallback', () {
    for (final json in [false, true]) {
      final engine = LoreScriptEngine(random: NoFinalRandom());
      if (json) {
        engine.loadFromJson(
          File('assets/data/scripts.json').readAsStringSync(),
        );
      }
      engine.consumedScripts.add('spec-26-L2104-seq');
      for (final tile in [0, 16]) {
        final result = LoreSpecialEventDispatcher.resolve(
          action: LoreTileAction.special,
          mapId: 26,
          x: 25,
          y: 15,
          context: ScriptContext(
            tileAtPlayer: tile,
            flags: {'bossNecromancerDefeated'},
          ),
          party: const [],
          scripts: engine,
          legacy: LoreDungeonEventManager.instance,
        );
        expect(result.legacy, isNull);
        expect(result.script?.hasPendingScene, tile == 0 ? true : null);
      }
    }
  });

  test('map25 entry overwrites all torch bytes; acknowledgement precedes fixed player-first battle', () {
    final portal = LoreEntProcedures.entranceAt(25, 25, 27)!;
    expect([
      portal.targetMapId,
      portal.targetX,
      portal.targetY,
    ], source['entryDestination']);
    for (var byte = 0; byte < 256; byte++) {
      final scene = LorePortalSession.begin(
        confirmed: true,
        portal: portal,
        context: ScriptContext(sourceEtc: {1: byte}),
        scripts: LoreScriptEngine(random: NoFinalRandom()),
      ).preScript!;
      expect(scene.outcome.sourceEtcWrites, [(index: 1, value: 1)]);
      expect(scene.pendingScene!.lines, [' 두말이 필요없다. 덤벼라 !!']);
      final battle = scene.acknowledgeScene();
      expect(battle.outcome.battleMonsters, source['entryMonsters']);
      expect(battle.outcome.battleEnemyFirst, source['entryEnemyFirst']);
      final escape = battle.continueAfterRunAway();
      expect([escape.outcome.teleportX, escape.outcome.teleportY], [25, 45]);
      expect(escape.outcome.blockMove, isTrue);
      expect(battle.continueAfterDefeat(), isNull);
      expect(battle.continueAfterBattle().outcome.blockMove, isFalse);
    }
  });

  test('map25 exit has one runtime owner and an exact y46 boundary', () async {
    final world = LoreWorldManager.instance;
    world.resetRulesForTest();
    addTearDown(world.resetRulesForTest);
    for (final json in [false, true]) {
      if (json) await world.loadData();
      final exit = world.findPortal(25, 26, 46)!;
      expect([
        exit.targetMapId,
        exit.targetX,
        exit.targetY,
      ], source['exitDestination']);
      expect(world.findPortal(25, 26, 47), isNull);
      final cancel = LorePortalSession.begin(
        confirmed: false,
        portal: exit,
        context: const ScriptContext(),
        scripts: LoreScriptEngine(),
      );
      expect(cancel.action, LorePortalAction.cancelled);
      expect(cancel.preScript, isNull);
      final accept = LorePortalSession.begin(
        confirmed: true,
        portal: exit,
        context: const ScriptContext(),
        scripts: LoreScriptEngine(),
      );
      expect(accept.action, LorePortalAction.loadMap);
    }
  });
}

import 'dart:math';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dungeon_event_manager.dart';
import 'package:lore/game/lore_world_manager.dart';
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
    bool mindReadActive = false,
    int maxEspLevel = 0,
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
        mindReadActive: mindReadActive,
        maxEspLevel: maxEspLevel,
      ),
      party: const [],
      scripts: scripts,
      legacy: LoreDungeonEventManager.instance,
    );
    expect(result.legacy, isNull);
    return result.script;
  }

  group('LORESPEC 맵 18 LOCKUP 분기 검증 (LORESPEC.PAS:1174-1365)', () {
    ScriptRun? at(
      int x,
      int y, {
      Map<int, int> etc = const {},
      int esp = 0,
      int tile = 52,
      LoreScriptEngine? engine,
    }) => LoreSpecProcedures.map18(
      x,
      y,
      ScriptContext(
        tileAtPlayer: tile,
        maxEspLevel: esp,
        sourceEtc: {39: 0, 5: 0, 15: 0, 1: 1, ...etc},
      ),
      engine ?? scripts,
    );
    ScriptRun drain(ScriptRun run) {
      while (run.hasPendingScene) {
        run = run.acknowledgeScene();
      }
      return run;
    }

    test('y = 95 is the wantexit boundary; ordinary cells do nothing', () {
      expect(at(24, 95, tile: 0), isNull);
      expect(at(1, 1), isNull);
      expect(at(37, 31, tile: 44), isNull);
    });

    test(
      'the wantexit boundary is exactly y = 95 (map 3 (96,43), refusal y - 1)',
      () {
        final portal = LoreWorldManager.instance.findPortal(18, 24, 95)!;
        expect(
          [portal.targetMapId, portal.targetX, portal.targetY],
          [3, 96, 43],
        );
        expect(LoreWorldManager.instance.findPortal(18, 24, 96), isNull);
        expect(LoreWorldManager.instance.findPortal(18, 24, 94), isNull);
        expect(LoreWorldManager.sourceExitRejectY(18, 95), 94);
      },
    );

    test('(22,41) opens the passage: 22,41 := 44 and 21,41 := 52', () {
      final run = at(22, 41)!;
      expect(run.outcome.tileChanges.map((t) => [t.x, t.y, t.tile]).toList(), [
        [22, 41, 44],
        [21, 41, 52],
      ]);
    });

    test('(21,41) Minotaur runs while raw etc[39] bit3 is clear and sets it after victory or escape', () {
      for (var b = 0; b < 256; b++) {
        expect(at(21, 41, etc: {39: b}) == null, (b & 4) != 0);
      }
      final lit = at(21, 41, etc: {1: 0})!;
      expect(lit.outcome.sourceEtcWrites.single.value, 1);
      final battle = drain(lit);
      expect(battle.outcome.battleMonsters, [53]);
      expect(battle.outcome.battleEnemyFirst, isTrue);
      expect(battle.continueAfterBattle().outcome.setFlags, ['etc39_bit3']);
      expect(battle.continueAfterRunAway().outcome.setFlags, ['etc39_bit3']);
    });

    test('Spica lecture sets bit1 only after the four pages', () {
      var run = at(37, 31)!;
      final pages = <List<String>>[];
      while (run.hasPendingScene) {
        pages.add(run.pendingScene!.lines);
        run = run.acknowledgeScene();
      }
      expect(pages.length, 4);
      expect(pages[0], ['여기에는 어떤 여자가 수도하고 있었다']);
      expect(pages[2].first, '');
      expect(pages[2][1], '투  시 : 변화의 여지가 있는 지역을 탐지');
      expect(pages[3].last, '줄 안다는걸 염두에 두고 사용하십시오.');
      expect(run.outcome.setFlags, ['etc39_bit1']);
    });

    test('Spica after the lecture: raw etc[5], best espLevel and bit2', () {
      final noMind = at(37, 31, etc: {39: 1, 5: 0}, esp: 9)!;
      expect(noMind.outcome.messages, [' 지체할 시간이 없습니다. 신속히 행동을 취하', '십시오.']);
      expect(noMind.pendingScene!.lines, ['십시오.']);
      final weak = at(37, 31, etc: {39: 1, 5: 2}, esp: 4)!;
      expect(weak.outcome.messages.length, 3);
      expect(weak.pendingScene!.lines, ['다.']);
      final offer = at(37, 31, etc: {39: 1, 5: 2}, esp: 5)!;
      expect(offer.outcome.messages.last, '겠습니다.');
      expect(offer.choiceTexts, ['저도 원했던 바입니다', '말씀은 고맙지만 사양하겠습니다']);
      // bit2 is written before ReturnJoinMember for either answer.
      expect(offer.choose(0).outcome.setFlags, ['etc39_bit2']);
      expect(offer.choose(0).outcome.recruits.single.key, 'spica');
      expect(offer.choose(1).outcome.setFlags, ['etc39_bit2']);
      expect(offer.choose(1).outcome.recruits, isEmpty);
      expect(offer.choose(1).outcome.messages.length, 3);
      for (final b in [3, 7, 255]) {
        expect(
          at(37, 31, etc: {39: b, 5: 2}, esp: 9),
          b & 2 != 0 ? isNull : isNotNull,
        );
      }
    });

    test('x = 31 Huge Dragon on raw etc[15] < 4: walk, random(3)+30 slots, victory, escape', () {
      for (var b = 0; b < 256; b++) {
        expect(at(31, 10, etc: {15: b}) == null, b >= 4);
      }
      final first = at(31, 10, engine: LoreScriptEngine(random: Random(7)))!;
      final run = drain(first);
      expect(run.outcome.nudges.where((n) => n.dx == 1).length, 6);
      expect(run.outcome.nudges.where((n) => n.dy == 1).length, 3);
      expect(run.outcome.battleEnemyFirst, isTrue);
      final monsters = run.outcome.battleMonsters;
      expect(monsters.length, 7);
      expect(monsters.take(2), [54, 39]);
      expect(monsters.skip(2).every((m) => m >= 30 && m <= 32), isTrue);
      // random(3) calls come in slot order from the engine generator.
      final again = LoreScriptEngine(random: Random(7));
      expect(monsters.skip(2), [
        for (var i = 0; i < 5; i++) again.roll(3) + 30,
      ]);
      expect(run.outcome.battleOverrides, [
        {'index': 1, 'name': 'Huge Dragon'},
        {'index': 2, 'name': "Dragon's tail", 'ac': 8},
      ]);
      final won = drain(run.continueAfterBattle());
      expect(won.outcome.questChanges.single.name, 'water');
      expect(won.outcome.questChanges.single.set, 4);
      final fled = run.continueAfterRunAway();
      expect([fled.outcome.teleportX, fled.outcome.teleportY], [25, 94]);
      expect(fled.outcome.questChanges, isEmpty);
      // y = 13 needs no southward walk.
      expect(
        drain(at(31, 13, engine: LoreScriptEngine(random: Random(7)))!)
            .outcome
            .nudges
            .where((n) => n.dy == 1),
        isEmpty,
      );
    });

    test('Huge Dragon lights the torch first, faces 6, 4, 5, and stops on a defeat; the Minotaur escape path runs after a reload', () {
      final run = at(
        31,
        10,
        etc: {1: 0},
        engine: LoreScriptEngine(random: Random(3)),
      )!;
      expect(run.outcome.sourceEtcWrites.single, (index: 1, value: 1));
      expect(run.outcome.torchLit, isTrue);
      final done = drain(run);
      expect(done.continueAfterDefeat(), isNull);
      expect(done.outcome.questChanges, isEmpty);
      final minotaur = drain(at(21, 41)!);
      expect(minotaur.continueAfterDefeat()!.outcome.setFlags, ['etc39_bit3']);
      expect(minotaur.resumesAfterReload, isTrue);
    });

    test('dispatcher owns map 18 without JSON fallback', () {
      final bare = LoreScriptEngine();
      expect(bare.usingJson, isFalse);
      final run = LoreSpecialEventDispatcher.resolve(
        action: LoreTileAction.special,
        mapId: 18,
        x: 22,
        y: 41,
        context: const ScriptContext(tileAtPlayer: 52),
        party: const [],
        scripts: bare,
        legacy: LoreDungeonEventManager.instance,
      );
      expect(run.script!.outcome.tileChanges.length, 2);
      final direct = dispatchSpecial(mapId: 18, x: 22, y: 41, tile: 52)!;
      expect(direct.outcome.tileChanges.length, 2);
      expect(dispatchSpecial(mapId: 18, x: 1, y: 1), isNull);
    });
  });
}

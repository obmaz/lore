import 'dart:io';

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
    bool mindReadActive = false,
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
      ),
      party: const [],
      scripts: scripts,
      legacy: LoreDungeonEventManager.instance,
    );
    expect(result.legacy, isNull);
    return result.script;
  }

  group('LORESPEC 맵 17 DEN3 / DRAGON DEN 분기 검증 (LORESPEC.PAS:1006-1173)', () {
    ScriptRun? at(int x, int y, {Map<int, int> etc = const {}}) =>
        LoreSpecProcedures.map17(
          x,
          y,
          ScriptContext(
            tileAtPlayer: 0,
            sourceEtc: {38: 0, 5: 0, 15: 0, 1: 1, ...etc},
          ),
          LoreScriptEngine(),
        );
    ScriptRun drain(ScriptRun run) {
      while (run.hasPendingScene) {
        run = run.acknowledgeScene();
      }
      return run;
    }

    test(
      'Red Antares on raw etc[38]/etc[5]; the dead bit2 exit keeps the offer',
      () {
        final teach = at(75, 52)!;
        expect(teach.outcome.tileOperations.single.tileOnlyIf, 40);
        expect(
          teach.pendingScene!.lines.single,
          '갑자기 주위가 용암으로 변하면서 한 영혼이 당신앞에 나타났다.',
        );
        expect(
          drain(teach).outcome.setFlags,
          containsAll(['etc38_bit1', 'specialMagicLearned']),
        );
        final farewell = at(75, 52, etc: {38: 1})!;
        expect(farewell.pendingScene!.lines, ['나는 다시 영혼의 세계로 돌아가야 겠소.']);
        expect(at(75, 52, etc: {38: 3}), isNull);
        for (final b in [1, 3]) {
          final offer = at(75, 52, etc: {38: b, 5: 4})!;
          expect(offer.choiceTexts, ['당신의 제의을 받아 들이겠소', '당신이 전해준 마법만으로도 족하오']);
          expect(offer.outcome.messages, isEmpty);
          expect(offer.choose(0).outcome.recruits.single.key, 'red_antares');
          expect(offer.choose(0).outcome.setFlags, contains('etc38_bit2'));
          expect(offer.choose(1).outcome.setFlags, isEmpty);
          expect(offer.choose(1).outcome.messages, ['당신이 바란다면 ...']);
        }
      },
    );

    test('Hidra while raw etc[15] < 2: heads, party first, victory sets 2 and returns, escape x+1', () {
      for (var b = 0; b < 256; b++) {
        expect(at(22, 30, etc: {15: b}) == null, b >= 2);
      }
      final run = at(22, 30, etc: {1: 0})!;
      expect(run.outcome.sourceEtcWrites.single.value, 1);
      final battle = run.acknowledgeScene();
      expect(battle.outcome.battleMonsters, [49, 49, 49]);
      expect(battle.outcome.battleEnemyFirst, isFalse);
      expect(battle.outcome.battleOverrides[1], {
        'index': 2,
        'name': "Hidra's Head 2",
        'level': 10,
        'eNumber': 39,
      });
      final won = drain(battle.continueAfterBattle());
      expect(won.outcome.questChanges.single.set, 2);
      expect([won.outcome.teleportX, won.outcome.teleportY], [56, 93]);
      final fled = battle.continueAfterRunAway();
      expect([fled.outcome.teleportX, fled.outcome.teleportY], [23, 30]);
    });

    test(
      'sequential ifs use the moved position: x=72 then y=38 in the same step',
      () {
        final wrap = at(30, 80)!;
        expect([wrap.outcome.teleportX, wrap.outcome.teleportY], [30, 6]);
        final open = at(68, 44)!;
        expect(open.outcome.tileChanges.length, 6);
        final chained = at(72, 45)!;
        expect(
          chained.outcome.tileChanges.map((t) => [t.x, t.y, t.tile]).take(3),
          [
            [72, 19, 44],
            [72, 20, 44],
            [72, 21, 44],
          ],
        );
        // y - 7 = 38 triggers the y = 38 swap and the move to (56,93).
        expect(
          [chained.outcome.teleportX, chained.outcome.teleportY],
          [56, 93],
        );
        expect(chained.outcome.tileChanges.length, 9);
        expect(at(30, 95), isNull);
      },
    );

    test('특수 사건 위치가 아닌 곳은 null을 반환한다', () {
      final normal = dispatchSpecial(mapId: 17, x: 1, y: 1);
      expect(normal, isNull);
    });
  });
}

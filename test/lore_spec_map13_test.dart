import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dungeon_event_manager.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/logic/script_world_reducer.dart';
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
    int tile = 52,
    Set<String> flags = const {},
  }) {
    final result = LoreSpecialEventDispatcher.resolve(
      action: LoreTileAction.special,
      mapId: mapId,
      x: x,
      y: y,
      context: ScriptContext(tileAtPlayer: tile, flags: flags),
      party: const [],
      scripts: scripts,
      legacy: LoreDungeonEventManager.instance,
    );
    expect(result.legacy, isNull);
    return result.script;
  }

  group('LORESPEC 맵 13 SWAMP FIELD 분기 검증 (LORESPEC.PAS:669-813)', () {
    test('pyramid on the real DEN4 map: tile rules, one-cell walk to (81,77), pages', () async {
      final map = await LoreMapData.loadFromAsset('DEN4', category: 'den');
      final cells = [
        for (var y = 71; y <= 81; y++)
          for (var x = 76; x <= 86; x++)
            if (map.getTile(x, y) == 52 || map.getTile(x, y) == 0) (x, y),
      ];
      expect(cells, isNotEmpty);
      for (final (sx, sy) in cells) {
        final run = LoreSpecProcedures.map13(
          sx,
          sy,
          ScriptContext(tileAtPlayer: map.getTile(sx, sy)),
          scripts,
        )!;
        final moves = run.outcome.nudges;
        expect(moves.where((m) => m.dy != 0).every((m) => m.dx == 0), isTrue);
        expect(sx + moves.fold<int>(0, (a, m) => a + m.dx), 81);
        expect(sy + moves.fold<int>(0, (a, m) => a + m.dy), 77);
        expect(moves.every((m) => (m.dx.abs() + m.dy.abs()) == 1), isTrue);
        var current = run;
        var pages = 0;
        while (current.hasPendingScene) {
          pages++;
          current = current.acknowledgeScene();
        }
        expect(pages, 7);
        final after = ScriptWorldReducer.applyMap(
          ScriptMapState(mapId: 13, x: sx, y: sy, direction: 1, grid: map.grid),
          current.outcome,
        );
        expect([after.x, after.y], [81, 77]);
        for (var y = 71; y <= 81; y++) {
          for (var x = 76; x <= 86; x++) {
            final before = map.getTile(x, y);
            final want = x == 81 && y == 76
                ? 48
                : before == 52
                ? 44
                : (before == 40 || before == 51 || before == 42)
                ? 51
                : before;
            expect(after.grid[y - 1][x - 1], want, reason: '($x,$y)');
          }
        }
        expect(current.outcome.setFlags, isEmpty);
      }
    });

    test('Gorgon: raw etc[38] bit5, victory-only flag, escape y+1 only while enemy 3 lives', () {
      for (var b = 0; b < 256; b++) {
        final run = LoreSpecProcedures.map13(
          10,
          68,
          ScriptContext(tileAtPlayer: 0, sourceEtc: {38: b}),
          scripts,
        );
        expect(run == null, b & 16 != 0);
      }
      final run = LoreSpecProcedures.map13(
        10,
        68,
        const ScriptContext(tileAtPlayer: 0, sourceEtc: {38: 0}),
        scripts,
      )!;
      final battle = run.acknowledgeScene();
      expect(battle.outcome.battleMonsters, [50, 51, 52]);
      expect(battle.outcome.battleEnemyFirst, isTrue);
      final won = battle.continueAfterBattle();
      expect(won.pendingScene!.lines, ['당신들은 Gorgon을 물리쳤다.']);
      expect(won.acknowledgeScene().outcome.setFlags, ['etc38_bit5']);
      expect(battle.continueAfterRunAway().outcome.nudges.single.dy, 1);
      final killed = battle.continueAfterRunAway(defeatedEnemySlots: {3});
      expect(killed.outcome.nudges, isEmpty);
      expect(killed.outcome.setFlags, isEmpty);
      expect(
        LoreSpecProcedures.map13(
          10,
          96,
          const ScriptContext(tileAtPlayer: 0),
          scripts,
        ),
        isNull,
      );
    });

    test('특수 사건 좌표가 아닌 곳은 null을 반환한다', () {
      expect(dispatchSpecial(mapId: 13, x: 10, y: 10, tile: 52), isNull);
    });
  });
}

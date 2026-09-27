import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/game/lore_world_manager.dart';
import 'package:lore/logic/lore_tile_protocol.dart';
import 'package:lore/logic/script_world_reducer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('활성 발걸음 규칙은 실제 지도의 특수 타일에서 호출 가능하다', () async {
    final engine = LoreScriptEngine()
      ..loadFromJson(File('assets/data/scripts.json').readAsStringSync());
    final world = LoreWorldManager.instance;
    world.resetRulesForTest();
    await world.loadData();
    final maps = <int, LoreMapData>{};
    for (final entry in LoreWorldManager.mapRegistry.entries) {
      maps[entry.key] = await LoreMapData.loadFromAsset(
        entry.value.fileName,
        category: entry.value.category.name,
      );
    }
    final variants = <int, List<LoreMapData>>{
      for (final entry in maps.entries) entry.key: [entry.value],
    };

    void addVariant(int mapId, ScriptOutcome outcome, int x, int y) {
      final original = maps[mapId]!;
      final changed = ScriptWorldReducer.applyMap(
        ScriptMapState(
          mapId: mapId,
          x: x,
          y: y,
          direction: 0,
          grid: original.grid,
        ),
        outcome,
      );
      variants[mapId]!.add(
        LoreMapData(
          name: original.name,
          category: original.category,
          xmax: original.xmax,
          ymax: original.ymax,
          grid: changed.grid,
        ),
      );
    }

    addVariant(
      6,
      engine.startTalk(6, 63, 76, const ScriptContext())!.outcome,
      63,
      77,
    );
    expect(variants[6]!.last.getTile(62, 82), 0);
    addVariant(
      19,
      engine
          .startStep(19, 11, 40, const ScriptContext(tileAtPlayer: 0))!
          .outcome,
      11,
      40,
    );
    expect(variants[19]!.last.getTile(41, 39), 0);
    addVariant(
      17,
      engine.startStep(17, 68, 44, const ScriptContext())!.outcome,
      68,
      44,
    );
    expect(variants[17]!.last.getTile(68, 38), 52);
    addVariant(
      18,
      engine
          .startStep(18, 22, 41, const ScriptContext(tileAtPlayer: 52))!
          .outcome,
      22,
      41,
    );
    expect(variants[18]!.last.getTile(21, 41), 52);
    for (final (sourceY, targetY) in [(91, 88), (75, 71)]) {
      final quiz = engine.startStep(20, 25, sourceY, const ScriptContext())!;
      addVariant(20, quiz.outcome, 25, sourceY);
      final opened = variants[20]!.last;
      expect(
        {opened.getTile(8, targetY), opened.getTile(43, targetY)},
        {0, 52},
      );
    }
    // LOREENT.sign: KEEP3 표지판을 읽으면 레버 타일을 52로 바꾼다.
    final keep = maps[23]!;
    final signOpened = [for (final row in keep.grid) List<int>.from(row)];
    signOpened[27 - 1][25 - 1] = 52;
    variants[23]!.add(
      LoreMapData(
        name: keep.name,
        category: keep.category,
        xmax: keep.xmax,
        ymax: keep.ymax,
        grid: signOpened,
      ),
    );

    final missing = <String>[];
    for (final script in engine.scripts.where(
      (script) => script.trigger == 'step' && !script.disabled,
    )) {
      var hasTarget = false;
      for (final map in variants[script.map]!) {
        for (var y = 5; y < map.ymax - 3 && !hasTarget; y++) {
          for (var x = 5; x < map.xmax - 3; x++) {
            if (!script.matches('step', script.map, x, y)) continue;
            final action = map.actionForTile(map.getTile(x, y));
            if (action != LoreTileAction.special) continue;
            if (world.findPortal(script.map, x, y) != null) {
              continue;
            }
            hasTarget = true;
            break;
          }
        }
        if (hasTarget) break;
      }
      if (!hasTarget) missing.add(script.id);
    }
    expect(missing, isEmpty);
    world.resetRulesForTest();
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/game/lore_world_manager.dart';
import 'package:lore/logic/lore_tile_protocol.dart';
import 'package:lore/logic/script_world_reducer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('활성 발걸음 규칙은 실제 지도의 이동 타일에서 호출 가능하다', () async {
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
    final castle = maps[6]!;
    final antares = engine.startTalk(6, 63, 76, const ScriptContext())!;
    final opened = ScriptWorldReducer.applyMap(
      ScriptMapState(mapId: 6, x: 63, y: 77, direction: 0, grid: castle.grid),
      antares.outcome,
    );
    final openedCastle = LoreMapData(
      name: castle.name,
      category: castle.category,
      xmax: castle.xmax,
      ymax: castle.ymax,
      grid: opened.grid,
    );
    expect(openedCastle.getTile(62, 82), 0);

    final missing = <String>[];
    for (final script in engine.scripts.where(
      (script) => script.trigger == 'step' && !script.disabled,
    )) {
      var hasTarget = false;
      for (final map in [
        maps[script.map]!,
        if (script.map == 6) openedCastle,
      ]) {
        for (var y = 5; y < map.ymax - 3 && !hasTarget; y++) {
          for (var x = 5; x < map.xmax - 3; x++) {
            if (!script.matches('step', script.map, x, y)) continue;
            final action = map.actionForTile(map.getTile(x, y));
            if (!action.entersTargetBeforeAction) continue;
            if (action == LoreTileAction.special &&
                world.findPortal(script.map, x, y) != null) {
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

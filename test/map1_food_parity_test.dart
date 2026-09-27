import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dungeon_event_manager.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/logic/lore_special_event_dispatcher.dart';
import 'package:lore/logic/lore_tile_protocol.dart';
import 'package:lore/logic/script_world_reducer.dart';

/// LORESPEC.PAS GROUND1의 식량 상자 계산과 후퇴 방향을 재생한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('맵 1 식량 상자는 최초 한 번 255 상한으로 지급하고 뒤로 물러난다', () async {
    final fixture = jsonDecode(
      File('test/fixtures/map1_food_parity.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final map = await LoreMapData.loadFromAsset('GROUND1', category: 'ground');
    final engine = LoreScriptEngine();
    engine.loadFromJson(await rootBundle.loadString('assets/data/scripts.json'));
    for (final raw in fixture['cases'] as List<dynamic>) {
      final item = raw as Map<String, dynamic>;
      final x = item['x'] as int;
      final y = item['y'] as int;
      final visited = item['visited'] as bool;
      final flag = item['flag'] as String;
      final selected = LoreSpecialEventDispatcher.resolve(
        action: LoreTileAction.special,
        mapId: 1,
        x: x,
        y: y,
        context: ScriptContext(
          tileAtPlayer: 0,
          flags: {if (visited) flag},
        ),
        party: const [],
        scripts: engine,
        legacy: LoreDungeonEventManager.instance,
      );
      final run = selected.script;
      expect(run, isNotNull, reason: 'LORESPEC.PAS:${fixture['line']}');
      expect(run!.script.id, 'lorespec-map1-food');
      expect(selected.legacy, isNull);
      final result = ScriptWorldReducer.applyMap(
        ScriptMapState(
          mapId: 1,
          x: x,
          y: y,
          direction: item['direction'] as int,
          grid: map.grid,
        ),
        run.outcome,
      );
      expect([result.x, result.y], item['end']);
      final resources = ScriptWorldReducer.applyResources(
        ScriptResources(gold: 0, food: item['food'] as int),
        run.outcome,
      );
      expect(resources.food, item['expectedFood']);
      expect(run.outcome.setFlags.contains(flag), !visited);
    }
  });
}

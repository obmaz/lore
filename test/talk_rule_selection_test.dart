import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/game/lore_world_manager.dart';
import 'package:lore/logic/lore_tile_protocol.dart';
import 'package:lore/logic/lore_talk_dispatcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('모든 활성 대화 규칙은 자신의 조건에서 실제로 선택된다', () async {
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

    for (final script in engine.scripts.where(
      (script) => script.trigger == 'talk' && !script.disabled,
    )) {
      final require = script.require;
      final flags = <String>{?require.flag, ...require.allFlags};
      final quests = <String, int>{};
      for (final quest in require.quests) {
        quests[quest.name] = quest.eq ?? quest.gte ?? 0;
      }
      final context = ScriptContext(
        flags: flags,
        partyNames: {?require.partyMember},
        enteredFromMap: require.enteredFromMap,
        mindReadActive: require.mindRead,
        maxEspLevel: require.minEspLevel ?? 0,
        tileAtPlayer: require.tileAtPlayerZero ? 0 : require.tileAtPlayerValue,
        moveDy: require.moveDyNot == 0 ? 1 : 0,
        questSteps: quests,
      );
      final map = maps[script.map]!;
      var selected = false;
      for (var y = 5; y < map.ymax - 3 && !selected; y++) {
        for (var x = 5; x < map.xmax - 3; x++) {
          if (!script.matches('talk', script.map, x, y) ||
              map.actionForTile(map.getTile(x, y)) != LoreTileAction.talk) {
            continue;
          }
          final dispatch = LoreTalkDispatcher.resolve(
            mapId: script.map,
            x: x,
            y: y,
            context: context,
            world: world,
            scripts: engine,
          );
          if (dispatch.source == LoreTalkSource.script &&
              dispatch.script?.script.id == script.id) {
            selected = true;
            break;
          }
        }
      }
      expect(selected, isTrue, reason: script.id);
    }
    world.resetRulesForTest();
  });
}

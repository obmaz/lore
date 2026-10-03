import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/game/lore_world_manager.dart';
import 'package:lore/logic/lore_tile_protocol.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('활성 대화·시설·기본 대사 좌표는 실제 27개 지도에서 대화 타일이다', () async {
    final maps = <int, LoreMapData>{};
    for (final entry in LoreWorldManager.mapRegistry.entries) {
      maps[entry.key] = await LoreMapData.loadFromAsset(
        entry.value.fileName,
        category: entry.value.category.name,
      );
    }

    bool isTalkTile(int mapId, int x, int y) {
      final map = maps[mapId]!;
      return x > 4 &&
          x < map.xmax - 3 &&
          y > 4 &&
          y < map.ymax - 3 &&
          map.actionForTile(map.getTile(x, y)) == LoreTileAction.talk;
    }

    final scripts = LoreScriptEngine()
      ..loadFromJson(File('assets/data/scripts.json').readAsStringSync());
    for (final script in scripts.scripts.where(
      (item) => item.trigger == 'talk' && !item.disabled,
    )) {
      final map = maps[script.map]!;
      var reachable = false;
      for (var y = 5; y < map.ymax - 3 && !reachable; y++) {
        for (var x = 5; x < map.xmax - 3; x++) {
          if (script.matches('talk', script.map, x, y) &&
              isTalkTile(script.map, x, y)) {
            reachable = true;
            break;
          }
        }
      }
      expect(reachable, isTrue, reason: script.id);
    }

    for (final source in ['facilities']) {
      final json = jsonDecode(
        File('assets/data/$source.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      for (final raw in json[source] as List<dynamic>) {
        final rule = raw as Map<String, dynamic>;
        expect(
          isTalkTile(rule['map'] as int, rule['x'] as int, rule['y'] as int),
          isTrue,
          reason: '$source ${rule['map']} (${rule['x']},${rule['y']})',
        );
      }
    }
  });
}

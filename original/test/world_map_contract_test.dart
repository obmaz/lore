import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/game/lore_world_manager.dart';
import 'package:lore/logic/lore_tile_protocol.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('27개 원본 지도에서 정적 진입 타일은 포털 또는 원본 무동작 좌표다', () async {
    final world = LoreWorldManager.instance;
    world.resetRulesForTest();
    await world.loadData();

    final noOperation = <(int, int, int)>{
      (2, 80, 47),
      (2, 84, 47),
      (2, 81, 49),
      (2, 83, 49),
      (4, 26, 15),
      (4, 25, 16),
      (4, 27, 16),
      (17, 80, 67),
      (17, 81, 67),
      (17, 82, 67),
      (26, 28, 43),
    };
    final actualNoOperation = <(int, int, int)>{};
    final maps = <int, LoreMapData>{};
    final destinations = <(int, int, int)>{};
    var activeEntrances = 0;
    for (final entry in LoreWorldManager.mapRegistry.entries) {
      final map = await LoreMapData.loadFromAsset(
        entry.value.fileName,
        category: entry.value.category.name,
      );
      maps[entry.key] = map;
      for (var y = 5; y < map.ymax - 3; y++) {
        for (var x = 5; x < map.xmax - 3; x++) {
          if (map.actionForTile(map.getTile(x, y)) != LoreTileAction.enter) {
            continue;
          }
          final portal = world.findPortal(entry.key, x, y);
          if (portal == null) {
            actualNoOperation.add((entry.key, x, y));
          } else {
            activeEntrances++;
            destinations.add((
              portal.targetMapId,
              portal.targetX,
              portal.targetY,
            ));
            expect(
              LoreWorldManager.mapRegistry.containsKey(portal.targetMapId),
              isTrue,
              reason: '${entry.key} ($x,$y)',
            );
          }
        }
      }
    }
    expect(maps.length, 27);
    expect(activeEntrances, greaterThan(0));
    expect(actualNoOperation, noOperation);
    for (final (mapId, x, y) in destinations) {
      final target = maps[mapId]!;
      expect(
        x >= 1 && x <= target.xmax && y >= 1 && y <= target.ymax,
        isTrue,
        reason: 'destination $mapId ($x,$y)',
      );
    }
    world.resetRulesForTest();
  });
}

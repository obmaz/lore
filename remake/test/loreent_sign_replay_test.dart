import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/game/lore_world_manager.dart';
import 'package:lore/logic/lore_tile_protocol.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every static sign tile in LOREENT sign maps has live text', () async {
    final world = LoreWorldManager.instance;
    world.resetRulesForTest();
    await world.loadData();
    var checked = 0;
    for (final mapId in [2, 6, 7, 8, 9, 12, 15, 17, 19]) {
      final info = LoreWorldManager.mapRegistry[mapId]!;
      final map = await LoreMapData.loadFromAsset(
        info.fileName,
        category: info.category.name,
      );
      for (var y = 1; y <= map.ymax; y++) {
        for (var x = 1; x <= map.xmax; x++) {
          if (map.actionForTile(map.getTile(x, y)) != LoreTileAction.sign) {
            continue;
          }
          expect(
            world.getSignMessage(mapId, x, y),
            isNotNull,
            reason: 'LOREENT.sign map $mapId at ($x,$y)',
          );
          checked++;
        }
      }
    }
    expect(checked, 41);
    expect(world.getSignMessage(12, 27, 56), contains("'15'"));
    expect(world.getSignMessage(12, 28, 29), contains("'7'"));
    world.resetRulesForTest();
  });
}

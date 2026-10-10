import '../game/lore_map_manager.dart';
import '../game/lore_world_manager.dart';

/// Visual-only environment selection. Never writes tiles or consumes random.
enum BattleBackdrop {
  meadow('초원', 0),
  forest('숲', 1),
  coast('물가', 2),
  marsh('늪지', 3),
  volcanic('용암 지대', 4),
  cavern('동굴', 5),
  castle('성채', 6),
  village('마을', 7),
  sand('모래지대', 2);

  const BattleBackdrop(this.label, this.cell);
  final String label;
  final int cell;

  static BattleBackdrop forLocation({
    required int mapId,
    LoreMapData? map,
    int x = 1,
    int y = 1,
  }) {
    final category = LoreWorldManager.mapRegistry[mapId]?.category;
    // These source-town maps are visually underground chambers, not villages.
    if (mapId == 24 || mapId == 26) return cavern;
    if (category == MapCategory.den) return cavern;
    if (category == MapCategory.keep || mapId == 6 || mapId == 27) {
      return castle;
    }
    if (mapId == 10 || mapId == 3) return coast;
    if (category == MapCategory.town) return village;
    if (mapId == 4) return marsh;
    if (mapId == 5) return volcanic;
    if (map == null) return meadow;
    final tile = map.getTile(x, y);
    switch (map.getCategory(tile)) {
      case TileCategory.water:
        return coast;
      case TileCategory.swamp:
        return marsh;
      case TileCategory.lava:
        return volcanic;
      default:
        break;
    }
    // GROUND 31..39 use the sand floor in the existing presentation atlas.
    if (category == MapCategory.ground && tile >= 31 && tile <= 39) {
      return sand;
    }
    // GROUND 2/3 are the tree silhouettes in the current map presentation.
    if (category == MapCategory.ground) {
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final tx = x + dx, ty = y + dy;
          if (tx < 1 || ty < 1 || tx > map.xmax || ty > map.ymax) continue;
          final nearby = map.getTile(tx, ty);
          if (nearby == 2 || nearby == 3) return forest;
        }
      }
    }
    return meadow;
  }
}

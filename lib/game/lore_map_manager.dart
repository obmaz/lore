import 'package:flutter/services.dart';

enum TileCategory {
  special, // 0: 특수 이벤트
  wall, // 1..21: 성벽/바위/건물 (통과 불가)
  portal, // 22: 다른 맵 진입 (마을<->필드 성문)
  sign, // 23: 표지판
  water, // 24: 물
  swamp, // 25: 늪지 (중독)
  lava, // 26: 용암
  walkable, // 27..47: 일반 이동 가능 바닥/길
  npc, // 48+: NPC / 주민
}

/// 1993년 원작 LORE 바이너리 맵(.MAP) 데이터 및 로더
class LoreMapData {
  final String name;
  final int xmax;
  final int ymax;
  final List<List<int>> grid; // [y][x] 0-based

  const LoreMapData({
    required this.name,
    required this.xmax,
    required this.ymax,
    required this.grid,
  });

  int getTile(int x, int y) {
    if (x < 1 || x > xmax || y < 1 || y > ymax) return 1; // 맵 밖은 벽
    return grid[y - 1][x - 1];
  }

  bool get isTown =>
      name.startsWith('TOWN') || name.startsWith('KEEP') || name == 'TEST';

  TileCategory getCategory(int tileValue) {
    if (tileValue == 0) return TileCategory.special;
    if (tileValue >= 1 && tileValue <= 21) return TileCategory.wall;

    if (isTown) {
      if (tileValue == 22) return TileCategory.portal;
      if (tileValue == 23) return TileCategory.sign;
      if (tileValue == 24) return TileCategory.water;
      if (tileValue == 25) return TileCategory.swamp;
      if (tileValue == 26) return TileCategory.lava;
      if (tileValue >= 27 && tileValue <= 47) return TileCategory.walkable;
      return TileCategory.npc; // 48+ 마을 주민/NPC
    } else {
      if (tileValue == 48) return TileCategory.water;
      if (tileValue == 23 || tileValue == 49) return TileCategory.swamp;
      if (tileValue == 50) return TileCategory.lava;
      if (tileValue >= 24 && tileValue <= 47) return TileCategory.walkable;
      if (tileValue == 22) return TileCategory.sign;
      return TileCategory.portal; // 진입 게이트
    }
  }

  bool isPassable(int x, int y) {
    final tile = getTile(x, y);
    final cat = getCategory(tile);
    // 벽과 NPC는 겹쳐서 이동 불가
    if (cat == TileCategory.wall || cat == TileCategory.npc) return false;
    return true;
  }

  /// `assets/maps/<filename>.MAP` 에서 바이너리 로드
  static Future<LoreMapData> loadFromAsset(String mapName) async {
    final assetPath = 'assets/maps/$mapName.MAP';
    final byteData = await rootBundle.load(assetPath);
    final bytes = byteData.buffer.asUint8List();

    final xmax = bytes[0];
    final ymax = bytes[1];

    final grid = List.generate(ymax, (y) {
      return List.generate(xmax, (x) {
        final offset = 2 + (y * xmax) + x;
        return offset < bytes.length ? bytes[offset] : 1;
      });
    });

    return LoreMapData(name: mapName, xmax: xmax, ymax: ymax, grid: grid);
  }
}

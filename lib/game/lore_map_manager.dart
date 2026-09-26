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

  /// 원작 `LORESUB.PAS:1723` 의 `position`(ground/town/den/keep).
  ///
  /// 같은 맵 파일이라도 이 값에 따라 타일 해석이 달라진다(예: `K_DEN2` 는
  /// 맵 25 에서는 던전(`del`), 맵 26 에서는 마을로 동작한다).
  final String category;
  final int xmax;
  final int ymax;
  final List<List<int>> grid; // [y][x] 0-based

  const LoreMapData({
    required this.name,
    required this.xmax,
    required this.ymax,
    required this.grid,
    this.category = '',
  });

  int getTile(int x, int y) {
    if (x < 1 || x > xmax || y < 1 || y > ymax) return 1; // 맵 밖은 벽
    return grid[y - 1][x - 1];
  }

  bool get isTown =>
      name.startsWith('TOWN') || name.startsWith('KEEP') || name == 'TEST';

  /// 원작 `LOREMAIN.PAS:195` 의 타일 판정을 그대로 옷긴다.
  ///
  /// ```
  /// town   : 22 진입, 23 퐷말, 24 물, 25 늪, 26 용암, 27..47 이동, 그외 NPC
  /// ground : 22 퐷말, 48 물, 23/49 늪, 50 용암, 24..47 이동, 그외 진입
  /// den: 0/52 특수, 53 푯말, 48 물, 49 늪, 50 용암, 54 진입,
  ///      41..47 이동, 1..40/51 벽, 그 외 NPC
  /// keep: den과 같으나 40..47 이동, 1..39/51 벽
  /// ```
  TileCategory getCategory(int tileValue) {
    if (tileValue == 0) return TileCategory.special;
    if (tileValue >= 1 && tileValue <= 21) return TileCategory.wall;

    switch (category) {
      case 'town':
        if (tileValue == 22) return TileCategory.portal;
        if (tileValue == 23) return TileCategory.sign;
        if (tileValue == 24) return TileCategory.water;
        if (tileValue == 25) return TileCategory.swamp;
        if (tileValue == 26) return TileCategory.lava;
        if (tileValue >= 27 && tileValue <= 47) return TileCategory.walkable;
        return TileCategory.npc;
      case 'ground':
        if (tileValue == 22) return TileCategory.sign;
        if (tileValue == 48) return TileCategory.water;
        if (tileValue == 23 || tileValue == 49) return TileCategory.swamp;
        if (tileValue == 50) return TileCategory.lava;
        if (tileValue >= 24 && tileValue <= 47) return TileCategory.walkable;
        return TileCategory.portal;
      case 'den':
      case 'keep':
        if (tileValue == 52) return TileCategory.special;
        if (tileValue >= (category == 'keep' ? 40 : 41) && tileValue <= 47) {
          return TileCategory.walkable;
        }
        if (tileValue == 48) return TileCategory.water;
        if (tileValue == 49) return TileCategory.swamp;
        if (tileValue == 50) return TileCategory.lava;
        if (tileValue == 51) return TileCategory.wall;
        if (tileValue == 53) return TileCategory.sign;
        if (tileValue == 54) return TileCategory.portal;
        if (tileValue <= (category == 'keep' ? 39 : 40)) {
          return TileCategory.wall;
        }
        return TileCategory.npc;
    }

    // 카테고리를 모를 때(테스트 등)의 기존 추정 로직.
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

  /// 원작 `saveN.map`의 현재 지도 스냅샷을 적용한다.
  void applyTileSnapshot(List<int> tiles) {
    if (tiles.length != xmax * ymax) return;
    for (var y = 0; y < ymax; y++) {
      for (var x = 0; x < xmax; x++) {
        grid[y][x] = tiles[y * xmax + x];
      }
    }
  }

  /// `assets/maps/<filename>.MAP` 에서 바이너리 로드
  static Future<LoreMapData> loadFromAsset(
    String mapName, {
    String category = '',
  }) async {
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

    return LoreMapData(
      name: mapName,
      xmax: xmax,
      ymax: ymax,
      grid: grid,
      category: category,
    );
  }
}

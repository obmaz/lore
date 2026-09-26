import '../game/lore_map_manager.dart';

enum LoreMoveKind { boundary, wall, waterBlocked, npc, portal, sign, walk }

class LoreMoveDecision {
  final LoreMoveKind kind;
  final TileCategory? category;

  const LoreMoveDecision(this.kind, this.category);
}

/// `LOREMAIN.PAS`의 맵 종류별 이동 분기를 화면과 분리한다.
class LoreMovementLogic {
  LoreMovementLogic._();

  static LoreMoveDecision decide({
    required LoreMapData map,
    required int targetX,
    required int targetY,
    required bool canWalkOnWater,
    required bool hasPortal,
  }) {
    // LOREMAIN.PAS: (x>4) and (x<xmax-3) and (y>4) and (y<ymax-3).
    // 실제 지도에는 바깥 테두리에도 통과 가능 타일이 있지만 원작은 진입을 막는다.
    if (targetX <= 4 ||
        targetX >= map.xmax - 3 ||
        targetY <= 4 ||
        targetY >= map.ymax - 3) {
      return const LoreMoveDecision(LoreMoveKind.boundary, null);
    }

    final category = map.getCategory(map.getTile(targetX, targetY));
    if (category == TileCategory.wall) {
      return LoreMoveDecision(LoreMoveKind.wall, category);
    }
    if (category == TileCategory.water && !canWalkOnWater) {
      return LoreMoveDecision(LoreMoveKind.waterBlocked, category);
    }
    if (category == TileCategory.npc) {
      return LoreMoveDecision(LoreMoveKind.npc, category);
    }
    if (category == TileCategory.portal ||
        (category == TileCategory.special && hasPortal)) {
      return LoreMoveDecision(LoreMoveKind.portal, category);
    }
    if (category == TileCategory.sign) {
      return LoreMoveDecision(LoreMoveKind.sign, category);
    }
    return LoreMoveDecision(LoreMoveKind.walk, category);
  }
}

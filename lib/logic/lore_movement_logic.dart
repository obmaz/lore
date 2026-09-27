import '../game/lore_map_manager.dart';
import 'lore_tile_protocol.dart';

enum LoreMoveKind { boundary, wall, waterBlocked, npc, portal, sign, walk }

class LoreMoveDecision {
  final LoreMoveKind kind;
  final TileCategory? category;
  final LoreTileAction? sourceAction;

  const LoreMoveDecision(this.kind, this.category, [this.sourceAction]);
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

    final tile = map.getTile(targetX, targetY);
    final action = map.actionForTile(tile);
    final category = map.getCategory(tile);
    if (action == LoreTileAction.wall) {
      return LoreMoveDecision(LoreMoveKind.wall, category, action);
    }
    if (action == LoreTileAction.water && !canWalkOnWater) {
      return LoreMoveDecision(LoreMoveKind.waterBlocked, category, action);
    }
    if (action == LoreTileAction.talk) {
      return LoreMoveDecision(LoreMoveKind.npc, category, action);
    }
    if (action == LoreTileAction.enter ||
        (action == LoreTileAction.special && hasPortal)) {
      return LoreMoveDecision(LoreMoveKind.portal, category, action);
    }
    if (action == LoreTileAction.sign) {
      return LoreMoveDecision(LoreMoveKind.sign, category, action);
    }
    return LoreMoveDecision(LoreMoveKind.walk, category, action);
  }
}

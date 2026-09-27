import '../game/lore_map_manager.dart';
import '../game/lore_world_manager.dart';
import 'lore_movement_logic.dart';
import 'lore_tile_protocol.dart';

enum LoreFieldEffectKind {
  boundary,
  wall,
  waterBlocked,
  talk,
  portalRequest,
  sign,
  positionChanged,
  poisonTick,
  mindReadTick,
  moveMode,
  hazard,
  step,
  encounterCheck,
}

class LoreFieldEffect {
  final LoreFieldEffectKind kind;
  final TileCategory? category;

  const LoreFieldEffect(this.kind, [this.category]);
}

/// An input command and its ordered effects before the UI performs them.
class LoreFieldTransition {
  final int x;
  final int y;
  final int direction;
  final bool moved;
  final PortalInfo? portal;
  final List<LoreFieldEffect> effects;

  const LoreFieldTransition({
    required this.x,
    required this.y,
    required this.direction,
    required this.moved,
    required this.portal,
    required this.effects,
  });
}

/// `LOREMAIN.Main` tile dispatch, with no Flutter, dialog, or mutable game state.
class LoreFieldSession {
  LoreFieldSession._();

  static LoreFieldTransition move({
    required LoreMapData map,
    required int x,
    required int y,
    required int direction,
    required int dx,
    required int dy,
    required bool canWalkOnWater,
    required PortalInfo? portal,
  }) {
    final nextDirection = switch ((dx, dy)) {
      (0, 1) => 0,
      (0, -1) => 1,
      (1, 0) => 2,
      (-1, 0) => 3,
      _ => direction,
    };
    final targetX = x + dx;
    final targetY = y + dy;
    final decision = LoreMovementLogic.decide(
      map: map,
      targetX: targetX,
      targetY: targetY,
      canWalkOnWater: canWalkOnWater,
      hasPortal: portal != null,
    );
    List<LoreFieldEffect> effects;
    var moved = false;
    switch (decision.kind) {
      case LoreMoveKind.boundary:
        effects = const [LoreFieldEffect(LoreFieldEffectKind.boundary)];
      case LoreMoveKind.wall:
        effects = const [LoreFieldEffect(LoreFieldEffectKind.wall)];
      case LoreMoveKind.waterBlocked:
        effects = const [LoreFieldEffect(LoreFieldEffectKind.waterBlocked)];
      case LoreMoveKind.npc:
        effects = const [LoreFieldEffect(LoreFieldEffectKind.talk)];
      case LoreMoveKind.portal:
        effects = portal == null
            ? const []
            : const [LoreFieldEffect(LoreFieldEffectKind.portalRequest)];
      case LoreMoveKind.sign:
        effects = const [LoreFieldEffect(LoreFieldEffectKind.sign)];
      case LoreMoveKind.walk:
        moved = true;
        final category = decision.category!;
        if (decision.sourceAction == LoreTileAction.walk) {
          effects = const [
            LoreFieldEffect(LoreFieldEffectKind.positionChanged),
            LoreFieldEffect(LoreFieldEffectKind.moveMode),
          ];
          break;
        }
        effects = [
          const LoreFieldEffect(LoreFieldEffectKind.positionChanged),
          if (category == TileCategory.swamp ||
              category == TileCategory.lava ||
              category == TileCategory.water)
            LoreFieldEffect(LoreFieldEffectKind.hazard, category),
          if (decision.sourceAction == LoreTileAction.special)
            const LoreFieldEffect(LoreFieldEffectKind.step),
          // Water's roll belongs to LOREMAIN.enter_water and runs in its
          // source order, immediately after the water-walk decrement.
        ];
    }
    return LoreFieldTransition(
      x: moved ? targetX : x,
      y: moved ? targetY : y,
      direction: nextDirection,
      moved: moved,
      portal: portal,
      effects: effects,
    );
  }
}

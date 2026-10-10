import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/logic/lore_movement_logic.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('K_DEN1 가장자리의 통행 가능한 타일도 원작 이동 경계에서 막힌다', () async {
    final map = await LoreMapData.loadFromAsset('K_DEN1', category: 'town');
    expect(map.getTile(25, 47), 47);
    expect(map.getCategory(map.getTile(25, 47)), TileCategory.walkable);

    final decision = LoreMovementLogic.decide(
      map: map,
      targetX: 25,
      targetY: 47,
      canWalkOnWater: false,
      hasPortal: false,
    );
    expect(decision.kind, LoreMoveKind.boundary);
  });
}

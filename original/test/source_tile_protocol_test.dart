import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/logic/lore_movement_logic.dart';
import 'package:lore/logic/lore_tile_protocol.dart';

/// LOREMAIN.PAS:208-282의 네 `case map[x,y] of`를 독립적인 범위 명세로 기록한다.
/// 지도 파일의 타일 값 전체(바이트 0..255)를 해당 원본 분류와 대조한다.
LoreTileAction sourceAction(String position, int tile) {
  if (tile == 0) return LoreTileAction.special;
  if (tile >= 1 && tile <= 21) return LoreTileAction.wall;
  switch (position) {
    case 'town':
      if (tile == 22) return LoreTileAction.enter;
      if (tile == 23) return LoreTileAction.sign;
      if (tile == 24) return LoreTileAction.water;
      if (tile == 25) return LoreTileAction.swamp;
      if (tile == 26) return LoreTileAction.lava;
      if (tile >= 27 && tile <= 47) return LoreTileAction.walk;
      return LoreTileAction.talk;
    case 'ground':
      if (tile == 22) return LoreTileAction.sign;
      if (tile == 23 || tile == 49) return LoreTileAction.swamp;
      if (tile >= 24 && tile <= 47) return LoreTileAction.walk;
      if (tile == 48) return LoreTileAction.water;
      if (tile == 50) return LoreTileAction.lava;
      return LoreTileAction.enter;
    case 'den':
      if (tile >= 22 && tile <= 40 || tile == 51) return LoreTileAction.wall;
      if (tile >= 41 && tile <= 47) return LoreTileAction.walk;
      if (tile == 48) return LoreTileAction.water;
      if (tile == 49) return LoreTileAction.swamp;
      if (tile == 50) return LoreTileAction.lava;
      if (tile == 52) return LoreTileAction.special;
      if (tile == 53) return LoreTileAction.sign;
      if (tile == 54) return LoreTileAction.enter;
      return LoreTileAction.talk;
    case 'keep':
      if (tile >= 22 && tile <= 39 || tile == 51) return LoreTileAction.wall;
      if (tile >= 40 && tile <= 47) return LoreTileAction.walk;
      if (tile == 48) return LoreTileAction.water;
      if (tile == 49) return LoreTileAction.swamp;
      if (tile == 50) return LoreTileAction.lava;
      if (tile == 52) return LoreTileAction.special;
      if (tile == 53) return LoreTileAction.sign;
      if (tile == 54) return LoreTileAction.enter;
      return LoreTileAction.talk;
  }
  throw ArgumentError(position);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('원본 네 지도 종류의 256개 타일 값을 모두 같은 행동으로 분류한다', () {
    for (final position in ['town', 'ground', 'den', 'keep']) {
      final map = LoreMapData(
        name: 'TEST',
        xmax: 20,
        ymax: 20,
        grid: List.generate(20, (_) => List.filled(20, 42)),
        category: position,
      );
      for (var tile = 0; tile <= 255; tile++) {
        expect(
          map.actionForTile(tile),
          sourceAction(position, tile),
          reason: '$position 타일 $tile',
        );
      }
    }
  });

  test('원본 선행 이동 순서와 특수 타일 포털 예외를 분리한다', () {
    for (final action in [
      LoreTileAction.special,
      LoreTileAction.water,
      LoreTileAction.swamp,
      LoreTileAction.lava,
      LoreTileAction.walk,
    ]) {
      expect(action.entersTargetBeforeAction, isTrue, reason: '$action');
    }
    for (final action in [
      LoreTileAction.wall,
      LoreTileAction.enter,
      LoreTileAction.sign,
      LoreTileAction.talk,
    ]) {
      expect(action.entersTargetBeforeAction, isFalse, reason: '$action');
    }

    final grid = List.generate(20, (_) => List.filled(20, 42));
    grid[9][10] = 52;
    final map = LoreMapData(
      name: 'KEEP2',
      xmax: 20,
      ymax: 20,
      grid: grid,
      category: 'keep',
    );
    final decision = LoreMovementLogic.decide(
      map: map,
      targetX: 11,
      targetY: 10,
      canWalkOnWater: false,
      hasPortal: true,
    );
    expect(decision.sourceAction, LoreTileAction.special);
    expect(decision.kind, LoreMoveKind.portal); // 현재 포털 처리 경로
  });
}

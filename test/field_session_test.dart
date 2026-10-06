import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/game/lore_world_manager.dart';
import 'package:lore/logic/lore_field_session.dart';

void main() {
  LoreMapData map(String category, int tile) {
    final grid = List.generate(20, (_) => List.filled(20, 42));
    grid[9][10] = tile;
    return LoreMapData(
      name: 'TEST',
      category: category,
      xmax: 20,
      ymax: 20,
      grid: grid,
    );
  }

  LoreFieldTransition move(
    LoreMapData map, {
    PortalInfo? portal,
    bool canWalkOnWater = false,
  }) => LoreFieldSession.move(
    map: map,
    x: 10,
    y: 10,
    direction: 0,
    dx: 1,
    dy: 0,
    canWalkOnWater: canWalkOnWater,
    portal: portal,
  );

  List<LoreFieldEffectKind> kinds(LoreFieldTransition result) =>
      result.effects.map((effect) => effect.kind).toList();

  test('늪 프로시저는 목표 좌표에 들어간 뒤 한 번 실행된다', () {
    final result = move(map('town', 25));
    expect((result.x, result.y, result.direction), (11, 10, 2));
    expect(result.moved, isTrue);
    expect(kinds(result), [
      LoreFieldEffectKind.positionChanged,
      LoreFieldEffectKind.hazard,
    ]);
    expect(result.effects[1].category, TileCategory.swamp);
  });

  test('진입 타일은 목적지가 있을 때만 확인을 요청하고 제자리에 남는다', () {
    const portal = PortalInfo(
      targetMapId: 7,
      targetX: 10,
      targetY: 11,
      name: 'gate',
    );
    final mapData = map('town', 22);
    final found = move(mapData, portal: portal);
    expect((found.x, found.y), (10, 10));
    expect(kinds(found), [LoreFieldEffectKind.portalRequest]);
    expect(found.portal, same(portal));
    expect(kinds(move(mapData)), [LoreFieldEffectKind.entranceNoMatch]);
  });

  test('특수 타일에 포털이 겹치면 포털을 우선하고 없으면 사건을 밟는다', () {
    const portal = PortalInfo(
      targetMapId: 9,
      targetX: 10,
      targetY: 11,
      name: 'gate',
    );
    final mapData = map('keep', 52);
    expect(kinds(move(mapData, portal: portal)), [
      LoreFieldEffectKind.portalRequest,
    ]);
    expect(kinds(move(mapData)), [
      LoreFieldEffectKind.positionChanged,
      LoreFieldEffectKind.step,
    ]);
  });

  test('Main hotkey return dispatches the current tile with zero movement', () {
    final grid = List.generate(20, (_) => List.filled(20, 42));
    grid[9][9] = 0;
    final mapData = LoreMapData(
      name: 'TEST',
      category: 'town',
      xmax: 20,
      ymax: 20,
      grid: grid,
    );
    final transition = LoreFieldSession.move(
      map: mapData,
      x: 10,
      y: 10,
      direction: 2,
      dx: 0,
      dy: 0,
      canWalkOnWater: false,
      portal: null,
    );
    expect((transition.x, transition.y, transition.direction), (10, 10, 2));
    expect(kinds(transition), [
      LoreFieldEffectKind.positionChanged,
      LoreFieldEffectKind.step,
    ]);
  });

  test('특수·수중·용암에서는 독과 독심술을 진행하지 않는다', () {
    for (final (category, tile) in [
      ('town', 0),
      ('ground', 0),
      ('den', 52),
      ('keep', 52),
    ]) {
      final result = move(map(category, tile));
      expect(kinds(result), [
        LoreFieldEffectKind.positionChanged,
        LoreFieldEffectKind.step,
      ], reason: '$category/$tile');
    }
    expect(kinds(move(map('den', 41))), [
      LoreFieldEffectKind.positionChanged,
      LoreFieldEffectKind.moveMode,
    ]);
    expect(kinds(move(map('ground', 48), canWalkOnWater: true)), [
      LoreFieldEffectKind.positionChanged,
      LoreFieldEffectKind.hazard,
    ]);
    expect(kinds(move(map('town', 26))), [
      LoreFieldEffectKind.positionChanged,
      LoreFieldEffectKind.hazard,
    ]);
  });

  test('벽·대화·표지판은 목표 칸을 밟지 않고 같은 명령에서 같은 결과를 낸다', () {
    for (final (tile, expected) in [
      (1, LoreFieldEffectKind.wall),
      (48, LoreFieldEffectKind.talk),
      (23, LoreFieldEffectKind.sign),
    ]) {
      final mapData = map('town', tile);
      final first = move(mapData);
      final second = move(mapData);
      expect((first.x, first.y), (10, 10));
      expect(kinds(first), [expected]);
      expect(kinds(second), kinds(first));
    }
  });
}

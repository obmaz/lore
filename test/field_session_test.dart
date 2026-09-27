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

  LoreFieldTransition move(LoreMapData map, {PortalInfo? portal}) =>
      LoreFieldSession.move(
        map: map,
        x: 10,
        y: 10,
        direction: 0,
        dx: 1,
        dy: 0,
        canWalkOnWater: false,
        portal: portal,
      );

  List<LoreFieldEffectKind> kinds(LoreFieldTransition result) =>
      result.effects.map((effect) => effect.kind).toList();

  test('이동 명령은 위치·위험·사건·조우 검사를 원본 순서로 기록한다', () {
    final result = move(map('town', 25));
    expect((result.x, result.y, result.direction), (11, 10, 2));
    expect(result.moved, isTrue);
    expect(kinds(result), [
      LoreFieldEffectKind.positionChanged,
      LoreFieldEffectKind.hazard,
      LoreFieldEffectKind.step,
      LoreFieldEffectKind.encounterCheck,
    ]);
    expect(result.effects[1].category, TileCategory.swamp);
    expect(result.effects.last.category, TileCategory.swamp);
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
    expect(kinds(move(mapData)), isEmpty);
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
      LoreFieldEffectKind.encounterCheck,
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

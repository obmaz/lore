import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/presentation/battle_backdrop.dart';

void main() {
  test('all 27 map environments have presentation-only regional backdrops', () {
    final expected = [
      BattleBackdrop.meadow,
      BattleBackdrop.meadow,
      BattleBackdrop.coast,
      BattleBackdrop.marsh,
      BattleBackdrop.volcanic,
      BattleBackdrop.castle,
      BattleBackdrop.village,
      BattleBackdrop.village,
      BattleBackdrop.village,
      BattleBackdrop.coast,
      for (var i = 11; i <= 20; i++) BattleBackdrop.cavern,
      BattleBackdrop.castle,
      BattleBackdrop.castle,
      BattleBackdrop.castle,
      BattleBackdrop.cavern,
      BattleBackdrop.cavern,
      BattleBackdrop.cavern,
      BattleBackdrop.castle,
    ];
    for (var id = 1; id <= 27; id++) {
      expect(BattleBackdrop.forLocation(mapId: id), expected[id - 1]);
    }
  });

  test('ground appearance follows tiles without changing source map data', () {
    final map = LoreMapData(
      name: 'GROUND1',
      category: 'ground',
      xmax: 3,
      ymax: 3,
      grid: [
        for (var y = 0; y < 3; y++) [42, 42, 42],
      ],
    );
    for (final entry in {
      42: BattleBackdrop.meadow,
      32: BattleBackdrop.sand,
      48: BattleBackdrop.coast,
      49: BattleBackdrop.marsh,
      50: BattleBackdrop.volcanic,
    }.entries) {
      map.setTile(2, 2, entry.key);
      final snapshot = map.tileSnapshot();
      expect(
        BattleBackdrop.forLocation(mapId: 1, map: map, x: 2, y: 2),
        entry.value,
      );
      expect(map.tileSnapshot(), snapshot);
    }
    map.setTile(2, 2, 42);
    map.setTile(1, 2, 2);
    final snapshot = map.tileSnapshot();
    expect(
      BattleBackdrop.forLocation(mapId: 1, map: map, x: 2, y: 2),
      BattleBackdrop.forest,
    );
    expect(
      BattleBackdrop.forLocation(mapId: 1, map: map, x: 1, y: 1),
      BattleBackdrop.forest,
    );
    expect(map.tileSnapshot(), snapshot);
    expect(
      BattleBackdrop.forLocation(mapId: 26, map: map),
      BattleBackdrop.cavern,
    );
  });
}

import 'dart:math';

import '../game/lore_map_manager.dart';

/// LOREBATT.PAS `randomenemy` / `EncounterEnemy`와 LOREMAIN.PAS의 이동 조우율.
class LoreEncounterLogic {
  /// 원작 `random(range) + plus`: 두 값 모두 포함하는 몬스터 도감 번호 범위.
  static const Map<int, (int min, int max)> pools = {
    1: (1, 10),
    2: (8, 20),
    3: (16, 30),
    4: (24, 40),
    5: (33, 49),
    11: (6, 15),
    12: (17, 21),
    14: (5, 12),
    15: (18, 25),
    16: (28, 32),
    17: (23, 28),
    18: (30, 32),
    19: (38, 41),
    20: (41, 45),
  };

  static bool shouldEncounter(
    int mapId,
    TileCategory tile,
    Random random, {
    int frequency = 2,
  }) {
    if (!pools.containsKey(mapId)) return false;
    final steps = switch (tile) {
      TileCategory.walkable => 20,
      TileCategory.water => 30,
      _ => 0,
    };
    if (steps == 0) return false;
    final rate = frequency >= 1 && frequency <= 3 ? frequency : 2;
    return random.nextInt(rate * steps) == 0;
  }

  static List<int> rollMonsters(
    int mapId,
    Random random, {
    int maxEnemies = 5,
  }) {
    final pool = pools[mapId];
    if (pool == null) return const [];
    final limit = maxEnemies >= 3 && maxEnemies <= 7 ? maxEnemies : 5;
    final count = random.nextInt(limit) + 1;
    return List.generate(
      count,
      (_) => pool.$1 + random.nextInt(pool.$2 - pool.$1 + 1),
    );
  }
}

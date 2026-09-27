import 'dart:math';

import '../game/lore_map_manager.dart';
import '../models/monster.dart';
import '../models/party_member.dart';

enum EncounterChoice { engage, flee }

typedef EncounterDecision = ({bool escaped, bool enemyFirst});

/// LOREBATT.PAS `randomenemy` / `EncounterEnemy`와 LOREMAIN.PAS의 이동 조우율.
class LoreEncounterLogic {
  /// 교전과 도주의 공통 결과. 도주 실패는 민첩성에 관계없이 적 선공이다.
  static EncounterDecision decide(
    EncounterChoice choice,
    List<PartyMember> party,
    List<Monster> enemies,
  ) {
    if (choice == EncounterChoice.flee) {
      return canEvadeBeforeBattle(party, enemies)
          ? (escaped: true, enemyFirst: false)
          : (escaped: false, enemyFirst: true);
    }
    return (escaped: false, enemyFirst: enemyActsFirst(party, enemies));
  }

  /// LOREBATT.PAS `EncounterEnemy`: 이름 있는 파티원과 모든 적의 민첩성
  /// 정수 평균을 비교한다. 동률이면 적이 먼저 행동한다.
  static bool enemyActsFirst(List<PartyMember> party, List<Monster> enemies) {
    final present = party.where((member) => member.name.isNotEmpty).toList();
    if (present.isEmpty || enemies.isEmpty) return false;
    final partyAverage =
        present.fold<int>(0, (sum, member) => sum + member.agility) ~/
        present.length;
    return partyAverage <= averageEnemyAgility(enemies);
  }

  /// 전투 진입 전 도주 선택. 이름 있는 대원의 평균 행운이 적 평균
  /// 민첩성보다 높을 때만 즉시 빠져나간다 (LOREBATT.PAS:1241-1257).
  static bool canEvadeBeforeBattle(
    List<PartyMember> party,
    List<Monster> enemies,
  ) {
    final present = party.where((member) => member.name.isNotEmpty).toList();
    if (present.isEmpty || enemies.isEmpty) return false;
    final averageLuck =
        present.fold<int>(0, (sum, member) => sum + member.luck) ~/
        present.length;
    return averageLuck > averageEnemyAgility(enemies);
  }

  static int averageEnemyAgility(List<Monster> enemies) {
    if (enemies.isEmpty) return 0;
    return enemies.fold<int>(0, (sum, enemy) => sum + enemy.agility) ~/
        enemies.length;
  }

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

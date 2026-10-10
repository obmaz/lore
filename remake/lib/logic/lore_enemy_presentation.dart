import '../models/monster.dart';

/// DisplayEnemies' EGA index, independent of the modern rendering adapter.
class LoreEnemyPresentation {
  const LoreEnemyPresentation._();
  static int color(Monster enemy) {
    if (enemy.isDead) return 0;
    if (enemy.isUnconscious) return 8;
    final hp = enemy.hp;
    if (hp == 0) return 8;
    if (hp < 0) return 10;
    if (hp <= 19) return 12;
    if (hp <= 49) return 4;
    if (hp <= 99) return 6;
    if (hp <= 199) return 14;
    if (hp <= 299) return 2;
    return 10;
  }
}

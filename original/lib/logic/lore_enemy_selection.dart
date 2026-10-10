import '../models/monster.dart';

/// LORESUB.SelectEnemy: 1-based wrapping cursor and Enter-only acceptance.
/// Escape is ignored here (unlike the command Select menu).
class LoreEnemySelection {
  LoreEnemySelection(this.count, {this.number = 1}) {
    RangeError.checkValueInInterval(count, 1, 7, 'enemy count');
    RangeError.checkValueInInterval(number, 1, count, 'enemy number');
  }
  final int count;
  int number;
  bool readKey(int key, {int scan = 0}) {
    var delta = 0;
    if (key == 0) {
      key = scan;
      if (scan == 72) delta = -1;
      if (scan == 80) delta = 1;
    }
    final accepted = key == 13;
    if (delta != 0 || accepted) {
      number += delta;
      if (number < 1) number = count;
      if (number > count) number = 1;
    }
    return accepted;
  }

  static int color(Monster enemy, {bool highlighted = true}) {
    if (enemy.isDead) return highlighted ? 7 : 0;
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

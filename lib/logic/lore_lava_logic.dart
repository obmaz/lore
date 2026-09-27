import 'dart:math';

import '../models/party_member.dart';

/// LOREMAIN.enter_lava rolls every one of the six player slots before damage.
class LoreLavaLogic {
  LoreLavaLogic._();

  static List<int> rollDamages(List<PartyMember> party, Random random) => [
    for (final member in party)
      random.nextInt(40) +
          40 -
          2 * (member.luck > 0 ? random.nextInt(member.luck) : 0),
  ];

  static void applyDamage(PartyMember member, int damage) {
    if (member.hp > 0 && member.unconscious == 0) {
      member.hp -= damage;
      if (member.hp <= 0) member.unconscious = 1;
    } else if (member.hp > 0 && member.unconscious > 0) {
      member.hp -= damage;
    } else if (member.unconscious > 0 && member.dead == 0) {
      member.unconscious += damage;
      if (member.unconscious > member.endurance * member.battleLevel) {
        member.dead = 1;
      }
    } else if (member.dead > 0) {
      member.dead = min(30000, member.dead + damage);
    }
  }
}

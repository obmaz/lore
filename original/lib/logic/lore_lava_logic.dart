import 'dart:math';

import '../models/party_member.dart';
import 'lore_source_memory.dart';

/// LOREMAIN.enter_lava rolls every one of the six player slots before damage.
class LoreLavaLogic {
  LoreLavaLogic._();

  static List<int> rollDamages(List<PartyMember> party, Random random) {
    final damages = <int>[];
    for (var i = 0; i < 6; i++) {
      // Shipped EXE evaluates the right operand first: luck, then Random(40).
      final luck = random.nextInt(i < party.length ? party[i].luck : 0);
      damages.add(random.nextInt(40) + 40 - 2 * luck);
    }
    return damages;
  }

  static void applyDamage(PartyMember member, int damage) {
    if (member.hp > 0 && member.unconscious == 0) {
      member.hp = LorePascal.integer(member.hp - damage);
      if (member.hp <= 0) member.unconscious = 1;
    } else if (member.hp > 0 && member.unconscious > 0) {
      member.hp = LorePascal.integer(member.hp - damage);
    } else if (member.unconscious > 0 && member.dead == 0) {
      member.unconscious = LorePascal.integer(member.unconscious + damage);
      if (member.unconscious >
          LorePascal.integer(member.endurance * member.battleLevel)) {
        member.dead = 1;
      }
    } else if (member.dead > 0) {
      // Both operands are integer: DOS compares the wrapped sum before capping.
      final nextDead = LorePascal.integer(member.dead + damage);
      member.dead = nextDead > 30000 ? 30000 : nextDead;
    }
  }
}

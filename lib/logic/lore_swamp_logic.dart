import 'dart:math';

import '../models/party_member.dart';

/// LOREMAIN.enter_swamp rolls all six slots before applying poison to members.
class LoreSwampLogic {
  LoreSwampLogic._();

  static List<int> rollPoisonedSlots(List<PartyMember> party, Random random) {
    final poisoned = <int>[];
    for (var i = 0; i < party.length; i++) {
      final marked = random.nextInt(20) + 1 >= party[i].luck;
      if (marked && party[i].name.isNotEmpty) poisoned.add(i);
    }
    return poisoned;
  }

  static bool applyPoison(PartyMember member) {
    if (member.name.isEmpty || member.poison > 0) return false;
    member.poison = 1;
    return true;
  }
}

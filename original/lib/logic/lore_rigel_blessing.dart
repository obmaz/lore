import 'dart:math';

import '../models/party_member.dart';
import 'lore_source_memory.dart';

/// LORESPEC.PAS: Rigel에게 식량과 치료를 주었을 때의 무기 축복.
void applyRigelBlessing(List<PartyMember> party, Random random) {
  if (party.isEmpty) return;
  party.first.sp = 0;
  for (final member in party.take(6)) {
    if (member.name.isEmpty) continue;
    if (random.nextInt(20) < member.luck && random.nextInt(20) < member.luck) {
      member.weaPower = LorePascal.byte((member.weaPower * 1.2).round());
    }
  }
}

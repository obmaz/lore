import '../data/lore_script.dart';
import '../models/party_member.dart';
import 'lore_source_memory.dart';

/// 스크립트의 파티 전체 보상을 입력 파티를 바꾸지 않고 계산한다.
class ScriptPartyReducer {
  ScriptPartyReducer._();

  static List<PartyMember> applyProgress(
    List<PartyMember> party,
    ScriptOutcome outcome,
  ) {
    return [
      for (var slot = 0; slot < party.length; slot++)
        _applyToMember(party[slot], outcome, slot + 1),
    ];
  }

  static PartyMember _applyToMember(
    PartyMember member,
    ScriptOutcome outcome,
    int slot,
  ) {
    final next = PartyMember.fromJson(member.toJson());
    // LORETALK.PAS:360-367 / LORESPEC.PAS:2061-2064.
    if (slot <= 6 && next.name.isNotEmpty) {
      if (outcome.partyClassId != null) {
        next.playerClass = PlayerClass.fromId(outcome.partyClassId!);
      }
      next.experience = LorePascal.longint(next.experience + outcome.expDelta);
    }
    return next;
  }
}

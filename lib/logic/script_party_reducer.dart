import '../data/lore_script.dart';
import '../models/party_member.dart';

/// 스크립트의 파티 전체 보상을 입력 파티를 바꾸지 않고 계산한다.
class ScriptPartyReducer {
  ScriptPartyReducer._();

  static List<PartyMember> applyProgress(
    List<PartyMember> party,
    ScriptOutcome outcome,
  ) {
    return [for (final member in party) _applyToMember(member, outcome)];
  }

  static PartyMember _applyToMember(PartyMember member, ScriptOutcome outcome) {
    final next = PartyMember.fromJson(member.toJson());
    // LORETALK.PAS:360-367 / LORESPEC.PAS:2061-2064.
    if (next.name.isNotEmpty) {
      if (outcome.partyClassId case final classId?) {
        next.playerClass = PlayerClass.fromId(classId);
      }
      next.experience += outcome.expDelta;
    }
    return next;
  }
}

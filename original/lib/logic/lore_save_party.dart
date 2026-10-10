import '../models/party_member.dart';

/// LORESUB Save/Load and LORECRET Last transfer player[1..6], never scratch 7.
/// Short legacy Flutter lists are padded by the existing unused-slot adapter;
/// this is not a claim about truncated DOS files or native I/O error handling.
class LoreSaveParty {
  LoreSaveParty._();

  static List<PartyMember> snapshot(List<PartyMember> party) => [
    for (var i = 0; i < 6; i++)
      i < party.length
          ? PartyMember.fromJson(party[i].toJson())
          : PartyMember.blank(),
  ];
}

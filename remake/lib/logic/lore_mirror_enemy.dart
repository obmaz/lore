import '../models/monster.dart';
import '../models/party_member.dart';

/// LORESUB.PAS `turn_mind(j, enemy_num)`과 맵 23의 빈 파티 슬롯 Wraith.
List<Monster> createMindMirrorEnemies(List<PartyMember> party) {
  return List.generate(6, (index) {
    if (index >= party.length || party[index].name.isEmpty) {
      return Monster.create(60).withOverrides(eNumber: 1);
    }
    final player = party[index];
    return Monster(
      eNumber: 1,
      name: player.name,
      strength: player.strength,
      mentality: player.mentality,
      endurance: player.endurance,
      resistance: player.resistance,
      agility: player.agility,
      accArms: player.accArms,
      accMagic: player.accMagic,
      ac: player.ac,
      special: player.playerClass == PlayerClass.hunter ? 2 : 0,
      castLevel: player.magicLevel ~/ 4,
      specialCastLevel: 0,
      level: player.battleLevel,
    );
  });
}

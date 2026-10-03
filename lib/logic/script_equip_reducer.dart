import '../models/party_member.dart';

typedef ScriptEquip = ({
  String kind,
  int index,
  int power,
  bool prompt,
  bool onlyUnarmed,
});

class ScriptEquipResult {
  final List<PartyMember> party;
  final List<int> equippedIndexes;
  final bool accepted;
  final bool rejectedMonk;

  const ScriptEquipResult({
    required this.party,
    required this.equippedIndexes,
    required this.accepted,
    this.rejectedMonk = false,
  });
}

/// 원작 LORESPEC.PAS의 장비 대상 판정과 장착 수치를 계산한다.
class ScriptEquipReducer {
  ScriptEquipReducer._();

  /// The source's `message(15, ..)` after an equip: LORESPEC:517 (Oedipus'
  /// spear, `name + ' 가 ...'` with the space), 873/920 (golden shield) and
  /// 940 (golden armor). The basic weapons of the weapon room print nothing.
  static String? completionMessage(PartyMember member, ScriptEquip equip) {
    if (equip.kind == 'weapon' && equip.index == 3) {
      return '${member.name} 가 오이디푸스의 창을 장착했다.';
    }
    if (equip.kind == 'shield' && equip.index == 5) {
      return '${member.name}가 황금의 방패를 장착했다.';
    }
    if (equip.kind == 'armor' && equip.index == 5) {
      return '${member.name}가 황금의 갑옷을 장착했다.';
    }
    return null;
  }

  static ScriptEquipResult apply(
    List<PartyMember> party,
    ScriptEquip equip, {
    int? selectedIndex,
  }) {
    final targets = equip.prompt
        ? [?selectedIndex]
        : [for (var i = 0; i < party.length; i++) i];
    if (equip.prompt && targets.isEmpty) {
      return ScriptEquipResult(
        party: party,
        equippedIndexes: const [],
        accepted: false,
      );
    }

    final next = [
      for (final member in party) PartyMember.fromJson(member.toJson()),
    ];
    final equipped = <int>[];
    for (final index in targets) {
      if (index < 0 || index >= party.length) continue;
      final member = party[index];
      if (member.name.isEmpty) continue;
      if (equip.kind == 'weapon' && member.playerClass == PlayerClass.monk) {
        if (equip.prompt) {
          return ScriptEquipResult(
            party: party,
            equippedIndexes: const [],
            accepted: false,
            rejectedMonk: true,
          );
        }
        continue;
      }
      if (equip.kind == 'weapon' && equip.onlyUnarmed && member.weapon != 0) {
        continue;
      }

      final updated = next[index];
      switch (equip.kind) {
        case 'weapon':
          if (equip.onlyUnarmed) {
            // 맵 6 기본 무장: 원작은 기사 보정 없이 wea_power := 5.
            updated.weapon = equip.index;
            updated.weaPower = equip.power;
          } else {
            updated.equipWeaponRaw(equip.index, equip.power);
          }
          break;
        case 'shield':
          updated.equipShieldRaw(equip.index, equip.power);
          break;
        case 'armor':
          updated.equipArmorRaw(equip.index, equip.power);
          break;
        default:
          continue;
      }
      next[index] = updated;
      equipped.add(index);
    }
    return ScriptEquipResult(
      party: next,
      equippedIndexes: equipped,
      accepted: !equip.prompt || equipped.isNotEmpty,
    );
  }
}

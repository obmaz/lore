import 'dart:convert';
import 'dart:typed_data';

import 'package:lore/models/monster.dart';
import 'package:lore/models/party_member.dart';

// Raw LORESUB.PAS record fields, decoded independently of production saves.
String _name(List<int> bytes, int offset) =>
    latin1.decode(bytes.sublist(offset + 1, offset + 1 + bytes[offset]));
ByteData _words(List<int> bytes) =>
    ByteData.sublistView(Uint8List.fromList(bytes));
PartyMember nativePlayer(List<int> r) {
  final d = _words(r);
  return PartyMember.zero()
    ..name = _name(r, 0)
    ..sex = Gender.values[r[18]]
    ..playerClass = PlayerClass.fromId(r[19])
    ..strength = r[20]
    ..mentality = r[21]
    ..concentration = r[22]
    ..endurance = r[23]
    ..resistance = r[24]
    ..agility = r[25]
    ..accArms = r[26]
    ..accMagic = r[27]
    ..accEsp = r[28]
    ..luck = r[29]
    ..poison = r[30]
    ..unconscious = d.getInt16(31, Endian.little)
    ..dead = d.getInt16(33, Endian.little)
    ..hp = d.getInt16(35, Endian.little)
    ..sp = d.getInt16(37, Endian.little)
    ..esp = d.getInt16(39, Endian.little)
    ..battleLevel = r[41]
    ..magicLevel = r[42]
    ..espLevel = r[43]
    ..ac = r[44]
    ..experience = d.getInt32(45, Endian.little)
    ..weapon = r[49]
    ..shield = r[50]
    ..armor = r[51]
    ..weaPower = r[52]
    ..shiPower = r[53]
    ..armPower = r[54];
}

Monster nativeMonster(List<int> r) => Monster(
  eNumber: r[0],
  name: _name(r, 1),
  strength: r[18],
  mentality: r[19],
  endurance: r[20],
  resistance: r[21],
  agility: r[22],
  accArms: r[23],
  accMagic: r[24],
  ac: r[25],
  special: r[26],
  castLevel: r[27],
  specialCastLevel: r[28],
  level: r[29],
  hp: _words(r).getInt16(30, Endian.little),
  isPoisoned: r[32] != 0,
  isUnconscious: r[33] != 0,
  isDead: r[34] != 0,
);
List<Object> nativeMonsterState(Monster e) => [
  e.eNumber,
  e.name,
  e.strength,
  e.mentality,
  e.endurance,
  e.resistance,
  e.agility,
  e.accArms,
  e.accMagic,
  e.ac,
  e.special,
  e.castLevel,
  e.specialCastLevel,
  e.level,
  e.hp,
  e.isPoisoned,
  e.isUnconscious,
  e.isDead,
];

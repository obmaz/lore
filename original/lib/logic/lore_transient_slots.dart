import '../models/monster.dart';
import '../models/party_member.dart';

/// Unsaved Pascal globals: enemy[1..7] and GameOption's player[7] scratch.
/// Active enemy count belongs to the battle, not to this retained storage.
class LoreTransientSlots {
  final List<Monster?> enemies = List.filled(7, null);
  PartyMember seventhPlayer = PartyMember.blank()
    ..battleLevel = 0
    ..magicLevel = 0
    ..espLevel = 0
    ..unconscious = 0
    ..dead = 0;

  void retainEnemies(List<Monster> active) {
    for (var i = 0; i < active.length; i++) {
      enemies[i] = active[i];
    }
  }

  /// Zero startup adapter for an unwritten slot; full DOS startup replay pending.
  Monster enemyAt(int index) => enemies[index] ??= Monster(
    eNumber: 0,
    name: '',
    strength: 0,
    mentality: 0,
    endurance: 0,
    resistance: 0,
    agility: 0,
    accArms: 0,
    accMagic: 0,
    ac: 0,
    special: 0,
    castLevel: 0,
    specialCastLevel: 0,
    level: 0,
    hp: 0,
  );

  /// Pascal Move copies the record; later mutations must not alias it.
  void rememberSwapPlayer(PartyMember member) {
    seventhPlayer = PartyMember.fromJson(member.toJson());
  }
}

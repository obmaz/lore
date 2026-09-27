import 'dart:math';

import '../models/party_member.dart';
import 'lore_lava_logic.dart';
import 'lore_swamp_logic.dart';

/// Source-shaped procedures from `LOREMAIN.PAS`.
///
/// Effects are callbacks so the procedure keeps Pascal's mutation, display,
/// random, and encounter order without depending on Flutter or Flame.
class LoreMainProcedures {
  LoreMainProcedures._();

  /// Shared body of the poison loop in `Move_Mode` and `enter_swamp`.
  /// Returns Pascal's `j`: the number of members whose poison reached 11.
  static int advancePoison(List<PartyMember> party) {
    var affected = 0;
    for (final member in party.take(6)) {
      if (member.name.isEmpty) continue;
      if (member.poison > 0) member.poison++;
      if (member.poison <= 10) continue;
      member.poison = 1;
      if (member.dead > 0 && member.dead < 100) {
        member.dead++;
      } else if (member.unconscious > 0) {
        member.unconscious++;
        if (member.unconscious > member.endurance * member.battleLevel) {
          member.dead = 1;
        }
      } else {
        member.hp--;
        if (member.hp <= 0) member.unconscious = 1;
      }
      affected++;
    }
    return affected;
  }

  /// `LOREMAIN.PAS:113-141`. Callbacks represent the original display,
  /// game-over, and battle boundaries; all conditions and mutations stay here.
  static void moveMode({
    required List<PartyMember> party,
    required void Function() scrollToParty,
    required void Function() displayHealthAndCondition,
    required void Function() gameOver,
    required int Function() mindReadSteps,
    required void Function(int steps) setMindReadSteps,
    required int encounterFrequency,
    required int Function(int exclusiveUpperBound) random,
    required void Function() encounterEnemy,
  }) {
    scrollToParty();
    final affected = advancePoison(party);
    if (affected > 0) displayHealthAndCondition();
    if (!party.take(6).any((member) => member.isBattleActive)) gameOver();
    final mindRead = mindReadSteps();
    if (mindRead > 0) setMindReadSteps(mindRead - 1);
    if (random(encounterFrequency * 20) == 0) encounterEnemy();
  }

  /// `LOREMAIN.PAS:29-75`. The six-slot poison roll is performed only after
  /// poison progression and only when swamp-walk has expired.
  static void enterSwamp({
    required List<PartyMember> party,
    required void Function() scrollToParty,
    required int Function() swampWalkSteps,
    required void Function(int steps) setSwampWalkSteps,
    required Random random,
    required void Function() showSwampWarning,
    required void Function(PartyMember member) showPoisonMessage,
    required void Function() displayCondition,
    required void Function() displayHealthAndCondition,
    required void Function() gameOver,
  }) {
    scrollToParty();
    final affected = advancePoison(party);
    final steps = swampWalkSteps();
    if (steps > 0) {
      setSwampWalkSteps(steps - 1);
    } else {
      final poisoned = LoreSwampLogic.rollPoisonedSlots(
        party.take(6).toList(),
        random,
      );
      showSwampWarning();
      for (final index in poisoned) {
        final member = party[index];
        showPoisonMessage(member);
        LoreSwampLogic.applyPoison(member);
      }
      displayCondition();
    }
    if (affected > 0) displayHealthAndCondition();
    if (!party.take(6).any((member) => member.isBattleActive)) gameOver();
  }

  /// `LOREMAIN.PAS:77-111`. Rolls damage for all six slots before showing
  /// messages and applying any damage, including damage to empty slots.
  static void enterLava({
    required List<PartyMember> party,
    required Random random,
    required void Function() scrollToParty,
    required void Function() showLavaWarning,
    required void Function(PartyMember member, int damage) showDamage,
    required void Function() displayCondition,
    required void Function() gameOver,
  }) {
    scrollToParty();
    final slots = party.take(6).toList();
    final damages = LoreLavaLogic.rollDamages(slots, random);
    showLavaWarning();
    for (var i = 0; i < slots.length; i++) {
      if (slots[i].name.isNotEmpty) showDamage(slots[i], damages[i]);
    }
    for (var i = 0; i < slots.length; i++) {
      LoreLavaLogic.applyDamage(slots[i], damages[i]);
    }
    displayCondition();
    if (!party.take(6).any((member) => member.isBattleActive)) gameOver();
  }

  /// `LOREMAIN.PAS:19-27`, including the no-spell `originposition` branch.
  static void enterWater({
    required int Function() waterWalkSteps,
    required void Function(int steps) setWaterWalkSteps,
    required void Function() scrollToParty,
    required int encounterFrequency,
    required int Function(int exclusiveUpperBound) random,
    required void Function() encounterEnemy,
    required void Function() restorePosition,
  }) {
    final steps = waterWalkSteps();
    if (steps > 0) {
      setWaterWalkSteps(steps - 1);
      scrollToParty();
      if (random(encounterFrequency * 30) == 0) encounterEnemy();
    } else {
      restorePosition();
    }
  }
}

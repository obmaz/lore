import 'dart:math';

import '../game/lore_world_manager.dart';
import '../models/party_member.dart';
import 'field_hotkeys.dart';
import 'lore_lava_logic.dart';
import 'lore_swamp_logic.dart';
import 'lore_source_memory.dart';

/// Source-shaped procedures from `LOREMAIN.PAS`.
///
/// Effects are callbacks so the procedure keeps Pascal's mutation, display,
/// random, and encounter order without depending on Flutter or Flame.
class LoreMainProcedures {
  LoreMainProcedures._();

  /// `LOREMAIN.Main`: these keys set `ok := true` with `x1 = y1 = 0`, so the
  /// current tile is dispatched after the menu or view procedure returns.
  static bool mainRedispatchesCurrentTile(FieldAction action) =>
      switch (action) {
        FieldAction.openMenu ||
        FieldAction.viewParty ||
        FieldAction.viewCharacter ||
        FieldAction.quickView ||
        FieldAction.castSpell ||
        FieldAction.extrasense ||
        FieldAction.rest ||
        FieldAction.gameOption => true,
        FieldAction.toggleSound || FieldAction.none => false,
      };

  /// The order of LOREMAIN `Main`'s four `if position = ...` blocks:
  /// town, ground, den, keep.
  static int positionRank(MapCategory? category) => switch (category) {
    MapCategory.town || null => 0,
    MapCategory.ground => 1,
    MapCategory.den => 2,
    MapCategory.keep => 3,
  };

  /// After the block for [startMap] ran, a map loaded inside it makes every
  /// later block whose position matches dispatch the arrival cell again.
  static bool dispatchesArrivalCell(int startMap, int currentMap) =>
      positionRank(LoreWorldManager.mapRegistry[currentMap]?.category) >
      positionRank(LoreWorldManager.mapRegistry[startMap]?.category);

  /// Shared body of the poison loop in `Move_Mode` and `enter_swamp`.
  /// Returns Pascal's `j`: the number of members whose poison reached 11.
  static int advancePoison(List<PartyMember> party) {
    var affected = 0;
    for (final member in party.take(6)) {
      if (member.name.isEmpty) continue;
      if (member.poison > 0) {
        member.poison = LorePascal.byte(member.poison + 1);
      }
      if (member.poison <= 10) continue;
      member.poison = 1;
      if (member.dead > 0 && member.dead < 100) {
        member.dead = LorePascal.integer(member.dead + 1);
      } else if (member.unconscious > 0) {
        member.unconscious = LorePascal.integer(member.unconscious + 1);
        if (member.unconscious >
            LorePascal.integer(member.endurance * member.battleLevel)) {
          member.dead = 1;
        }
      } else {
        member.hp = LorePascal.integer(member.hp - 1);
        if (member.hp <= 0) member.unconscious = 1;
      }
      affected++;
    }
    return affected;
  }

  /// `LOREMAIN.PAS:113-141`. Callbacks represent the original display,
  /// game-over, and battle boundaries; all conditions and mutations stay here.
  ///
  /// `DetectGameOver` blocks until `GameOver` returns (a reload or `<< 아니오 >>`),
  /// so the mind-read and encounter steps read the state after it.
  static Future<void> moveMode({
    required List<PartyMember> party,
    required void Function() scrollToParty,
    required void Function() displayHealthAndCondition,
    required Future<void> Function() gameOver,
    required int Function() mindReadSteps,
    required void Function(int steps) setMindReadSteps,
    required int Function() encounterFrequency,
    required int Function(int exclusiveUpperBound) random,
    required void Function() encounterEnemy,
  }) async {
    scrollToParty();
    final affected = advancePoison(party);
    if (affected > 0) displayHealthAndCondition();
    await detectGameOver(party, gameOver);
    final mindRead = mindReadSteps();
    if (mindRead > 0) setMindReadSteps(mindRead - 1);
    if (random(encounterFrequency() * 20) == 0) encounterEnemy();
  }

  /// `LORESUB.PAS:547-556` `DetectGameOver` (the caller's [gameOver] sets
  /// `party.etc[6] := 255` before running `GameOver`).
  static Future<void> detectGameOver(
    List<PartyMember> party,
    Future<void> Function() gameOver,
  ) async {
    if (!party.take(6).any((member) => member.isBattleActive)) {
      await gameOver();
    }
  }

  /// `LOREMAIN.PAS:29-75`. The six-slot poison roll is performed only after
  /// poison progression and only when swamp-walk has expired.
  static Future<void> enterSwamp({
    required List<PartyMember> party,
    required void Function() scrollToParty,
    required int Function() swampWalkSteps,
    required void Function(int steps) setSwampWalkSteps,
    required Random random,
    required void Function() showSwampWarning,
    required void Function(PartyMember member) showPoisonMessage,
    required void Function() displayCondition,
    required void Function() displayHealthAndCondition,
    required Future<void> Function() gameOver,
  }) async {
    scrollToParty();
    final affected = advancePoison(party);
    final steps = swampWalkSteps();
    if (steps > 0) {
      setSwampWalkSteps(steps - 1);
    } else {
      final poisoned = LoreSwampLogic.rollPoisonedSlots(party, random);
      showSwampWarning();
      for (final index in poisoned) {
        final member = party[index];
        showPoisonMessage(member);
        LoreSwampLogic.applyPoison(member);
      }
      displayCondition();
    }
    if (affected > 0) displayHealthAndCondition();
    await detectGameOver(party, gameOver);
  }

  /// `LOREMAIN.PAS:77-111`. Rolls damage for all six slots before showing
  /// messages and applying any damage, including damage to empty slots.
  static Future<void> enterLava({
    required List<PartyMember> party,
    required Random random,
    required void Function() scrollToParty,
    required void Function() showLavaWarning,
    required void Function(PartyMember member, int damage) showDamage,
    required void Function() displayCondition,
    required Future<void> Function() gameOver,
  }) async {
    scrollToParty();
    final slots = [
      for (var i = 0; i < 6; i++)
        i < party.length ? party[i] : PartyMember.blank(),
    ];
    final damages = LoreLavaLogic.rollDamages(slots, random);
    showLavaWarning();
    for (var i = 0; i < slots.length; i++) {
      if (slots[i].name.isNotEmpty) showDamage(slots[i], damages[i]);
    }
    for (var i = 0; i < slots.length; i++) {
      LoreLavaLogic.applyDamage(slots[i], damages[i]);
    }
    displayCondition();
    await detectGameOver(party, gameOver);
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

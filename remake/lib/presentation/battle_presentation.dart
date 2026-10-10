import '../models/monster.dart';
import '../models/party_member.dart';

enum BattleSide { party, enemy }

enum BattleEffect { weapon, magic, heal, status, esp, escape, enemy }

enum BattleFeedbackKind {
  damage,
  healing,
  resource,
  experience,
  status,
  outcome,
}

/// Presentation reads immutable before/after records. It never rolls dice or
/// applies damage/rewards; LoreBattle remains the owner of those mutations.
class BattleActorState {
  const BattleActorState({
    required this.name,
    required this.hp,
    required this.maxHp,
    required this.sp,
    required this.maxSp,
    required this.experience,
    required this.dead,
    required this.unconscious,
    required this.poisoned,
    required this.ac,
    required this.resistance,
    required this.special,
    required this.castLevel,
  });

  factory BattleActorState.party(PartyMember p) => BattleActorState(
    name: p.name,
    hp: p.hp,
    maxHp: p.maxHp,
    sp: p.sp,
    maxSp: p.maxSp,
    experience: p.experience,
    dead: p.dead != 0,
    unconscious: p.unconscious != 0,
    poisoned: p.poison != 0,
    ac: p.ac,
    resistance: p.resistance,
    special: 0,
    castLevel: p.magicLevel,
  );

  factory BattleActorState.enemy(Monster e) => BattleActorState(
    name: e.name,
    hp: e.hp,
    maxHp: e.maxHp,
    sp: 0,
    maxSp: 0,
    experience: 0,
    dead: e.isDead,
    unconscious: e.isUnconscious,
    poisoned: e.isPoisoned,
    ac: e.ac,
    resistance: e.resistance,
    special: e.special,
    castLevel: e.castLevel,
  );

  final String name;
  final int hp,
      maxHp,
      sp,
      maxSp,
      experience,
      ac,
      resistance,
      special,
      castLevel;
  final bool dead, unconscious, poisoned;
}

class BattleSnapshot {
  BattleSnapshot(List<PartyMember> party, List<Monster> enemies)
    : party = List.unmodifiable(party.take(6).map(BattleActorState.party)),
      enemies = List.unmodifiable(enemies.map(BattleActorState.enemy));

  final List<BattleActorState> party, enemies;
}

class BattleFeedback {
  const BattleFeedback(
    this.side,
    this.index,
    this.label, {
    this.positive = false,
    this.kind = BattleFeedbackKind.status,
  });
  final BattleSide side;
  final int index;
  final String label;
  final bool positive;
  final BattleFeedbackKind kind;
}

class BattleActionEvent {
  BattleActionEvent({
    required this.serial,
    required this.side,
    required this.actor,
    required this.effect,
    required this.title,
    required this.lines,
    required this.feedback,
    this.target,
    this.allTargets = false,
  });

  factory BattleActionEvent.between({
    required int serial,
    required BattleSide side,
    required int actor,
    required BattleEffect effect,
    required String title,
    required BattleSnapshot before,
    required BattleSnapshot after,
    required List<String> lines,
    int? target,
    bool allTargets = false,
  }) {
    final feedback = <BattleFeedback>[];
    void compare(
      BattleSide side,
      List<BattleActorState> old,
      List<BattleActorState> next,
    ) {
      for (var i = 0; i < next.length; i++) {
        final n = next[i];
        if (i >= old.length) {
          feedback.add(BattleFeedback(side, i, '소환'));
          continue;
        }
        final o = old[i];
        if (n.name != o.name) {
          feedback.add(BattleFeedback(side, i, '합류', positive: true));
        }
        final damage = o.hp - n.hp;
        if (damage != 0) {
          feedback.add(
            BattleFeedback(
              side,
              i,
              damage > 0 ? '−$damage' : '+${-damage}',
              positive: damage < 0,
              kind: damage > 0
                  ? BattleFeedbackKind.damage
                  : BattleFeedbackKind.healing,
            ),
          );
        }
        if (!o.dead && n.dead) {
          feedback.add(BattleFeedback(side, i, '격파'));
        } else if (!o.unconscious && n.unconscious) {
          feedback.add(BattleFeedback(side, i, '전투 불능'));
        } else if ((o.dead && !n.dead) || (o.unconscious && !n.unconscious)) {
          feedback.add(BattleFeedback(side, i, '부활', positive: true));
        }
        if (n.poisoned != o.poisoned) {
          feedback.add(
            BattleFeedback(
              side,
              i,
              n.poisoned ? '중독' : '해독',
              positive: !n.poisoned,
            ),
          );
        }
        if (n.ac != o.ac ||
            n.resistance != o.resistance ||
            n.special != o.special ||
            n.castLevel != o.castLevel) {
          feedback.add(BattleFeedback(side, i, '능력 변화'));
        }
        if (n.sp != o.sp) {
          feedback.add(
            BattleFeedback(
              side,
              i,
              'SP ${n.sp - o.sp > 0 ? '+' : ''}${n.sp - o.sp}',
              positive: n.sp > o.sp,
              kind: BattleFeedbackKind.resource,
            ),
          );
        }
        final xp = n.experience - o.experience;
        if (xp != 0) {
          feedback.add(
            BattleFeedback(
              side,
              i,
              'EXP ${xp > 0 ? '+' : ''}$xp',
              positive: true,
              kind: BattleFeedbackKind.experience,
            ),
          );
        }
      }
    }

    compare(BattleSide.party, before.party, after.party);
    compare(BattleSide.enemy, before.enemies, after.enemies);
    // Text-only outcomes (miss/resist/refusal) have no state delta. Keep their
    // source detail on the stage and add a short readable result by the target.
    for (final text in lines) {
      String? outcome;
      var outputSide = side == BattleSide.party
          ? BattleSide.enemy
          : BattleSide.party;
      var index = target ?? 0;
      if (text.contains('빗') ||
          text.contains('실패') ||
          text.contains('성공하지 못')) {
        outcome = '실패';
      } else if (text.contains('저지') ||
          text.contains('막았') ||
          text.contains('방어했다')) {
        outcome = '방어';
      } else if (text.contains('피했다')) {
        outcome = '회피';
      } else if (text.contains('부족') ||
          text.contains('능력이 없다') ||
          text.contains('사용할수') ||
          text.contains('사용할 수')) {
        outcome = '사용 불가';
        outputSide = side;
        index = actor;
      } else if (text.contains('통하지 않았다') || text.contains('흔들리지 않았다')) {
        outcome = '저항';
      }
      if (outcome == null) continue;
      final records = outputSide == BattleSide.party
          ? after.party
          : after.enemies;
      final named = records.indexWhere(
        (p) => p.name.isNotEmpty && text.contains(p.name),
      );
      if (named >= 0) index = named;
      feedback.add(
        BattleFeedback(
          outputSide,
          index,
          outcome,
          kind: BattleFeedbackKind.outcome,
        ),
      );
    }
    return BattleActionEvent(
      serial: serial,
      side: side,
      actor: actor,
      effect: effect,
      title: title,
      lines: List.unmodifiable(lines),
      feedback: List.unmodifiable(feedback),
      target: target,
      allTargets: allTargets,
    );
  }

  final int serial, actor;
  final BattleSide side;
  final BattleEffect effect;
  final String title;
  final List<String> lines;
  final List<BattleFeedback> feedback;
  final int? target;
  final bool allTargets;
}

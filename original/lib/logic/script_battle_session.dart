import '../data/lore_script.dart';
import '../models/monster.dart';
import 'lore_battle_progress.dart';

class ScriptBattleSessionResult {
  final LoreBattleProgressResult progress;
  final ScriptRun? continuation;
  final ScriptOutcome? appliedOutcome;
  final ScriptOutcome delta;
  final Set<int> defeatedEnemySlots;

  const ScriptBattleSessionResult({
    required this.progress,
    required this.continuation,
    required this.appliedOutcome,
    required this.delta,
    required this.defeatedEnemySlots,
  });
}

/// 전투 결과와 스크립트 후속 구간을 같은 적 명단으로 판정한다.
class ScriptBattleSession {
  ScriptBattleSession._();

  static ScriptBattleSessionResult resolve({
    required LoreBattleProgressState before,
    required LoreBattleEnd end,
    required List<Monster> enemies,
    ScriptRun? pendingScript,
    Set<int> inactiveDeadEnemySlots = const {},
    int goldEarned = 0,
    Iterable<String> victoryFlags = const [],
  }) {
    // Pascal `enemy[i].dead` (an hp <= 0 enemy is only unconscious) and, for
    // the two `enemy[3].hp <= 0` tests, the hp slots.
    final defeated = {
      if (pendingScript?.checksStoredDeadSlots == true)
        ...inactiveDeadEnemySlots,
      for (var i = 0; i < enemies.length; i++)
        if (enemies[i].isDead) i + 1,
    };
    final hpZero = {
      for (var i = 0; i < enemies.length; i++)
        if (enemies[i].hp <= 0) i + 1,
    };
    final keyEnemyDefeated =
        end == LoreBattleEnd.runAway &&
        (pendingScript?.isVictoryAfterRunAway(
              defeated,
              hpZeroEnemySlots: hpZero,
            ) ??
            false);
    final progress = LoreBattleProgress.resolve(
      before,
      end: end,
      enemyNames: enemies.map((enemy) => enemy.name),
      goldEarned: goldEarned,
      victoryFlags: victoryFlags,
      keyEnemyDefeatedOnEscape: keyEnemyDefeated,
    );
    final continuation = switch (end) {
      LoreBattleEnd.victory => pendingScript?.continueAfterBattle(
        defeatedEnemySlots: defeated,
      ),
      LoreBattleEnd.runAway => pendingScript?.continueAfterRunAway(
        defeatedEnemySlots: defeated,
        hpZeroEnemySlots: hpZero,
      ),
      LoreBattleEnd.defeat => pendingScript?.continueAfterDefeat(
        defeatedEnemySlots: defeated,
        hpZeroEnemySlots: hpZero,
      ),
    };
    final applied = pendingScript?.outcome;
    return ScriptBattleSessionResult(
      progress: progress,
      continuation: continuation,
      appliedOutcome: applied,
      delta: continuation == null || applied == null
          ? const ScriptOutcome()
          : continuation.outcome.since(applied),
      defeatedEnemySlots: defeated,
    );
  }
}

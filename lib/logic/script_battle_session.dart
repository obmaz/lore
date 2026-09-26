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
    int goldEarned = 0,
    Iterable<String> victoryFlags = const [],
  }) {
    final defeated = {
      for (var i = 0; i < enemies.length; i++)
        if (enemies[i].isDead || enemies[i].hp <= 0) i + 1,
    };
    final keyEnemyDefeated =
        end == LoreBattleEnd.runAway &&
        (pendingScript?.isVictoryAfterRunAway(defeated) ?? false);
    final progress = LoreBattleProgress.resolve(
      before,
      end: end,
      enemyNames: enemies.map((enemy) => enemy.name),
      goldEarned: goldEarned,
      victoryFlags: victoryFlags,
      keyEnemyDefeatedOnEscape: keyEnemyDefeated,
    );
    final continuation = switch (end) {
      LoreBattleEnd.victory => pendingScript?.continueAfterBattle(),
      LoreBattleEnd.runAway => pendingScript?.continueAfterRunAway(
        defeatedEnemySlots: defeated,
      ),
      LoreBattleEnd.defeat => null,
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

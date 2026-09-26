/// 전투 종료 뒤 게임 진행 상태에 적용할 결과.
enum LoreBattleEnd { victory, runAway, defeat }

class LoreBattleProgressState {
  final int gold;
  final int lastBattleResult;
  final Map<String, bool> flags;

  const LoreBattleProgressState({
    required this.gold,
    required this.lastBattleResult,
    required this.flags,
  });
}

class LoreBattleProgressResult {
  final LoreBattleProgressState state;
  final List<String> newlySetFlags;
  final String? bossMessage;

  const LoreBattleProgressResult({
    required this.state,
    required this.newlySetFlags,
    required this.bossMessage,
  });
}

/// LOREBATT.PAS의 승리·도주·전멸 후 진행 변경. 화면과 매니저에 의존하지 않는다.
class LoreBattleProgress {
  LoreBattleProgress._();

  static LoreBattleProgressResult resolve(
    LoreBattleProgressState before, {
    required LoreBattleEnd end,
    required Iterable<String> enemyNames,
    int goldEarned = 0,
    Iterable<String> victoryFlags = const [],
    bool keyEnemyDefeatedOnEscape = false,
  }) {
    final flags = Map<String, bool>.from(before.flags);
    final newlySetFlags = <String>[];

    void setFlag(String flag) {
      if (flags[flag] == true) return;
      flags[flag] = true;
      newlySetFlags.add(flag);
    }

    if (end == LoreBattleEnd.victory) {
      for (final flag in victoryFlags) {
        setFlag(flag);
      }
    }

    String? bossMessage;
    if (end == LoreBattleEnd.victory ||
        (end == LoreBattleEnd.runAway && keyEnemyDefeatedOnEscape)) {
      final boss = _bossMilestone(enemyNames);
      if (boss != null) {
        setFlag(boss.$1);
        bossMessage = boss.$2;
      }
    }

    return LoreBattleProgressResult(
      state: LoreBattleProgressState(
        gold: before.gold + (end == LoreBattleEnd.victory ? goldEarned : 0),
        lastBattleResult: switch (end) {
          LoreBattleEnd.victory => 0,
          LoreBattleEnd.runAway => 2,
          LoreBattleEnd.defeat => 255,
        },
        flags: flags,
      ),
      newlySetFlags: newlySetFlags,
      bossMessage: bossMessage,
    );
  }

  static (String, String)? _bossMilestone(Iterable<String> enemyNames) {
    // 원본 보스전에는 일반 몬스터가 앞에 배치되기도 한다.
    for (final name in enemyNames) {
      switch (name) {
        case 'Major Mummy':
          return (
            'bossMajorMummyDefeated',
            '★ Major Mummy를 물리쳤습니다! LASTDITCH 성주에게 승전보를 전하십시오!',
          );
        case 'ArchiGagoyle':
          return (
            'bossArchiGagoyleDefeated',
            '★ ArchiGagoyle을 물리쳤습니다! GAIA TERRA 성주에게 승전보를 전하십시오!',
          );
        case 'Huge Dragon':
          return (
            'bossHugeDragonDefeated',
            '★ Huge Dragon을 물리쳤습니다! WATER FIELD 성주에게 승전보를 전하십시오!',
          );
      }
      if (name.startsWith('Hidra')) {
        return (
          'bossHidraDefeated',
          '★ 삼두룡 Hidra를 물리쳤습니다! WATER FIELD 성주에게 승전보를 전하십시오!',
        );
      }
    }
    return null;
  }
}

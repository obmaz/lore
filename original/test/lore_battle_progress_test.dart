import 'support/legacy_json_fixture_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/logic/lore_battle_progress.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Major Mummy가 세 번째 적이어도 승리와 도주 후 격퇴를 기록한다', () async {
    final engine = LegacyJsonFixtureEngine();
    await engine.load();
    final run = engine.startById(
      'spec-11-L465-1x',
      const ScriptContext(questSteps: {'lastditch': 1}),
    )!;
    expect(run.awaitingBattle, isTrue);
    final names = List<String>.filled(run.outcome.battleMonsters.length, '');
    for (final override in run.outcome.battleOverrides) {
      names[(override['index'] as int) - 1] = override['name'] as String;
    }
    expect(names, ['Sphinx', 'Sphinx', 'Major Mummy']);

    const before = LoreBattleProgressState(
      gold: 1200,
      lastBattleResult: 2,
      flags: {},
    );
    final victory = LoreBattleProgress.resolve(
      before,
      end: LoreBattleEnd.victory,
      enemyNames: names,
      goldEarned: 300,
      victoryFlags: ['etc33_bit1'],
    );
    expect((victory.state.gold, victory.state.lastBattleResult), (1500, 0));
    expect(
      victory.newlySetFlags,
      containsAll(['etc33_bit1', 'bossMajorMummyDefeated']),
    );
    expect(before.flags, isEmpty);

    expect(run.isVictoryAfterRunAway({3}), isTrue);
    final escaped = LoreBattleProgress.resolve(
      before,
      end: LoreBattleEnd.runAway,
      enemyNames: names,
      victoryFlags: ['etc33_bit1'],
      keyEnemyDefeatedOnEscape: true,
    );
    expect(escaped.state.lastBattleResult, 2);
    expect(escaped.state.gold, 1200);
    expect(escaped.state.flags['bossMajorMummyDefeated'], isTrue);
    expect(escaped.state.flags['etc33_bit1'], isNull);
  });

  test('도주와 전멸은 승리 플래그를 지급하지 않는다', () {
    const before = LoreBattleProgressState(
      gold: 900,
      lastBattleResult: 0,
      flags: {'met': true},
    );
    for (final end in [LoreBattleEnd.runAway, LoreBattleEnd.defeat]) {
      final result = LoreBattleProgress.resolve(
        before,
        end: end,
        enemyNames: ['Zombie', 'Zombie', 'ArchiGagoyle'],
        goldEarned: 300,
        victoryFlags: ['reward'],
      );
      expect(result.state.gold, 900);
      expect(result.state.flags, {'met': true});
      expect(
        result.state.lastBattleResult,
        end == LoreBattleEnd.runAway ? 2 : 255,
      );
    }
  });

  test('세 번째 ArchiGagoyle와 Hidra 머리도 보스로 식별한다', () {
    const before = LoreBattleProgressState(
      gold: 0,
      lastBattleResult: 0,
      flags: {},
    );
    final gargoyle = LoreBattleProgress.resolve(
      before,
      end: LoreBattleEnd.victory,
      enemyNames: ['Zombie', 'Zombie', 'ArchiGagoyle'],
    );
    final hidra = LoreBattleProgress.resolve(
      before,
      end: LoreBattleEnd.victory,
      enemyNames: ["Hidra's Head 1", "Hidra's Head 2"],
    );
    expect(gargoyle.state.flags['bossArchiGagoyleDefeated'], isTrue);
    expect(hidra.state.flags['bossHidraDefeated'], isTrue);
  });
}

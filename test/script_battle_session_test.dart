import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/logic/lore_battle_progress.dart';
import 'package:lore/logic/script_battle_session.dart';
import 'package:lore/models/monster.dart';

/// `dead` is Pascal `enemy[i].dead`; an hp <= 0 enemy is only unconscious.
Monster enemy(String name, {int hp = 10, bool dead = false}) => Monster(
  eNumber: 1,
  name: name,
  strength: 1,
  mentality: 1,
  endurance: 10,
  resistance: 1,
  agility: 1,
  accArms: 1,
  accMagic: 1,
  ac: 0,
  special: 0,
  castLevel: 0,
  specialCastLevel: 0,
  level: 1,
  hp: hp,
)..isDead = dead;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LoreScriptEngine engine;
  setUp(() async {
    engine = LoreScriptEngine();
    await engine.load();
  });

  const before = LoreBattleProgressState(
    gold: 1200,
    lastBattleResult: 2,
    flags: {},
  );

  test('Major Mummy 승리는 전투 보상과 후속 퀘스트를 한 번씩 적용한다', () {
    final run = engine.startStep(
      11,
      30,
      24,
      const ScriptContext(questSteps: {'lastditch': 1}),
    )!;
    final result = ScriptBattleSession.resolve(
      before: before,
      end: LoreBattleEnd.victory,
      enemies: [enemy('Sphinx'), enemy('Sphinx'), enemy('Major Mummy')],
      pendingScript: run,
      goldEarned: 300,
      victoryFlags: run.outcome.battleVictoryFlags,
    );

    expect(result.progress.state.gold, 1500);
    expect(result.progress.state.lastBattleResult, 0);
    expect(result.progress.state.flags['bossMajorMummyDefeated'], isTrue);
    expect(result.continuation?.awaitingBattle, isFalse);
    expect(result.delta.questChanges, isNotEmpty);
    expect(result.delta.battleMonsters, isEmpty); // 첫 전투를 다시 시작하지 않는다.
    expect(result.appliedOutcome, same(run.outcome));
    expect(before.flags, isEmpty);
  });

  test('보스 생존 도주는 진행하지 않고, 세 번째 슬롯 격퇴 도주는 진행한다', () {
    final run = engine.startStep(
      11,
      30,
      24,
      const ScriptContext(questSteps: {'lastditch': 1}),
    )!;
    final alive = ScriptBattleSession.resolve(
      before: before,
      end: LoreBattleEnd.runAway,
      enemies: [enemy('Sphinx'), enemy('Sphinx'), enemy('Major Mummy')],
      pendingScript: run,
    );
    expect(alive.defeatedEnemySlots, isEmpty);
    expect(alive.progress.state.flags['bossMajorMummyDefeated'], isNull);
    expect(alive.delta.questChanges, isEmpty);

    final defeated = ScriptBattleSession.resolve(
      before: before,
      end: LoreBattleEnd.runAway,
      enemies: [
        enemy('Sphinx'),
        enemy('Sphinx'),
        enemy('Major Mummy', hp: 0, dead: true),
      ],
      pendingScript: run,
    );
    expect(defeated.defeatedEnemySlots, {3});
    expect(defeated.progress.state.gold, 1200);
    expect(defeated.progress.state.flags['bossMajorMummyDefeated'], isTrue);
    expect(defeated.delta.questChanges, isNotEmpty);
  });

  test('SWAMP KEEP 수문장 둘을 격퇴하고 도주하면 관문 완료를 기록한다', () {
    final run = engine.startById('keep1-exit-guard', const ScriptContext())!;
    final result = ScriptBattleSession.resolve(
      before: before,
      end: LoreBattleEnd.runAway,
      enemies: [
        enemy('Guardian 1', hp: 0, dead: true),
        enemy('Guardian 2', hp: 0, dead: true),
        for (var i = 0; i < 5; i++) enemy('Minion $i'),
      ],
      pendingScript: run,
    );
    expect(result.defeatedEnemySlots, {1, 2});
    expect(result.delta.setFlags, [
      'keep1LeftGuardianDefeated',
      'keep1RightGuardianDefeated',
      'swampKeepBossDefeated',
    ]);
    expect(result.continuation?.awaitingBattle, isFalse);
  });

  test('최후 전투는 도주 재전투를 만들고 보스 격퇴 시에만 끝낸다', () {
    final run = engine.startStep(
      26,
      26,
      20,
      const ScriptContext(tileAtPlayer: 0),
    )!;
    final roster = [for (var i = 1; i <= 7; i++) enemy('Enemy $i')];
    final retry = ScriptBattleSession.resolve(
      before: before,
      end: LoreBattleEnd.runAway,
      enemies: roster,
      pendingScript: run,
    );
    expect(retry.continuation?.awaitingBattle, isTrue);
    expect(retry.delta.battleReuseExisting, isTrue);
    expect(retry.delta.setFlags, isEmpty);

    final escaped = ScriptBattleSession.resolve(
      before: before,
      end: LoreBattleEnd.runAway,
      enemies: [...roster.take(6), enemy('Enemy 7', hp: 0, dead: true)],
      pendingScript: run,
    );
    expect(escaped.continuation?.awaitingBattle, isFalse);
    expect(escaped.delta.setFlags, contains('bossNecromancerDefeated'));

    final defeat = ScriptBattleSession.resolve(
      before: before,
      end: LoreBattleEnd.defeat,
      enemies: roster,
      pendingScript: run,
    );
    expect(defeat.progress.state.lastBattleResult, 255);
    expect(defeat.continuation, isNull);
    expect(defeat.delta.setFlags, isEmpty);
  });
}

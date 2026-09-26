import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LoreScriptEngine engine;
  setUp(() async {
    engine = LoreScriptEngine();
    await engine.load();
  });

  test('맵 11의 창은 획득 전에는 지급되고 획득 플래그 뒤에는 빠진다', () {
    final before = engine.startStep(11, 30, 44, const ScriptContext())!;
    expect(before.script.id, 'oedipus-spear');
    expect(before.outcome.equips.single.index, 3);
    expect(before.outcome.setFlags, contains('oedipusSpearTaken'));

    final after = engine.startStep(
      11,
      30,
      44,
      const ScriptContext(flags: {'oedipusSpearTaken'}),
    );
    expect(after?.outcome.equips, isNull);
  });

  test('맵 13 Gorgon은 특수 타일에서만 전투하며 도주 결과가 갈린다', () {
    final blocked = engine.startStep(
      13,
      81,
      68,
      const ScriptContext(tileAtPlayer: 41),
    );
    expect(blocked?.outcome.battleMonsters, isNull);

    final active = engine.startStep(
      13,
      81,
      68,
      const ScriptContext(tileAtPlayer: 52),
    )!;
    expect(active.outcome.battleMonsters, [50, 51, 52]);
    expect(
      active.continueAfterRunAway().outcome.since(active.outcome).nudges,
      isNotEmpty,
    );
    expect(
      active
          .continueAfterRunAway(defeatedEnemySlots: {3})
          .outcome
          .since(active.outcome)
          .nudges,
      isEmpty,
    );
  });

  test('맵 26 최후 이벤트는 타일 0에서만 시작해 보스 격퇴 도주가 결말로 간다', () {
    expect(
      engine.startStep(26, 26, 20, const ScriptContext(tileAtPlayer: 44)),
      isNull,
    );
    final active = engine.startStep(
      26,
      26,
      20,
      const ScriptContext(tileAtPlayer: 0),
    )!;
    expect(active.awaitingBattle, isTrue);
    expect(active.continueAfterRunAway().awaitingBattle, isTrue);
    final ending = active.continueAfterRunAway(defeatedEnemySlots: {7});
    expect(ending.awaitingBattle, isFalse);
    expect(
      ending.outcome.since(active.outcome).setFlags,
      contains('bossNecromancerDefeated'),
    );
  });

  test('동일 ID 라바 게이트는 키·수문장 상태에 따라 봉쇄·전투·통과한다', () {
    final locked = engine.startById(
      'portal-21-22-lavagate',
      const ScriptContext(),
    )!;
    expect(locked.outcome.blockMove, isTrue);
    expect(locked.outcome.battleMonsters, isEmpty);

    const keys = {'lavaGateKeyLeft', 'lavaGateKeyRight'};
    final guarded = engine.startById(
      'portal-21-22-lavagate',
      const ScriptContext(flags: keys),
    )!;
    expect(guarded.awaitingBattle, isTrue);
    expect(guarded.outcome.battleMonsters, [65, 64]);

    final cleared = engine.startById(
      'portal-21-22-lavagate',
      const ScriptContext(
        flags: {
          ...keys,
          'lavaGateLeftGuardianDefeated',
          'lavaGateRightGuardianDefeated',
        },
      ),
    )!;
    expect(cleared.awaitingBattle, isFalse);
    expect(cleared.outcome.blockMove, isFalse);
    expect(cleared.outcome.setFlags, contains('lavaGateGuardiansCleared'));
  });
}

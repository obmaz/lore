// 원작 `LORESPEC.PAS`(좌표 이벤트) 이관 검증.
//
// - 좌표 조건(`on(x,y)`)별로 스크립트가 나뉘고, 진행 플래그로 갈라진다.
// - 옮기지 못한 효과(전투/장비 등)를 가진 좌표는 손으로 쓴 스크립트를
//   그대로 쓰고, 옮긴 쪽은 `disabled` 로 보관만 한다.
// - 맵 26(Necromancer 최후)처럼 한 칸에서 이어지는 연출은 시퀀스 스크립트로
//   옮기되 원작과 같이 `map[x,y] = 0` 인 칸에서만 발동한다.
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    LoreScriptEngine.instance.resetForTest();
    await LoreScriptEngine.instance.load();
  });
  tearDown(() => LoreScriptEngine.instance.resetForTest());

  test('원작 LORESPEC 좌표 이벤트가 스크립트로 들어와 있다', () {
    final ids = LoreScriptEngine.instance.scripts.map((s) => s.id).toSet();
    expect(ids.where((id) => id.startsWith('spec-')).length, greaterThan(100));
  });

  test('맵 13 피라미드 장면과 Gorgon 전투가 실제로 실행된다', () {
    final engine = LoreScriptEngine.instance;
    expect(
      engine.startStep(13, 80, 71, const ScriptContext(tileAtPlayer: 41)),
      isNull,
    );
    final chapters = engine.startStep(
      13,
      80,
      71,
      const ScriptContext(tileAtPlayer: 52),
    );
    expect(chapters, isNotNull);
    final outcome = chapters!.outcome;
    expect(outcome.messages, contains('CHAPTER 4'));
    expect(outcome.tileAreas.map((a) => a.onlyIf), containsAll([52, 40, 42]));
    expect((outcome.teleportX, outcome.teleportY), (81, 77));
    final gorgon = engine.startStep(
      13,
      81,
      68,
      const ScriptContext(tileAtPlayer: 52),
    )!;
    expect(gorgon.outcome.battleMonsters, [50, 51, 52]);
    expect(gorgon.outcome.battleOverrides, hasLength(3));
    expect(gorgon.outcome.battleVictoryFlags, contains('etc38_bit5'));
    expect(gorgon.continueAfterRunAway().outcome.nudges.single.dy, 1);
    expect(
      gorgon.continueAfterRunAway(defeatedEnemySlots: {3}).outcome.nudges,
      isEmpty,
    );
  });

  test('맵 26 최후 연출은 map[x,y]=0 인 칸에서만 발동한다', () {
    final seq = LoreScriptEngine.instance.scripts.firstWhere(
      (s) => s.id.startsWith('spec-26-') && s.id.endsWith('-seq'),
    );
    expect(seq.require.tileAtPlayerZero, isTrue);
    // 원작 `Print(13,' 당신들이 나를 없에겠다고 온자들인가?')` 문구가 살아 있다.
    expect(seq.steps.any((st) => st.text == ' 당신들이 나를 없에겠다고 온자들인가?'), isTrue);
    expect(
      seq.steps.any((st) => st.text == ' 욱!!! 역시 너희들의 능력으로 여기까지 뚫고'),
      isTrue,
    );

    // 타일이 0이 아니면 걸리지 않는다.
    expect(
      LoreScriptEngine.instance.startStep(
        26,
        26,
        20,
        const ScriptContext(tileAtPlayer: 44),
      ),
      isNull,
    );

    final battle = LoreScriptEngine.instance.startStep(
      26,
      26,
      20,
      const ScriptContext(tileAtPlayer: 0),
    )!;
    expect(battle.awaitingBattle, isTrue);
    expect(battle.outcome.battleMonsters, [69, 70, 71, 72, 73, 74, 75]);
    expect(battle.outcome.setFlags, isEmpty);
    final retry = battle.continueAfterRunAway();
    expect(retry.awaitingBattle, isTrue);
    expect(retry.outcome.since(battle.outcome).battleReuseExisting, isTrue);
    expect(retry.outcome.messages.last, '없다는 점이 안타깝군.');
    final escapedAfterBoss = battle.continueAfterRunAway(
      defeatedEnemySlots: {7},
    );
    expect(escapedAfterBoss.awaitingBattle, isFalse);
    expect(
      escapedAfterBoss.outcome.setFlags,
      contains('bossNecromancerDefeated'),
    );
    expect(
      battle.continueAfterBattle().outcome.setFlags,
      contains('bossNecromancerDefeated'),
    );
  });

  test('Major Mummy는 도망쳐도 보스를 쓰러뜨렸으면 임무가 진행된다', () {
    final mummy = LoreScriptEngine.instance.startStep(
      11,
      30,
      24,
      const ScriptContext(questSteps: {'lastditch': 1}),
    )!;
    expect(mummy.awaitingBattle, isTrue);
    expect(mummy.isVictoryAfterRunAway({3}), isTrue);
    expect(mummy.continueAfterRunAway().outcome.questChanges, isEmpty);
    expect(
      mummy.continueAfterRunAway(defeatedEnemySlots: {3}).outcome.questChanges,
      isNotEmpty,
    );
  });

  test('옮기지 못한 조건을 가진 분기는 실행하지 않고 보관만 한다', () {
    final disabled = LoreScriptEngine.instance.scripts
        .where((s) => s.id.startsWith('spec-'))
        .where((s) => s.disabled)
        .toList();
    expect(disabled, isNotEmpty);
    // 보관된 문구는 남아 있다(원문 대조용).
    expect(
      disabled.any(
        (s) => s.steps.any((st) => (st.text ?? '').contains('라바 게이트를 열수가 없다')),
      ),
      isTrue,
    );
  });

  test('맵 4(26,16) Draconian 분기는 진행 플래그로 갈라진다', () {
    final variants = LoreScriptEngine.instance.scripts
        .where((s) => s.map == 4 && s.x == 26 && s.y == 16)
        .toList();
    expect(variants.length, greaterThanOrEqualTo(3));
    // 첫 방문(강의) / 재방문(동료 권유) / 이미 동료(짧은 인사) 세 갈래.
    final lecture = variants.firstWhere(
      (s) => s.steps.length > 40,
      orElse: () => variants.first,
    );
    expect(
      lecture.steps.any((st) => (st.text ?? '').contains('나는 Draconian이라고 하오')),
      isTrue,
    );
  });

  test('옮긴 스크립트가 전투·동료·장비·횃불·밀기 스텝까지 담고 있다', () {
    final specs = LoreScriptEngine.instance.scripts
        .where((s) => s.id.startsWith('spec-'))
        .expand((s) => s.steps)
        .toList();
    final kinds = specs.map((s) => s.kind).toSet();
    for (final kind in const [
      'battle',
      'join',
      'equip',
      'torch',
      'nudge',
      'setTileArea',
      'teleport',
      'choice',
    ]) {
      expect(kinds.contains(kind), isTrue, reason: '$kind 스텝이 없다');
    }

    // 원작 `joinenemy(i,43)` → 몬스터 43 이 전투 목록에 들어간다.
    final battles = specs.where((s) => s.kind == 'battle').toList();
    expect(battles.any((b) => (b.monsters ?? const []).contains(43)), isTrue);
    // 원작 `join(9,k)` → Polaris, `join(43,k)` → Spica
    final joins = specs
        .where((s) => s.kind == 'join')
        .map((s) => s.key)
        .toSet();
    expect(joins.contains('polaris') || joins.contains('spica'), isTrue);
  });

  test('원작 1회성은 party.etc 비트로 관리된다 (금화 재획득 불가)', () {
    final engine = LoreScriptEngine.instance;
    final first = engine.startStep(9, 10, 24, const ScriptContext())!;
    expect(first.outcome.goldDelta, 5000);
    // 원작 `party.etc[35] := party.etc[35] or bit1`
    expect(first.outcome.setFlags, contains('etc35_bit1'));

    // 비트가 켜진 상태에서는 같은 보상이 다시 나오지 않는다.
    expect(
      engine.startStep(9, 10, 24, const ScriptContext(flags: {'etc35_bit1'})),
      isNull,
    );
  });
}

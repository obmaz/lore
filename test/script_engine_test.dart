import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/logic/lore_join.dart';

/// 게임 본편과 같이 **현재 플래그**로 스크립트 컨텍스트를 만든다.
/// 원작 좌표 이벤트의 1회성은 `party.etc` 비트로 관리되므로, 고정 컨텍스트로는
/// 재진입 판정을 확인할 수 없다.
ScriptContext _liveCtx() {
  final flags = LoreDialogueManager.instance
      .getFlagsCopy()
      .entries
      .where((e) => e.value)
      .map((e) => e.key)
      .toSet();
  return ScriptContext(
    flags: flags,
    questSteps: LoreDialogueManager.instance.questSteps,
  );
}

class _MissingBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => throw Exception('asset not found');
}

/// JSON 스크립트 엔진 검증.
///
/// 원작 LORESPEC.PAS / LORETALK.PAS의 좌표 이벤트를 `assets/data/scripts.json`으로
/// 옮기고, 엔진이 보상/조건/선택지/1회성을 정확히 처리하는지 확인한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const noCtx = ScriptContext();
  const learned = ScriptContext(flags: {'specialMagicLearned'});

  setUp(() => LoreScriptEngine.instance.resetForTest());
  tearDown(() => LoreScriptEngine.instance.resetForTest());

  group('JSON 스크립트 엔진 (assets/data/scripts.json)', () {
    test('선택지를 이어 실행할 때 앞 구간의 대사와 보상을 다시 적용하지 않는다', () async {
      await LoreScriptEngine.instance.load();

      final talk = LoreScriptEngine.instance.startStep(12, 12, 48, noCtx)!;
      final afterTalk = talk.choose(1);
      final talkDelta = afterTalk.outcome.since(talk.outcome);
      expect(talk.outcome.messages, hasLength(8));
      expect(talkDelta.messages, hasLength(5));
      expect(talkDelta.events, hasLength(5));
      expect(talkDelta.messages.first, startsWith(' 일행은 그에게'));
      expect(talkDelta.foodDelta, -5);
      expect(talkDelta.recruits, isEmpty);
      expect(talkDelta.rigelBlessing, isTrue);

      // DEN7의 퀴즈는 걸음(step) 이벤트 안에서 선택지를 표시해야 한다.
      final quiz = LoreScriptEngine.instance.startStep(20, 24, 54, noCtx)!;
      expect(quiz.hasPendingChoice, isTrue);
      final answer = quiz.choose(1);
      final answerDelta = answer.outcome.since(quiz.outcome);
      expect(answerDelta.messages, hasLength(1));
      expect(answerDelta.events, hasLength(1));
      expect(answerDelta.messages.single, anyOf('정답이다!', '오답이다!'));
      expect(quiz.outcome.messages.single, startsWith('문>'));
    });

    test('선택지 이후의 효과만 차분으로 계산한다', () {
      const before = ScriptOutcome(
        messages: ['소개'],
        goldDelta: 100,
        setFlags: ['met'],
        questChanges: [(name: 'water', set: null, inc: 1)],
        tileChanges: [(map: null, x: 1, y: 2, tile: 44, ifZero: null)],
      );
      const after = ScriptOutcome(
        messages: ['소개', '선택'],
        goldDelta: 150,
        setFlags: ['met', 'accepted'],
        questChanges: [
          (name: 'water', set: null, inc: 1),
          (name: 'gaia', set: 2, inc: null),
        ],
        tileChanges: [
          (map: null, x: 1, y: 2, tile: 44, ifZero: null),
          (map: null, x: 3, y: 4, tile: 45, ifZero: null),
        ],
      );
      final delta = after.since(before);
      expect(delta.messages, ['선택']);
      expect(delta.goldDelta, 50);
      expect(delta.setFlags, ['accepted']);
      expect(delta.questChanges.single.name, 'gaia');
      expect(delta.tileChanges.single.x, 3);
    });

    test('황금의 봉인을 얻으면 원작처럼 (18,9) 통로가 열린다', () async {
      await LoreScriptEngine.instance.load();
      final outcome = LoreScriptEngine.instance
          .startStep(12, 18, 10, noCtx)!
          .outcome;
      expect(outcome.setFlags, contains('goldenSealFound'));
      expect(outcome.tileChanges.single.x, 18);
      expect(outcome.tileChanges.single.y, 9);
      expect(outcome.tileChanges.single.tile, 0);
    });

    test('GROUND 1 식량은 한 번만 지급하고 특수 칸에서 되돌린다', () async {
      await LoreScriptEngine.instance.load();
      final engine = LoreScriptEngine.instance;
      final first = engine.startStep(
        1,
        42,
        84,
        const ScriptContext(tileAtPlayer: 0),
      )!;
      expect(first.outcome.foodDelta, 100);
      expect(first.outcome.setFlags, contains('etc32_bit8'));
      expect(first.outcome.stepBack, isTrue);

      final later = engine.startStep(
        1,
        42,
        84,
        const ScriptContext(flags: {'etc32_bit8'}, tileAtPlayer: 0),
      )!;
      expect(later.outcome.foodDelta, 0);
      expect(later.outcome.messages.single, contains('아무것도'));
      expect(later.outcome.stepBack, isTrue);
    });

    test('지진 동굴의 보물은 지정된 네 좌표에서만 나온다', () async {
      await LoreScriptEngine.instance.load();
      final engine = LoreScriptEngine.instance;
      expect(
        engine.startStep(15, 25, 50, const ScriptContext(tileAtPlayer: 0)),
        isNull,
      );
      final treasure = engine.startStep(
        15,
        10,
        48,
        const ScriptContext(tileAtPlayer: 0),
      )!;
      expect(treasure.outcome.goldDelta, 6000);
    });

    test('KEEP2 수문장 칸은 일반 습격에서 제외하고 일반 칸은 40으로 바뀐다', () async {
      await LoreScriptEngine.instance.load();
      final engine = LoreScriptEngine.instance;
      expect(
        engine.startStep(
          22,
          25,
          25,
          const ScriptContext(flags: {'keep2GuardsCleared'}),
        ),
        isNull,
      );

      final ambush = engine.startStep(22, 43, 25, noCtx)!;
      expect(ambush.outcome.battleMonsters, List.filled(5, 60));
      expect(ambush.continueAfterBattle().outcome.playerTiles.single.tile, 40);
      expect(ambush.continueAfterRunAway().outcome.playerTiles.single.tile, 40);
    });

    test('최종 방에 진입하면 원작처럼 입구 뒤쪽을 타일 16으로 막는다', () async {
      await LoreScriptEngine.instance.load();
      final run = LoreScriptEngine.instance.startEnter(26, noCtx)!;
      final area = run.outcome.tileAreas.single;
      expect((area.map, area.xMin, area.xMax), (26, 24, 26));
      expect((area.yMin, area.yMax, area.tile), (16, 19, 16));
    });

    test('SWAMP KEEP 남쪽 관문은 열쇠와 생존 수문장을 검사한다', () async {
      final engine = LoreScriptEngine.instance;
      await engine.load();
      const id = 'portal-21-22-lavagate';
      final blocked = engine.startById(id, noCtx)!;
      expect(blocked.outcome.blockMove, isTrue);

      const keys = ScriptContext(
        flags: {'lavaGateKeyLeft', 'lavaGateKeyRight'},
      );
      final both = engine.startById(id, keys)!;
      expect(both.outcome.battleMonsters, [65, 64]);
      expect(both.awaitingBattle, isTrue);
      final escaped = both.continueAfterRunAway(defeatedEnemySlots: {1});
      expect(
        escaped.outcome.since(both.outcome).setFlags,
        contains('lavaGateLeftGuardianDefeated'),
      );
      expect(escaped.outcome.blockMove, isFalse);

      const leftDead = ScriptContext(
        flags: {
          'lavaGateKeyLeft',
          'lavaGateKeyRight',
          'lavaGateLeftGuardianDefeated',
        },
      );
      final remaining = engine.startById(id, leftDead)!;
      expect(remaining.outcome.battleMonsters, [64]);
      expect(
        remaining.continueAfterBattle().outcome.setFlags,
        contains('lavaGateRightGuardianDefeated'),
      );
      expect(
        remaining.outcome.battleVictoryFlags,
        contains('lavaGateGuardiansCleared'),
      );

      const allDead = ScriptContext(
        flags: {
          'lavaGateKeyLeft',
          'lavaGateKeyRight',
          'lavaGateLeftGuardianDefeated',
          'lavaGateRightGuardianDefeated',
        },
      );
      final cleared = engine.startById(id, allDead)!;
      expect(cleared.outcome.battleMonsters, isEmpty);
      expect(cleared.outcome.setFlags, contains('lavaGateGuardiansCleared'));

      expect(engine.startEnter(22, noCtx), isNull);
      expect(
        engine.startEnter(22, const ScriptContext(enteredFromMap: 5)),
        isNull,
      );
      final speech = engine.startEnter(
        22,
        const ScriptContext(enteredFromMap: 21),
      )!;
      expect(speech.outcome.battleMonsters, isEmpty);
      expect(speech.outcome.setFlags, contains('ancientEvilSpeechGiven'));
      expect(
        engine.startEnter(
          22,
          const ScriptContext(
            enteredFromMap: 21,
            flags: {'ancientEvilSpeechGiven'},
          ),
        ),
        isNull,
      );
    });

    test('Frost Dragon은 일곱 자리 중 2~6번에 섞이고 도망치면 진입이 취소된다', () async {
      final engine = LoreScriptEngine.instance;
      await engine.load();
      final run = engine.startById('portal-5-23-frostdragon', noCtx)!;
      expect(run.awaitingBattle, isTrue);
      expect(run.outcome.battleMonsters, hasLength(7));
      final slot = run.outcome.battleMonsters.indexOf(69) + 1;
      expect(slot, inInclusiveRange(2, 6));
      expect(run.outcome.battleMonsters.where((id) => id == 54), hasLength(6));
      expect(
        run.continueAfterRunAway().outcome.since(run.outcome).blockMove,
        isTrue,
      );
      expect(run.outcome.battleVictoryFlags, contains('frostDragonDefeated'));
    });

    test('SWAMP KEEP 출구는 남은 수문장만 재소환한다', () async {
      final engine = LoreScriptEngine.instance;
      await engine.load();
      const id = 'keep1-exit-guard';
      final first = engine.startById(id, noCtx)!;
      expect(first.outcome.battleMonsters, [55, 56, 35, 35, 35, 35, 35]);
      expect(first.awaitingBattle, isTrue);
      expect(
        first
            .continueAfterRunAway(defeatedEnemySlots: {1})
            .outcome
            .since(first.outcome)
            .setFlags,
        contains('keep1LeftGuardianDefeated'),
      );

      final remaining = engine.startById(
        id,
        const ScriptContext(flags: {'keep1LeftGuardianDefeated'}),
      )!;
      expect(remaining.outcome.battleMonsters, [56, 35, 35, 35, 35, 35]);
      expect(
        remaining.continueAfterBattle().outcome.setFlags,
        contains('keep1RightGuardianDefeated'),
      );
      expect(
        remaining.outcome.battleVictoryFlags,
        contains('swampKeepBossDefeated'),
      );

      final noGuard = engine.startById(
        id,
        const ScriptContext(
          flags: {'keep1LeftGuardianDefeated', 'keep1RightGuardianDefeated'},
        ),
      )!;
      expect(noGuard.outcome.blockMove, isTrue);
      expect(noGuard.outcome.setFlags, contains('swampKeepBossDefeated'));
      expect(
        engine.startById(
          id,
          const ScriptContext(flags: {'swampKeepBossDefeated'}),
        ),
        isNull,
      );
    });

    test('두 봉인 던전의 완료 보상이 라바 게이트 열쇠가 된다', () async {
      final engine = LoreScriptEngine.instance;
      await engine.load();
      final left = engine.startStep(
        19,
        14,
        6,
        const ScriptContext(flags: {'evilSealRoom1'}),
      )!;
      expect(left.awaitingBattle, isTrue);
      expect(
        left.continueAfterBattle().outcome.setFlags,
        contains('lavaGateKeyLeft'),
      );

      final right = engine.startStep(
        20,
        25,
        13,
        const ScriptContext(flags: {'den7DragonsCleared', 'den7MudmenCleared'}),
      )!;
      expect(right.awaitingBattle, isTrue);
      expect(
        right.continueAfterBattle().outcome.setFlags,
        contains('lavaGateKeyRight'),
      );
    });

    test('LASTDITCH 비밀벽은 양쪽에서 접근하면 선 행의 타일이 열린다', () async {
      await LoreScriptEngine.instance.load();
      for (final x in [30, 32]) {
        final run = LoreScriptEngine.instance.startStep(
          7,
          x,
          9,
          const ScriptContext(tileAtPlayer: 0),
        );
        expect(run, isNotNull);
        final area = run!.outcome.tileAreas.single;
        expect((area.xMin, area.xMax, area.tile), (31, 31, 45));
        expect(area.atPlayerY, isTrue);
        expect(
          LoreScriptEngine.instance.startStep(
            7,
            x,
            9,
            const ScriptContext(tileAtPlayer: 44),
          ),
          isNull,
        );
      }
    });

    test('1회성 선택지는 취소 전에는 재시도할 수 있다', () async {
      await LoreScriptEngine.instance.load();
      final first = LoreScriptEngine.instance.startStep(12, 12, 48, noCtx)!;
      expect(first.hasPendingChoice, isTrue);
      expect(
        LoreScriptEngine.instance.consumedScripts,
        isNot(contains(first.script.id)),
      );
      expect(LoreScriptEngine.instance.startStep(12, 12, 48, noCtx), isNotNull);

      first.choose(2); // 거절도 원작의 1회성 선택 완료로 본다.
      expect(
        LoreScriptEngine.instance.consumedScripts,
        contains(first.script.id),
      );
      expect(LoreScriptEngine.instance.startStep(12, 12, 48, noCtx), isNull);
    });

    test('1. 스크립트를 로드한다', () async {
      await LoreScriptEngine.instance.load();
      expect(
        LoreScriptEngine.instance.usingJson,
        isTrue,
        reason: 'JSON 로드 실패: ${LoreScriptEngine.instance.loadError}',
      );
      expect(LoreScriptEngine.instance.scripts.length, 592);
      expect(LoreScriptEngine.instance.scripts.map((s) => s.trigger).toSet(), {
        'step',
        'talk',
        'enter', // 원작 LOREENT.PAS entermode (맵 진입 연출)
        'portal', // 진입 전 판정(라바 게이트/수문장 전투)
      });
    });

    test('2. step 스크립트(금화 발견) 보상과 1회성', () async {
      await LoreScriptEngine.instance.load();

      final run = LoreScriptEngine.instance.startStep(9, 10, 24, _liveCtx());
      expect(run, isNotNull);
      expect(run!.outcome.goldDelta, 5000);
      expect(run.hasPendingChoice, isFalse);
      // 게임 화면과 같이 결과 플래그를 반영한다(원작 `party.etc[35] or bit1`).
      for (final f in run.outcome.setFlags) {
        LoreDialogueManager.instance.setFlag(f);
      }

      // 두 번째 진입에서는 원작 `party.etc` 비트가 켜져 다시 나오지 않는다.
      // (게임과 같이 현재 플래그로 컨텍스트를 만들어 확인한다.)
      expect(
        LoreScriptEngine.instance
                .startStep(9, 10, 24, _liveCtx())
                ?.outcome
                .goldDelta ??
            0,
        0,
      );
      // 다른 좌표는 별개
      expect(
        LoreScriptEngine.instance.startStep(14, 6, 6, noCtx)!.outcome.goldDelta,
        1000,
      );
      expect(
        LoreScriptEngine.instance
            .startStep(14, 31, 8, noCtx)!
            .outcome
            .goldDelta,
        1500,
      );
      // 금화 좌표가 아닌 칸에는 금화 보상이 없다.
      expect(
        LoreScriptEngine.instance
                .startStep(9, 11, 24, noCtx)
                ?.outcome
                .goldDelta ??
            0,
        0,
      );
    });

    test('3. Rigel의 합류와 식량 지원 선택지는 효과가 다르다', () async {
      await LoreScriptEngine.instance.load();

      final run = LoreScriptEngine.instance.startStep(12, 12, 48, noCtx);
      expect(run, isNotNull);
      expect(run!.hasPendingChoice, isTrue);
      expect(run.pendingChoice!.length, 3);
      expect(run.pendingChoice!.first, '좋소, 같이 모험을 합시다');
      // 원작 `Print` 줄 수만큼 안내 메시지가 누적된다(마주침 + Rigel의 말)
      expect(run.outcome.messages.length, 8);
      expect(run.outcome.messages.first, contains('몸을 가누지'));

      // 1번 선택지: 식량과 치료를 지원하고 무기 축복을 받는다.
      final after = run.choose(1);
      expect(after.hasPendingChoice, isFalse);
      expect(after.outcome.foodDelta, -5);
      expect(after.outcome.recruits, isEmpty);
      expect(after.outcome.rigelBlessing, isTrue);
      expect(after.outcome.setFlags, contains('etc31_bit2'));
      expect(run.choose(0).outcome.recruits.single.key, 'rigel');
      expect(LoreJoin.byKey('rigel')!.hp, 1); // 원작과 동일한 빈사 상태

      // 2번 선택지(거절)는 합류하지 않는다(원작도 아무 말 없이 빠져나간다)
      LoreScriptEngine.instance.resetForTest();
      await LoreScriptEngine.instance.load();
      final base = LoreScriptEngine.instance.startStep(12, 12, 48, noCtx)!;
      final decline = base.choose(2);
      expect(decline.outcome.recruits, isEmpty);
      expect(decline.outcome.setFlags, contains('etc31_bit2'));
      // 거절은 안내 문구를 더하지 않는다(원작에 문구가 없다)
      expect(decline.outcome.messages.length, base.outcome.messages.length);
    });

    test('4. require 조건에 따라 다른 스크립트가 선택된다 (Red Antares)', () async {
      await LoreScriptEngine.instance.load();

      // 특수 마법을 배우기 전 → 전수 스크립트
      final teach = LoreScriptEngine.instance.startStep(17, 75, 52, noCtx)!;
      expect(teach.outcome.messages.first, contains('용암으로 변하면서'));
      expect(teach.outcome.setFlags, contains('specialMagicLearned'));
      expect(teach.outcome.recruits, isEmpty);

      // 원작 party.etc[5]가 0이면 합류 선택지가 나타나지 않는다.
      final waiting = LoreScriptEngine.instance.startStep(17, 75, 52, learned)!;
      expect(waiting.script.id, 'redantares-wait-for-mindread');
      expect(waiting.hasPendingChoice, isFalse);
      expect(waiting.outcome.recruits, isEmpty);

      // 독심술을 쓰며 재진입하면 합류를 제안한다.
      const mindRead = ScriptContext(
        flags: {'specialMagicLearned'},
        mindReadActive: true,
      );
      final join = LoreScriptEngine.instance.startStep(17, 75, 52, mindRead)!;
      expect(join.hasPendingChoice, isTrue);
      final chosen = join.choose(0);
      expect(chosen.outcome.recruits.single.key, 'red_antares');
      final red = LoreJoin.byKey('red_antares')!;
      expect(red.hp, 0); // 원작과 동일
      expect(red.resistance, 15);
    });

    test('Red Antares 거절은 재시도 가능하고 합류 성공만 완료 비트를 남긴다', () async {
      await LoreScriptEngine.instance.load();
      const ready = ScriptContext(
        flags: {'specialMagicLearned'},
        mindReadActive: true,
      );
      final engine = LoreScriptEngine.instance;
      final decline = engine.startStep(17, 75, 52, ready)!.choose(1);
      expect(decline.outcome.recruits, isEmpty);
      expect(decline.outcome.setFlags, isNot(contains('etc38_bit2')));
      final retry = engine.startStep(17, 75, 52, ready)!;
      expect(retry.script.id, 'redantares-join');
      final accept = retry.choose(0);
      expect(accept.outcome.recruits.single.key, 'red_antares');
      expect(accept.outcome.setFlags, contains('etc38_bit2'));
      expect(accept.outcome.setFlags, contains('redAntaresJoined'));
      expect(
        engine.startStep(
          17,
          75,
          52,
          const ScriptContext(
            flags: {'specialMagicLearned', 'etc38_bit2'},
            mindReadActive: true,
          ),
        ),
        isNull,
      );
    });

    test('5. Spica는 특수 타일 첫 만남 뒤에만 독심술로 영입한다', () async {
      await LoreScriptEngine.instance.load();

      final first = LoreScriptEngine.instance.startStep(18, 37, 31, noCtx)!;
      expect(first.outcome.setFlags, contains('etc39_bit1'));
      expect(first.outcome.messages.join(''), contains('Spica'));
      expect(LoreScriptEngine.instance.startTalk(18, 37, 31, noCtx), isNull);

      const met = ScriptContext(flags: {'etc39_bit1'});
      final inactive = LoreScriptEngine.instance.startStep(18, 37, 31, met)!;
      expect(inactive.outcome.messages.join(''), contains('지체할 시간이 없습니다'));

      const lowEsp = ScriptContext(
        flags: {'etc39_bit1'},
        mindReadActive: true,
        maxEspLevel: 4,
      );
      final cannot = LoreScriptEngine.instance.startStep(18, 37, 31, lowEsp)!;
      expect(cannot.outcome.messages.join(''), contains('나의 마음을 끌어낼수는 없습니'));
      expect(cannot.hasPendingChoice, isFalse);

      const ready = ScriptContext(
        flags: {'etc39_bit1'},
        mindReadActive: true,
        maxEspLevel: 5,
      );
      final can = LoreScriptEngine.instance.startStep(18, 37, 31, ready)!;
      expect(can.hasPendingChoice, isTrue);
      expect(can.choose(2).outcome.setFlags, isNot(contains('etc39_bit2')));
      expect(can.choose(1).outcome.setFlags, contains('etc39_bit2'));
      expect(can.choose(0).outcome.recruits.single.key, 'spica');
      expect(
        LoreScriptEngine.instance.startStep(
          18,
          37,
          31,
          const ScriptContext(flags: {'etc39_bit1', 'etc39_bit2'}),
        ),
        isNull,
      );
      expect(LoreJoin.byKey('spica')!.sex.name, 'female');
    });

    test('6. Mad Joe는 원작과 동일하게 6번 슬롯 고정으로 합류한다', () async {
      await LoreScriptEngine.instance.load();

      final run = LoreScriptEngine.instance.startTalk(6, 40, 15, noCtx)!;
      expect(run.hasPendingChoice, isTrue);
      final joined = run.choose(0);
      expect(joined.outcome.recruits.single.key, 'mad_joe');
      expect(joined.outcome.recruits.single.slot, 4); // 0-based = 6번 슬롯
      expect(
        LoreScriptEngine.instance.startTalk(6, 40, 15, noCtx),
        isNotNull,
      ); // 영입 메뉴 취소·거절 시 다시 대화 가능
      expect(
        LoreScriptEngine.instance.startTalk(
          6,
          40,
          15,
          const ScriptContext(flags: {'madJoeJoined'}),
        ),
        isNull,
      );
    });

    test('8. 지형 변형(setTile)과 강제 이동(teleport) 스텝', () async {
      await LoreScriptEngine.instance.load();

      // 맵 6 (62,82) 상자: 메시지 + 금 1000 + 타일 44로 변경(원작 map[62,82] := 44)
      final chest = LoreScriptEngine.instance.startStep(
        6,
        62,
        82,
        const ScriptContext(tileAtPlayer: 0),
      )!;
      expect(chest.outcome.messages.first, contains('상자 속에서'));
      expect(chest.outcome.goldDelta, 1000);
      final change = chest.outcome.tileChanges.single;
      expect(change.x, 62);
      expect(change.y, 82);
      expect(change.tile, 44);
      expect(change.map, isNull); // 현재 맵에 적용

      // 맵 4 (20,39) Ancient Evil: 첫 방문은 대륙 안내 + 플래그 (원작 LORESPEC 맵 4)
      final first = LoreScriptEngine.instance.startStep(4, 20, 39, noCtx)!;
      expect(first.outcome.setFlags, contains('ancientEvilMet'));
      expect(first.outcome.teleportX, isNull);
      expect(first.outcome.messages.length, 5);

      // 재방문은 비밀 통로로 강제 이동 (원작 x := 46; y := 41)
      final later = LoreScriptEngine.instance.startStep(
        4,
        20,
        39,
        const ScriptContext(flags: {'ancientEvilMet'}),
      )!;
      expect(later.outcome.teleportX, 46);
      expect(later.outcome.teleportY, 41);
      expect(later.outcome.teleportMap, isNull); // 같은 맵
    });

    test('7. JSON이 없으면 스크립트 없음으로 동작하고 게임은 Dart 로직으로 폴백한다', () async {
      await LoreScriptEngine.instance.load(bundle: _MissingBundle());

      expect(LoreScriptEngine.instance.usingJson, isFalse);
      expect(LoreScriptEngine.instance.loadError, isNotNull);
      expect(LoreScriptEngine.instance.scripts, isEmpty);
      expect(LoreScriptEngine.instance.startStep(9, 10, 24, noCtx), isNull);
      expect(LoreScriptEngine.instance.startStep(12, 12, 48, noCtx), isNull);
    });

    test('10. 원작 잔여 좌표 이벤트 이관 (맵 4/6/11/14/15)', () async {
      await LoreScriptEngine.instance.load();
      final engine = LoreScriptEngine.instance;

      // 1) 맵 4 (40,18) 공간 이동 (원작 x := 46; y := 41)
      final jump = engine.startStep(4, 40, 18, noCtx)!;
      expect(jump.outcome.teleportX, 46);
      expect(jump.outcome.teleportY, 41);
      expect(jump.outcome.messages.single, contains('공간 이동'));

      // 2) 맵 4 (26,16) Draconian: 피라밋 설명 + 강의 → 독심술(etc5) 사용 후
      //    영입 제안 (원작도 `party.etc[5] > 0` 일 때만 영입을 제안한다)
      final lecture = engine.startStep(4, 26, 16, noCtx)!;
      expect(lecture.outcome.messages.first, contains('드래곤의 중간 종족'));
      expect(lecture.outcome.recruits, isEmpty);
      final join = engine.startStep(
        4,
        26,
        16,
        const ScriptContext(flags: {'etc5'}),
      )!;
      expect(join.pendingChoice, isNotNull);
      final joinOutcome = join.choose(0).outcome;
      final joined = joinOutcome.recruits.single;
      expect(joined.key, 'draconian');
      expect(joined.slot, 4); // 원작 join(62,6) = 6번 슬롯
      expect(joinOutcome.setFlags, contains('draconianMet'));
      // 원작 join(62,6)은 레벨 17로 편입시킨다.
      expect(LoreJoin.byKey('draconian')!.battleLevel, 17);
      // 이미 합류했다면 피라밋은 비어 있다(원작 `etc[16] and bit2 > 0`).
      final after = engine.startStep(
        4,
        26,
        16,
        const ScriptContext(flags: {'draconianMet'}),
      )!;
      expect(after.outcome.messages.join(''), contains('아무도 살고 있지 않았다'));

      // 3) 맵 6 (51/52,12): Mad Joe를 풀어준 경우에만 병사와 싸운다.
      expect(
        engine.startStep(6, 51, 12, const ScriptContext(tileAtPlayer: 0)),
        isNull,
      );
      final prison = engine.startStep(
        6,
        51,
        12,
        const ScriptContext(flags: {'madJoeJoined'}, tileAtPlayer: 0),
      )!;
      expect(prison.outcome.battleMonsters, [26, 26]);
      expect(prison.awaitingBattle, isTrue);
      expect(engine.consumedScripts, isNot(contains('prison-battle-first')));
      expect(prison.outcome.tileChanges, isEmpty);
      expect(prison.outcome.setFlags, contains('prisonBattleStarted'));
      final escaped = prison.continueAfterRunAway();
      expect(escaped.outcome.tileChanges, isEmpty);
      final prisonAgain = engine.startStep(
        6,
        52,
        12,
        const ScriptContext(
          flags: {'madJoeJoined', 'prisonBattleStarted'},
          tileAtPlayer: 0,
        ),
      )!;
      expect(prisonAgain.outcome.battleMonsters.length, 7);
      expect(prisonAgain.continueAfterBattle().outcome.tileChanges.length, 4);
      final prisonVictory = prison.continueAfterBattle();
      expect(engine.consumedScripts, contains('prison-battle-first'));
      expect(prisonVictory.outcome.tileChanges.length, 4);
      expect(prisonVictory.outcome.setFlags, contains('prisonBattleDone'));
      expect(
        engine.startStep(
          6,
          51,
          12,
          const ScriptContext(
            flags: {'madJoeJoined', 'prisonBattleStarted', 'prisonBattleDone'},
            tileAtPlayer: 0,
          ),
        ),
        isNull,
      );

      final party = List.generate(6, (_) => LoreJoin.madJoe());
      expect(LoreJoin.removeMadJoeAtPrison(party), isTrue);
      expect(party[5].name, isEmpty);
      expect(party[4].name, 'Mad Joe');
      expect(LoreJoin.removeMadJoeAtPrison(party), isFalse);

      // 4) 맵 6 (41,79) 기본 무장 (무기 없는 대원만)
      final arm = engine.startStep(6, 41, 79, noCtx)!;
      final equip = arm.outcome.equips.single;
      expect(equip.kind, 'weapon');
      expect(equip.index, 1);
      expect(equip.power, 5);
      expect(equip.onlyUnarmed, isTrue);

      // 5) 맵 11 y=44 오이디푸스의 창 (행 전체 트리거) + 선택 대화상자
      final spear = engine.startStep(11, 30, 44, noCtx)!;
      expect(spear.outcome.equips.single.kind, 'weapon');
      expect(spear.outcome.equips.single.index, 3);
      expect(spear.outcome.equips.single.power, 12);
      expect(spear.outcome.equips.single.prompt, isTrue);
      // 같은 행(y=44)의 다른 x에서도 발동하고, 다른 행에서는 발동하지 않는다.
      final oedipus = engine.scripts.firstWhere((s) => s.id == 'oedipus-spear');
      expect(oedipus.matches('step', 11, 7, 44), isTrue);
      expect(oedipus.matches('step', 11, 7, 43), isFalse);
      expect(oedipus.matches('step', 10, 7, 44), isFalse);

      // 6) 맵 11 y=24 미이라의 방 (Sphinx ×2 + Major Mummy)
      //    원작은 `party.etc[13] = 1`(LASTDITCH 퀘스트 단계 1)일 때만 발동한다.
      final mummy = engine.startStep(
        11,
        12,
        24,
        const ScriptContext(questSteps: {'lastditch': 1}),
      )!;
      expect(mummy.outcome.battleMonsters, [35, 35, 26]);
      // 적 이름/능력치도 원작 그대로 덮어쓴다.
      final names = mummy.outcome.battleOverrides
          .map((o) => o['name'])
          .whereType<String>()
          .toList();
      expect(names, ['Sphinx', 'Sphinx', 'Major Mummy']);

      // 7) 맵 14 (16,20) 황금의 방패 / 맵 15 (14,7) 방패, (45,19) 갑옷
      expect(
        engine.startStep(14, 16, 20, noCtx)!.outcome.equips.single.kind,
        'shield',
      );
      expect(
        engine.startStep(15, 14, 7, noCtx)!.outcome.equips.single.kind,
        'shield',
      );
      expect(
        engine.startStep(15, 45, 19, noCtx)!.outcome.equips.single.kind,
        'armor',
      );

      // 8) 맵 15 y=27 QUAKE 보스 (Zombie ×2 + ArchiGagoyle)
      //    원작은 `party.etc[14] = 4`(GAIA 퀘스트 단계 4)일 때 발동한다.
      final quake = engine.startStep(
        15,
        20,
        27,
        const ScriptContext(questSteps: {'gaia': 4}),
      )!;
      expect(quake.outcome.battleMonsters, [36, 36, 42]);
      expect(
        quake.outcome.battleOverrides.map((o) => o['name']).whereType<String>(),
        ['Zombie', 'Zombie', 'ArchiGagoyle'],
      );
    });

    test('11. 원작 맵 15 (y=48) 보물은 6000 → 4000 두 단계로 지급된다', () async {
      await LoreScriptEngine.instance.load();
      final engine = LoreScriptEngine.instance;

      final first = engine.startStep(15, 10, 48, noCtx)!;
      expect(first.outcome.goldDelta, 6000);
      // 첫 보상을 받은 뒤에는 두 번째 좌표에서 4000을 받는다.
      final second = engine.startStep(
        15,
        40,
        48,
        const ScriptContext(flags: {'quakeGoldA'}),
      )!;
      expect(second.outcome.goldDelta, 4000);
      // 두 단계를 모두 마치면 더 이상 보상이 없다.
      expect(
        engine.startStep(
          15,
          11,
          48,
          const ScriptContext(flags: {'quakeGoldA', 'quakeGoldB'}),
        ),
        isNull,
      );
    });

    test('12. 카메라 연출(peek)과 Skeleton 영입, 황금의 봉인 (원작 잔여 이관)', () async {
      await LoreScriptEngine.instance.load();
      final engine = LoreScriptEngine.instance;

      // 1) Ancient Evil 안내는 원작처럼 대사 → 시야 이동 → 대사 순서로 진행된다.
      final ancient = engine.startStep(4, 20, 39, noCtx)!;
      final kinds = ancient.outcome.events.map((e) => e.kind).toList();
      expect(kinds.where((k) => k == 'peek').length, 3);
      expect(kinds.first, 'message');
      expect(kinds[2], 'peek');
      final firstPeek = ancient.outcome.events.firstWhere(
        (e) => e.kind == 'peek',
      );
      expect(firstPeek.x, 48); // 원작 x := 48; y := 57;
      expect(firstPeek.y, 57);
      expect(ancient.outcome.messages.length, 5); // messages에는 대사만 남는다

      // 2) LORE 성 출구(맵 6 y=95) Skeleton 영입 - 원작 join(19,6) = 6번 슬롯
      final skeleton = engine.startStep(6, 40, 95, noCtx)!;
      expect(skeleton.outcome.messages.first, contains('누군가가 당신을 불렀다'));
      final joined = skeleton.choose(0).outcome.recruits.single;
      expect(joined.key, 'skeleton');
      expect(joined.slot, 4);
      expect(LoreJoin.byKey('skeleton')!.name, 'Skeleton');

      // 3) 맵 12 (18,10) 황금의 봉인 (원작 party.etc[14] := 2)
      final seal = engine.startStep(12, 18, 10, noCtx)!;
      expect(seal.outcome.messages.first, contains('황금의 봉인'));
      expect(seal.outcome.setFlags, contains('goldenSealFound'));
      // 봉인을 이미 찾은 상태에서는 같은 봉인 스크립트가 다시 걸리지 않는다.
      // (원작 `else if (y=10) and (party.etc[14] < 2)` 처럼 같은 행(y=10)에
      // 다른 원작 이벤트가 걸릴 수 있으므로 "아무것도 안 걸린다" 대신
      // "봉인 스크립트가 아니다" 를 확인한다.)
      final again = engine.startStep(
        12,
        18,
        10,
        const ScriptContext(flags: {'goldenSealFound'}),
      );
      expect(
        again?.outcome.setFlags.contains('goldenSealFound') ?? false,
        isFalse,
      );
    });
    test('13. 원작 보스전 (맵 17 Hidra / 맵 18 Huge Dragon) 이관', () async {
      await LoreScriptEngine.instance.load();
      final engine = LoreScriptEngine.instance;

      // 1) 맵 17: x = 22 열에 들어서면 세 머리 Hidra 와 전투 (원작 etc[15] < 2)
      final hidra = engine.startStep(17, 22, 40, noCtx)!;
      expect(hidra.outcome.battleMonsters, [49, 49, 49]);
      // 원작 안내 문구가 그대로 대사로 들어온다(제목은 없을 수 있다).
      expect(hidra.outcome.messages.any((m) => m.contains('Hidra')), isTrue);
      expect(hidra.outcome.setFlags, isNot(contains('bossHidraDefeated')));
      expect(hidra.continueAfterRunAway().outcome.nudges.single.dx, 1);
      expect(
        hidra.continueAfterBattle().outcome.setFlags,
        contains('bossHidraDefeated'),
      );
      // 다른 열에서는 발동하지 않는다.
      expect(
        engine.startStep(17, 23, 40, noCtx)?.outcome.battleMonsters ??
            const <int>[],
        isEmpty,
      );

      // 2) 맵 18: x = 31 열에서 거룡 + 꼬리 + Mud-Man 무리와 전투
      final dragon = engine.startStep(
        18,
        31,
        40,
        const ScriptContext(flags: {}),
      )!;
      expect(dragon.outcome.battleMonsters.first, 54);
      expect(dragon.outcome.battleMonsters[1], 39); // Dragon's tail
      expect(dragon.continueAfterRunAway().outcome.teleportX, 25);
      expect(dragon.continueAfterRunAway().outcome.teleportY, 94);
      expect(
        dragon.outcome.setFlags,
        isNot(contains('bossHugeDragonDefeated')),
      );
      expect(
        dragon.continueAfterBattle().outcome.setFlags,
        contains('bossHugeDragonDefeated'),
      );

      // 3) 지름길(맵 17 x = 72)은 통로 타일을 연다.
      //    원작 `for j := 19 to 21 do map[72,j] := 44` → (x=72, y=19~21) 영역.
      final shortcut = engine.startStep(17, 72, 30, noCtx)!;
      final openArea = shortcut.outcome.tileAreas.single;
      expect(openArea.tile, 44);
      expect(openArea.xMin, 72);
      expect(openArea.xMax, 72);
      expect(openArea.yMin, 19);
      expect(openArea.yMax, 21);
    });

    test('최종 결전은 분신 전투 후 Necromancer와 싸우며 도망 분기를 처리한다', () async {
      await LoreScriptEngine.instance.load();
      final engine = LoreScriptEngine.instance;
      final first = engine.startById(
        'keep3-necromancer-y26',
        const ScriptContext(tileAtPlayer: 52),
      )!;
      expect(first.awaitingBattle, isTrue);
      expect(first.outcome.battleMonsters, List.filled(6, 60));
      expect(first.outcome.battleMirrorParty, isTrue);
      expect(first.outcome.tileChanges, isEmpty);

      final retry = first.continueAfterRunAway();
      expect(retry.awaitingBattle, isTrue);
      expect(retry.outcome.battleMonsters, List.filled(6, 60));
      expect(retry.outcome.since(first.outcome).battleReuseExisting, isTrue);
      expect(
        retry.outcome.since(first.outcome).battleMonsters,
        List.filled(6, 60),
      );
      expect(retry.outcome.messages.last, ' 하지만 당신은 환상에서 벗어나지 못했다.');

      final second = first.continueAfterBattle();
      expect(second.awaitingBattle, isTrue);
      expect(second.outcome.battleMonsters, [70]);
      expect(second.outcome.battleMirrorParty, isFalse);
      expect(second.outcome.since(first.outcome).battleMonsters, [70]);

      final escaped = second.continueAfterRunAway();
      expect(escaped.awaitingBattle, isFalse);
      expect(escaped.outcome.since(second.outcome).nudges.single.dy, 1);

      final cleared = second.continueAfterBattle();
      expect(cleared.awaitingBattle, isFalse);
      expect(cleared.outcome.since(second.outcome).battleMonsters, isEmpty);
      expect(cleared.outcome.tileChanges, isNotEmpty);
      expect(cleared.outcome.tileAreas.single.tile, 46);
    });

    test('Wivern 수문장은 도망 전 쓰러뜨린 수만큼 다음 전투가 줄어든다', () async {
      await LoreScriptEngine.instance.load();
      final engine = LoreScriptEngine.instance;
      ScriptRun start(int defeated) => engine.startStep(
        16,
        20,
        10,
        ScriptContext(tileAtPlayer: 0, questSteps: {'wivern': defeated}),
      )!;

      final three = start(0);
      expect(three.outcome.battleMonsters, [43, 43, 43]);
      expect(three.continueAfterBattle().outcome.questChanges.last.set, 3);
      expect(
        three
            .continueAfterRunAway(defeatedEnemySlots: {1})
            .outcome
            .questChanges
            .last
            .set,
        1,
      );
      expect(start(1).outcome.battleMonsters, [43, 43]);
      expect(start(2).outcome.battleMonsters, [43]);
      expect(start(3).outcome.messages.single, contains('시체'));
    });

    test('KEEP2 출구는 7명 수문장을 거친 뒤에만 격퇴 상태를 남긴다', () async {
      await LoreScriptEngine.instance.load();
      final engine = LoreScriptEngine.instance;
      final run = engine.startById('keep2-exit-guard', const ScriptContext())!;
      expect(run.awaitingBattle, isTrue);
      expect(run.outcome.battleEnemyFirst, isTrue);
      expect(run.outcome.battleMonsters, hasLength(7));
      expect(run.outcome.battleMonsters.last, 66);
      expect(run.outcome.battleMonsters.take(6).toSet(), hasLength(1));
      expect(run.outcome.setFlags, isEmpty);
      expect(run.continueAfterRunAway().outcome.setFlags, isEmpty);
      expect(
        run.continueAfterRunAway(defeatedEnemySlots: {7}).outcome.setFlags,
        contains('etc43_bit3'),
      );
      expect(
        run.continueAfterBattle().outcome.setFlags,
        contains('etc43_bit3'),
      );
    });

    test('마지막 두 포털은 원작 수문장을 거쳐 맵 26으로 이어진다', () async {
      await LoreScriptEngine.instance.load();
      final engine = LoreScriptEngine.instance;
      final dungeon = engine.startById(
        'portal-23-25-dungeon',
        const ScriptContext(),
      )!;
      expect(dungeon.outcome.battleMonsters, [62, 62, 70, 62, 62, 62, 62]);
      expect(dungeon.outcome.battleEnemyFirst, isTrue);
      expect(dungeon.continueAfterRunAway().outcome.blockMove, isTrue);
      expect(
        dungeon.continueAfterRunAway(defeatedEnemySlots: {3}).outcome.setFlags,
        contains('dungeonOfEvilCleared'),
      );

      final chamber = engine.startById(
        'portal-25-26-chamber',
        const ScriptContext(),
      )!;
      expect(chamber.outcome.battleMonsters, [63, 63, 63, 63, 63, 72]);
      expect(chamber.outcome.battleEnemyFirst, isFalse);
      expect(chamber.outcome.torchLit, isTrue);
      final escaped = chamber.continueAfterRunAway();
      expect(escaped.outcome.blockMove, isTrue);
      expect((escaped.outcome.teleportX, escaped.outcome.teleportY), (25, 45));
      expect(chamber.outcome.battleVictoryFlags, isEmpty);
    });

    test('Frost Dragon 입구의 모든 난수 배치에서 적이 먼저 행동한다', () async {
      await LoreScriptEngine.instance.load();
      final engine = LoreScriptEngine.instance;
      for (var i = 0; i < 20; i++) {
        final run = engine.startById(
          'portal-5-23-frostdragon',
          const ScriptContext(),
        )!;
        expect(run.outcome.battleMonsters, hasLength(7));
        expect(run.outcome.battleMonsters, contains(69));
        expect(run.outcome.battleEnemyFirst, isTrue);
      }
    });

    test('14. 영역 지형 변형(setTileArea)과 난수 소환/난수 플래그', () async {
      await LoreScriptEngine.instance.load();
      final engine = LoreScriptEngine.instance;

      // 1) 맵 19 (41,39) 레버: 통로를 영역 단위로 열고 7개 방 중 하나를 뽑는다.
      final leverB = engine.startStep(
        19,
        41,
        39,
        const ScriptContext(tileAtPlayer: 0),
      )!;
      expect(leverB.outcome.tileAreas.map((a) => a.tile), contains(44));
      final corridor = leverB.outcome.tileAreas.firstWhere((a) => a.tile == 44);
      expect(corridor.xMin, 25);
      expect(corridor.xMax, 27);
      expect(corridor.yMin, 27);
      expect(corridor.yMax, 37); // 원작 `for j := 27 to 37 do for i := 25 to 27`
      final pickedRoom = leverB.outcome.setFlags.firstWhere(
        (f) => f.startsWith('evilSealRoom'),
        orElse: () => '',
      );
      expect(pickedRoom, isNotEmpty); // 1~7 중 하나가 반드시 뽑힌다
      expect(leverB.outcome.setFlags, contains('evilSealLeverB'));
      expect(
        engine.startStep(19, 41, 39, const ScriptContext(tileAtPlayer: 49)),
        isNull,
      );

      // 2) 늪위를 걷는 마법이 켜져 있으면 레버를 당길 수 없다 (원작 etc[3] > 0).
      const swampOn = ScriptContext(
        flags: {'swampWalkActive'},
        tileAtPlayer: 0,
      );
      final blocked = engine.startStep(19, 11, 40, swampOn)!;
      expect(blocked.outcome.messages.single, contains('늪위를 걷는 마법'));
      expect(blocked.outcome.tileChanges, isEmpty);

      // 3) 정답 방에서만 Crab God 왕과 싸운다 (방 번호는 무작위로 정해진다).
      final room3 = engine.startStep(
        19,
        22,
        6,
        const ScriptContext(flags: {'evilSealRoom3'}),
      )!;
      expect(room3.outcome.battleMonsters, List.filled(7, 59));
      expect(room3.outcome.tileAreas.single.yMin, 5);
      expect(room3.outcome.tileAreas.single.atPlayerX, isTrue);
      expect(room3.outcome.battleOverrides, [
        for (var index = 4; index <= 7; index++)
          {'index': index, 'eNumber': 25, 'hp': 210, 'level': 7},
      ]);
      expect(room3.outcome.setFlags, isNot(contains('evilSealRoomCleared')));
      expect(
        room3.continueAfterBattle().outcome.setFlags,
        contains('evilSealRoomCleared'),
      );

      // 4) 다른 방은 "봉인이 발견되지 않았다" 안내만 나온다.
      final wrongRoom = engine.startStep(
        19,
        22,
        6,
        const ScriptContext(flags: {'evilSealRoom4'}),
      )!;
      expect(wrongRoom.outcome.battleMonsters, isEmpty);
      expect(wrongRoom.outcome.messages.single, contains('봉인이 발견되지 않았다'));
      expect(wrongRoom.outcome.tileAreas.single.atPlayerX, isTrue);
      expect(engine.startStep(19, 10, 6, noCtx), isNull);
      expect(
        engine.startStep(
          19,
          22,
          6,
          const ScriptContext(flags: {'evilSealRoom4', 'evilSealRoomCleared'}),
        ),
        isNull,
      );

      // 5) 봉인이 남아 있는 동안 y 8~12에서는 난수 마리(3~5)의 수호 몬스터가 나온다.
      final guardians = engine.startStep(
        19,
        14,
        8,
        const ScriptContext(flags: {'evilSealLeverB'}),
      )!;
      expect(guardians.outcome.battleMonsters.length, inInclusiveRange(3, 5));
      expect(guardians.outcome.battleMonsters.every((id) => id == 59), isTrue);
      expect(guardians.outcome.messages, isEmpty);
      expect(guardians.outcome.battleOverrides.length, 5);
      expect(guardians.outcome.battleOverrides.first['hp'], 210);
      expect(
        guardians.continueAfterRunAway().outcome.playerTiles.single.tile,
        49,
      );
      // 봉인을 이미 풀었다면 나오지 않는다.
      expect(
        engine.startStep(
          19,
          14,
          8,
          const ScriptContext(flags: {'evilSealLeverB', 'evilSealRoomCleared'}),
        ),
        isNull,
      );
    });

    test('15. 맵 12 수수께끼 문과 맵 17 통로 강제 이동', () async {
      await LoreScriptEngine.instance.load();
      final engine = LoreScriptEngine.instance;

      // 1) 옳은 문(33, 50)은 통로를 연다.
      final right = engine.startStep(12, 33, 50, noCtx)!;
      expect(right.outcome.messages.single, contains('옳은 문'));
      expect(right.outcome.tileChanges.single.tile, 0);

      // 2) 그 밖의 문은 되돌려 보낸다 (원작 x := 25; y := 70).
      final wrong = engine.startStep(12, 20, 50, noCtx)!;
      expect(wrong.outcome.messages.single, contains('바보군요'));
      expect(wrong.outcome.teleportX, 25);
      expect(wrong.outcome.teleportY, 70);

      // 3) 맵 17 y=38: 지형을 열고 (56, 93)으로 내려보낸다.
      final passage = engine.startStep(17, 68, 38, noCtx)!;
      expect(passage.outcome.tileAreas.length, 2);
      expect(passage.outcome.teleportX, 56);
      expect(passage.outcome.teleportY, 93);
    });

    test('16. 맵 21/22/23/25 (KEEP·K_DEN) 이벤트 이관', () async {
      await LoreScriptEngine.instance.load();
      final engine = LoreScriptEngine.instance;

      // 1) 맵 21 (25,20) 봉인문: 두 퍼즐 중 하나라도 남아 있으면 막히고 밀려난다.
      final blocked = engine.startStep(
        21,
        25,
        20,
        const ScriptContext(flags: {'sealPuzzleA'}),
      )!;
      expect(blocked.outcome.messages.join(''), contains('라바 게이트를 열수가 없다'));
      final nudge = blocked.outcome.nudges.single;
      expect(nudge.dy, 1); // 원작 `inc(y)`
      // 두 퍼즐을 모두 풀면 문이 열린다 → 더 이상 막히지 않는다.
      // (원작은 이때도 전투·지형 변경을 하지만 "밀려나기"는 하지 않는다.)
      final opened = engine.startStep(
        21,
        25,
        20,
        const ScriptContext(flags: {'sealPuzzleA', 'sealPuzzleB'}),
      );
      expect(opened?.outcome.nudges ?? const [], isEmpty);
      expect(
        (opened?.outcome.messages ?? const []).any((m) => m.contains('봉인')),
        isFalse,
      );

      // 2) 맵 22 (25,18): Wraith 5자리 중 하나가 Death Knight로 교체된다.
      final ambush = engine.startStep(22, 25, 18, noCtx)!;
      expect(ambush.outcome.battleEnemyFirst, isTrue);
      expect(ambush.outcome.battleMonsters.where((m) => m == 60).length, 4);
      expect(ambush.outcome.battleMonsters.where((m) => m == 63).length, 1);
      expect(ambush.outcome.setFlags, isNot(contains('keep2AmbushCleared')));
      expect(
        ambush.continueAfterBattle().outcome.setFlags,
        contains('keep2AmbushCleared'),
      );

      // 3) 맵 22 (y=25, x=24~26) 수문장 5명
      final guards = engine.startStep(22, 25, 25, noCtx)!;
      expect(guards.outcome.battleEnemyFirst, isFalse);
      expect(guards.outcome.battleMonsters, [61, 58, 56, 55, 60]);

      // 4) 맵 23 (25,27): 함정 해제 + 0인 타일만 영역 변형
      final trap = engine.startStep(
        23,
        25,
        27,
        const ScriptContext(tileAtPlayer: 52),
      )!;
      final zeroArea = trap.outcome.tileAreas.firstWhere(
        (a) => a.tile == 39 && a.onlyIf == 0,
      );
      expect(zeroArea.xMin, 12);
      expect(zeroArea.xMax, 39);
      expect(zeroArea.yMin, 7);
      expect(zeroArea.yMax, 34);
      expect(
        engine.startStep(23, 25, 27, const ScriptContext(tileAtPlayer: 46)),
        isNull,
      );

      // 5) 맵 25 열쇠: 먼저 닿은 쪽은 기록만, 나중 쪽에서 문이 열린다.
      final firstKey = engine.startStep(25, 5, 34, noCtx)!;
      expect(firstKey.outcome.setFlags, ['keep3KeyA']);
      final secondKey = engine.startStep(
        25,
        46,
        34,
        const ScriptContext(flags: {'keep3KeyA'}),
      )!;
      expect(secondKey.outcome.setFlags, contains('keep3KeyB'));
      expect(secondKey.outcome.setFlags, contains('sealPuzzleB'));
      expect(
        secondKey.outcome.tileChanges.map((t) => t.x),
        containsAll(<int>[25, 26]),
      );

      // 6) 맵 25 통로 개방 (15,34)/(36,34)
      final corridor = engine.startStep(
        25,
        15,
        34,
        const ScriptContext(tileAtPlayer: 0),
      )!;
      expect(corridor.outcome.tileAreas.length, 3);
      // 특수 타일이 바닥으로 변한 뒤 다시 지나가도 이벤트를 반복하지 않는다.
      expect(
        engine.startStep(6, 62, 82, const ScriptContext(tileAtPlayer: 44)),
        isNull,
      );
      expect(
        engine.startStep(25, 15, 34, const ScriptContext(tileAtPlayer: 41)),
        isNull,
      );
      expect(
        engine.startStep(18, 22, 41, const ScriptContext(tileAtPlayer: 44)),
        isNull,
      );
    });

    test('K_DEN2 입구의 금속 수문장은 승리 후에만 길과 직업을 바꾼다', () async {
      await LoreScriptEngine.instance.load();
      final engine = LoreScriptEngine.instance;
      const entrance = ScriptContext(tileAtPlayer: 0);
      final battle = engine.startStep(25, 25, 43, entrance)!;
      expect(battle.outcome.battleMonsters, [66, 66, 66, 66, 71]);
      expect(battle.outcome.tileAreas, isEmpty);
      expect(battle.outcome.partyClassId, isNull);

      final escaped = battle.continueAfterRunAway();
      expect(escaped.outcome.since(battle.outcome).nudges.single.dy, 1);
      expect(escaped.outcome.tileAreas, isEmpty);
      expect(escaped.outcome.partyClassId, isNull);

      final won = battle.continueAfterBattle();
      final reward = won.outcome.since(battle.outcome);
      expect(reward.partyClassId, 10);
      expect(reward.tileAreas.single, (
        map: null,
        xMin: 24,
        xMax: 27,
        yMin: 43,
        yMax: 43,
        tile: 41,
        ifZero: null,
        atPlayerX: false,
        atPlayerY: false,
        onlyIf: null,
      ));
      expect(
        engine.startStep(25, 25, 43, const ScriptContext(tileAtPlayer: 41)),
        isNull,
      );
    });

    test('SWAMP GATE 첫 진입에만 Lord Ahn의 안내가 나온다', () async {
      await LoreScriptEngine.instance.load();
      final engine = LoreScriptEngine.instance;
      final first = engine.startById('portal-9-13-swamp-gate', noCtx)!;
      expect(first.outcome.messages.join(), contains('Lord Ahn'));
      expect(first.outcome.setFlags, contains('etc35_bit6'));
      expect(first.outcome.teleportMap, isNull);
      expect(
        engine.startById(
          'portal-9-13-swamp-gate',
          const ScriptContext(flags: {'etc35_bit6'}),
        ),
        isNull,
      );
    });

    test('SWAMP KEEP 특수 칸은 58번 몬스터 3~6명과 싸운 뒤 소모된다', () async {
      await LoreScriptEngine.instance.load();
      final engine = LoreScriptEngine.instance;
      expect(
        engine.startStep(
          21,
          25,
          20,
          const ScriptContext(flags: {'sealPuzzleA', 'sealPuzzleB'}),
        ),
        isNull,
      );
      final battle = engine.startStep(21, 10, 11, noCtx)!;
      expect(battle.script.id, 'keep1-special-ambush');
      expect(battle.outcome.battleMonsters.length, inInclusiveRange(3, 6));
      expect(battle.outcome.battleMonsters.toSet(), {58});
      expect(battle.outcome.playerTiles, isEmpty);
      final escaped = battle.continueAfterRunAway();
      expect(escaped.outcome.since(battle.outcome).playerTiles.single.tile, 46);
      expect(escaped.outcome.playerTiles.single.ifZero, 40);
      final won = battle.continueAfterBattle();
      expect(won.outcome.since(battle.outcome).playerTiles.single.ifZero, 40);
    });

    test('EVIL SEAL 수수께끼 문은 남쪽으로 되돌아갈 때 발동하지 않는다', () async {
      await LoreScriptEngine.instance.load();
      final engine = LoreScriptEngine.instance;
      expect(
        engine.startStep(12, 33, 50, const ScriptContext(moveDy: -1)),
        isNotNull,
      );
      expect(
        engine.startStep(12, 32, 50, const ScriptContext(moveDy: -1)),
        isNotNull,
      );
      expect(
        engine.startStep(12, 33, 50, const ScriptContext(moveDy: 1)),
        isNull,
      );
      expect(
        engine.startStep(12, 32, 50, const ScriptContext(moveDy: 1)),
        isNull,
      );
    });

    test('17. 맵 20(DEN 7) 퀴즈 미로와 숨은 통로, 맵 22 상시 습격', () async {
      await LoreScriptEngine.instance.load();
      final engine = LoreScriptEngine.instance;

      // 1) 퀴즈 행(y=91): 8개 문항 중 하나가 무작위로 나오고, 문이 함께 정해진다.
      final quiz = engine.startStep(20, 30, 91, noCtx)!;
      // 원작은 안내문(` 다음 물음이 맞다면 ...`) 뒤에 `문> ...` 문항을 보여준다.
      expect(quiz.outcome.messages.any((m) => m.startsWith('문> ')), isTrue);
      // 문은 항상 좌/우 중 한쪽만 열린다.
      final doors = quiz.outcome.tileChanges.where((t) => t.y == 88).toList();
      expect(doors.length, 2);
      expect(doors.map((t) => t.tile).toSet(), {0, 52});

      // 2) 숨은 통로: 밟은 타일이 0일 때만 아래층으로 내려간다 (원작 y := 80).
      final passage = engine.startStep(
        20,
        30,
        88,
        const ScriptContext(tileAtPlayer: 0),
      )!;
      expect(passage.outcome.teleportY, 80);
      expect(passage.outcome.teleportKeepX, isTrue);
      // 타일이 0이 아니면 필드로 퇴장한다.
      final exit = engine.startStep(
        20,
        30,
        88,
        const ScriptContext(tileAtPlayer: 46),
      )!;
      expect(exit.outcome.teleportMap, 4);
      expect(exit.outcome.teleportX, 82);

      // 3) y=18 에서 마법의 횃불을 얻는다 (원작 etc[1] := 1).
      expect(engine.startStep(20, 30, 18, noCtx)!.outcome.torchLit, isTrue);

      // 4) y=48 Minotaur, y=13 거룡 → 진흙 인간 → 미궁의 주인 순서
      expect(engine.startStep(20, 30, 48, noCtx)!.outcome.battleMonsters, [53]);
      expect(engine.startStep(20, 30, 13, noCtx)!.outcome.battleMonsters, [
        54,
        54,
        54,
      ]);
      // 원작은 수호룡 승리 직후 같은 좌표에서 진흙 인간과 주인을 연달아 만난다.
      final dragons = engine.startStep(20, 30, 13, noCtx)!;
      final afterDragons = dragons.continueAfterBattle();
      expect(afterDragons.awaitingBattle, isTrue);
      expect(afterDragons.outcome.battleMonsters, List.filled(7, 31));
      expect(afterDragons.outcome.setFlags, contains('den7DragonsCleared'));
      final afterMudmen = afterDragons.continueAfterBattle();
      expect(afterMudmen.awaitingBattle, isTrue);
      expect(afterMudmen.outcome.battleMonsters.last, 57);
      expect(afterMudmen.outcome.setFlags, contains('den7MudmenCleared'));
      final afterMaster = afterMudmen.continueAfterBattle();
      expect(afterMaster.awaitingBattle, isFalse);
      expect(afterMaster.outcome.setFlags, contains('den7MazeCleared'));
      expect(afterMaster.outcome.teleportMap, 4);
      expect(dragons.continueAfterRunAway().outcome.nudges.single.dy, 1);
      expect(afterDragons.continueAfterRunAway().outcome.nudges.single.dy, 1);
      final mudmen = engine.startStep(
        20,
        30,
        13,
        const ScriptContext(flags: {'den7DragonsCleared'}),
      )!;
      expect(mudmen.outcome.battleMonsters.length, 7);
      final master = engine.startStep(
        20,
        30,
        13,
        const ScriptContext(flags: {'den7DragonsCleared', 'den7MudmenCleared'}),
      )!;
      expect(master.outcome.battleMonsters.last, 57); // Astral Mud
      expect(master.continueAfterRunAway().outcome.nudges.single.dy, 1);
      expect(
        master
            .continueAfterRunAway(defeatedEnemySlots: {7})
            .outcome
            .teleportMap,
        4,
      );
      expect(master.continueAfterBattle().outcome.teleportMap, 4);
      // 미궁을 깨면 지상으로 돌아간다.
      final back = engine.startStep(
        20,
        30,
        13,
        const ScriptContext(
          flags: {'den7DragonsCleared', 'den7MudmenCleared', 'den7MazeCleared'},
        ),
      )!;
      expect(back.outcome.teleportMap, 4);

      // 5) 맵 22의 일반 특수 칸에서는 Wraith 무리가 나오고 지형이 바뀐다.
      final ambush = engine.startStep(22, 43, 25, noCtx)!;
      expect(ambush.outcome.battleMonsters, [60, 60, 60, 60, 60]);
      final tile = ambush.continueAfterBattle().outcome.playerTiles.single;
      expect(tile.tile, 40);
      expect(ambush.continueAfterRunAway().outcome.playerTiles.single.tile, 40);
      // (25,18) 등 지정 이벤트가 우선한다.
      expect(
        engine.startStep(22, 25, 18, noCtx)!.outcome.battleMonsters.length,
        5,
      );
    });

    test('18. 원작 LORETALK 마을 NPC 대사 이관 (자동 생성분)', () async {
      await LoreScriptEngine.instance.load();
      final engine = LoreScriptEngine.instance;

      // 마을 5곳(6/7/9/10/24)의 NPC 대사가 좌표 대화로 들어와 있다.
      expect(
        engine.startTalk(6, 72, 73, noCtx)!.outcome.messages.single,
        'Orc 는 가장 하급 괴물이오.',
      );
      expect(
        engine.startTalk(9, 24, 38, noCtx)!.outcome.messages.single,
        contains('황금의 봉인'),
      );
      expect(engine.startTalk(10, 11, 16, noCtx), isNotNull);

      // 주인공 이름이 들어가는 원작 대사는 {hero} 로 치환된다.
      final byHero = LoreScriptEngine.instance.scripts
          .where((s) => s.map == 6 && s.x == 24 && s.y == 50)
          .toList();
      expect(byHero, isNotEmpty);
      expect(
        byHero.first.steps.any((st) => (st.text ?? '').contains('{hero}')),
        isTrue,
      );
      // 대사가 있는 talk 스크립트는 79개 이상 이관되어 있다.
      final talkCount = engine.scripts.where((s) => s.trigger == 'talk').length;
      expect(talkCount, greaterThanOrEqualTo(88));
    });
  });
}

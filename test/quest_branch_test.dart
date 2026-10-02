import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/logic/script_world_reducer.dart';
import 'package:lore/logic/lore_spec_procedures.dart';

/// 원작 `LORETALK.PAS` 의 상태 분기(party.etc 비트/퀘스트 단계) 대사를
/// 검증한다. (아이템 1: 남은 수동 이관 분기)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const lordahnCtx0 = ScriptContext(questSteps: {'lordahn': 0});
  const lordahnCtx2 = ScriptContext(questSteps: {'lordahn': 2});
  const lordahnCtx4 = ScriptContext(questSteps: {'lordahn': 4});
  const lordahnCtx6 = ScriptContext(questSteps: {'lordahn': 6});

  setUp(() {
    LoreScriptEngine.instance.resetForTest();
    LoreDialogueManager.instance.resetDataForTest();
  });
  tearDown(() => LoreScriptEngine.instance.resetForTest());

  group('LORETALK 퀘스트 단계 분기 (아이템 1)', () {
    test('Lord Ahn 알현: 단계별 대사와 단계 증가/경험치', () async {
      await LoreScriptEngine.instance.load();
      final engine = LoreScriptEngine.instance;

      // etc[10] = 0: 소개 + inc(party.etc[10])
      final q0 = engine.startTalk(6, 51, 28, lordahnCtx0)!;
      expect(q0.outcome.messages.first, contains('Lord Ahn'));
      expect(q0.outcome.questChanges.single.name, 'lordahn');
      expect(q0.outcome.questChanges.single.inc, 1);
      expect(q0.outcome.expDelta, 0);

      // etc[10] = 2: MENACE 탐사 의뢰
      final q2 = engine.startTalk(6, 51, 28, lordahnCtx2)!;
      expect(q2.outcome.messages.join('\n'), contains('MENACE'));
      expect(q2.outcome.questChanges.single.inc, 1);

      // etc[10] = 3: 안내만 하고 단계는 늘지 않는다.
      final q3 = engine.startTalk(
        6,
        51,
        28,
        const ScriptContext(questSteps: {'lordahn': 3}),
      )!;
      expect(q3.outcome.messages.single, contains('MENACE'));
      expect(q3.outcome.questChanges, isEmpty);

      // etc[10] = 4: [EXP + 1000]
      final q4 = engine.startTalk(6, 51, 28, lordahnCtx4)!;
      expect(q4.outcome.messages.join('\n'), contains('[EXP + 1000]'));
      expect(q4.outcome.expDelta, 1000);

      // etc[10] = 6: 마지막 안내
      final q6 = engine.startTalk(6, 51, 28, lordahnCtx6)!;
      expect(q6.outcome.messages.single, contains('스스로 행동'));
    });

    test('성문 안내는 Lord Ahn 단계에 따라 문구가 바뀐다 (48..54, 31..37)', () async {
      await LoreScriptEngine.instance.load();
      final engine = LoreScriptEngine.instance;

      final before = engine.startTalk(6, 51, 34, lordahnCtx0)!;
      expect(before.outcome.messages.single, '저희 성주님을 만나십시오.');

      final after = engine.startTalk(6, 51, 34, lordahnCtx2)!;
      expect(after.outcome.messages.single, '당신이 성공하기를 빕니다.');
    });

    test('(50,51) 도전: 수락하면 벽이 열리고, 거절하면 안내문이 나온다', () async {
      await LoreScriptEngine.instance.load();
      final engine = LoreScriptEngine.instance;

      // already accepted
      final lucky = engine.startTalk(
        6,
        50,
        51,
        const ScriptContext(flags: {'loreChallengeAccepted'}),
      )!;
      expect(lucky.outcome.messages.single, '행운을 빌겠소 !!!');

      // etc[10] < 3 : 아직 성주를 만나지 않음
      final early = engine.startTalk(6, 50, 51, lordahnCtx0)!;
      expect(early.outcome.messages.single, '저희 성주님을 만나 보십시오.');

      // etc[10] >= 3 : Y/n 선택지
      final ask = engine.startTalk(6, 52, 51, lordahnCtx4)!;
      expect(ask.hasPendingChoice, isTrue);
      expect(ask.pendingChoice!.length, 2);
      final accepted = ask.choose(0).outcome;
      expect(accepted.setFlags, contains('loreChallengeAccepted'));
      expect(
        accepted.tileChanges.length,
        10,
      ); // map[49..53,52] + map[49..53,53]
      expect(accepted.messages.join('\n'), contains('진정한 이 세계에 발을 디디게'));

      // 거절
      final refused = engine
          .startTalk(6, 52, 51, lordahnCtx4)!
          .choose(1)
          .outcome;
      expect(refused.setFlags, isEmpty);
      expect(refused.messages.join('\n'), contains('다시 생각 해보십시오.'));
    });

    test('(51,87) 성문 축복과 (63,76) Jr. Antares 숨은 통로', () async {
      await LoreScriptEngine.instance.load();
      final engine = LoreScriptEngine.instance;

      final bless = engine.startTalk(6, 51, 87, const ScriptContext())!;
      expect(bless.outcome.messages.join('\n'), contains('난 당신을 믿소'));
      expect(bless.outcome.setFlags, contains('loreChallengeBlessed'));
      expect(bless.outcome.tileAreas.single.yMin, 88);
      expect(bless.outcome.tileAreas.single.xMin, 49);
      expect(bless.outcome.tileAreas.single.xMax, 53);

      final after = engine.startTalk(
        6,
        51,
        87,
        const ScriptContext(flags: {'loreChallengeBlessed'}),
      )!;
      expect(after.outcome.messages.join('\n'), contains('힘내시오'));

      final antares = engine.startTalk(6, 63, 76, const ScriptContext())!;
      expect(antares.outcome.messages.join('\n'), contains('Jr. Antares'));
      expect(antares.outcome.setFlags, contains('jrAntaresSecretFound'));
      final tiles = {
        for (final t in antares.outcome.tileChanges) '${t.x},${t.y}': t.tile,
      };
      expect(tiles['62,82'], 0);
      expect(tiles['62,83'], 14);
      expect(antares.outcome.tileAreas.single.yMin, 79);
      expect(antares.outcome.tileAreas.single.yMax, 81);
      expect(
        engine.startTalk(
          6,
          63,
          76,
          const ScriptContext(flags: {'jrAntaresSecretFound'}),
        ),
        isNull,
      );
    });

    test('LASTDITCH/GAIA/WATER FIELD 성주 대사와 경험치 보상', () async {
      await LoreScriptEngine.instance.load();
      final engine = LoreScriptEngine.instance;

      // 맵 7 (38,17) etc[13] = 2 → 10000 EXP
      final ld2 = engine.startTalk(
        7,
        38,
        17,
        const ScriptContext(questSteps: {'lastditch': 2}),
      )!;
      expect(ld2.outcome.expDelta, 10000);
      expect(ld2.outcome.questChanges.single.name, 'lastditch');

      // 맵 9 (42,25) etc[14] = 5 → 40000 EXP + Water Key 안내
      final gaia5 = engine.startTalk(
        9,
        42,
        25,
        const ScriptContext(questSteps: {'gaia': 5}),
      )!;
      expect(gaia5.outcome.expDelta, 40000);
      expect(gaia5.outcome.messages.join('\n'), contains('Water Key'));

      // 맵 10 (25,18) etc[15] = 4 → 300000 EXP + Swamp Key 안내
      final water4 = engine.startTalk(
        10,
        25,
        18,
        const ScriptContext(questSteps: {'water': 4}),
      )!;
      expect(water4.outcome.expDelta, 300000);
      expect(water4.outcome.messages.join('\n'), contains('Swamp Key'));

      // 맵 7 성문 안내(etc[13] = 0 / >= 1)
      expect(
        engine.startTalk(7, 36, 19, const ScriptContext())!.outcome.messages,
        ['성주님을 만나 보십시오.'],
      );
      expect(
        engine
            .startTalk(
              7,
              36,
              19,
              const ScriptContext(questSteps: {'lastditch': 1}),
            )!
            .outcome
            .messages,
        ['당신이 성공하기를 빕니다.'],
      );
    });

    test('Polaris/Lore Hunter 영입은 퀘스트 조건과 타일 변경을 갖는다', () async {
      await LoreScriptEngine.instance.load();
      final engine = LoreScriptEngine.instance;

      // etc[13] < 2 에서만 제안한다.
      expect(
        engine.startTalk(
          7,
          37,
          41,
          const ScriptContext(questSteps: {'lastditch': 2}),
        ),
        isNull,
      );
      final polaris = engine.startTalk(7, 37, 41, const ScriptContext())!;
      expect(polaris.outcome.messages.join('\n'), contains('Polaris'));
      final joined = polaris.choose(0).outcome;
      expect(joined.recruits.single.key, 'polaris');
      expect(
        joined.tileChanges.single.x == 37 && joined.tileChanges.single.y == 41,
        isTrue,
      );
      expect(polaris.choose(1).outcome.tileChanges, isEmpty);

      // 맵 10 (40,56) Lore Hunter
      final hunter = engine.startTalk(10, 40, 56, const ScriptContext())!;
      expect(hunter.outcome.messages.join('\n'), contains('Lore Hunter'));
      final hunterJoined = hunter.choose(0).outcome;
      expect(hunterJoined.recruits.single.key, 'lore_hunter');
      expect(hunterJoined.setFlags, contains('loreHunterJoined'));
    });

    test('LASTDITCH 재진입 시 Polaris의 현재 동행 여부로 NPC 타일을 바꾼다', () async {
      await LoreScriptEngine.instance.load();
      final engine = LoreScriptEngine.instance;
      final map = await LoreMapData.loadFromAsset('TOWN2', category: 'town');
      expect(map.getTile(37, 41), 53);

      const formerMember = ScriptContext(
        enteredFromMap: 1,
        flags: {'polarisJoined'},
      );
      expect(engine.startEnter(7, formerMember), isNull);

      const currentMember = ScriptContext(
        enteredFromMap: 1,
        partyNames: {'Polaris'},
      );
      final entry = engine.startEnter(7, currentMember)!;
      expect(entry.outcome.tileChanges.single.tile, 44);
      final after = ScriptWorldReducer.applyMap(
        ScriptMapState(mapId: 7, x: 38, y: 7, direction: 0, grid: map.grid),
        entry.outcome,
      );
      expect(after.grid[40][36], 44);
      expect(map.getTile(37, 41), 53);
    });

    test('(41,79) 기본 무장 이벤트가 etc[50] bit4 를 세운다', () async {
      await LoreScriptEngine.instance.load();
      final engine = LoreScriptEngine.instance;

      expect(
        engine.startStep(6, 41, 79, const ScriptContext(tileAtPlayer: 0)),
        isNull,
      );
      final run = LoreSpecProcedures.map6(
        41,
        79,
        const ScriptContext(tileAtPlayer: 0),
        engine,
      )!;
      expect(run.outcome.setFlags, contains('etc50_bit4'));
      final armed = run.acknowledgeScene();
      expect(armed.outcome.messages.join('\n'), contains('기본적인 무기'));
      expect(armed.outcome.equips.single.kind, 'weapon');
      expect(armed.outcome.equips.single.index, 1);
      expect(armed.outcome.equips.single.onlyUnarmed, isTrue);
      expect(run.outcome.nudges.length, 3);
      expect(run.outcome.nudges.first.dx, -1);

      // 무기고 안내 문구도 상태에 따라 나뉜다.
      final first = engine.startTalk(6, 42, 78, const ScriptContext())!;
      expect(first.outcome.messages.join('\n'), contains('들어가셔서 무'));
      final later = engine.startTalk(
        6,
        42,
        78,
        const ScriptContext(flags: {'weaponRoomVisited'}),
      )!;
      expect(later.outcome.messages.join('\n'), contains('무찔러 주십시오'));
    });
  });

  group('퀘스트 단계 저장 (LoreDialogueManager)', () {
    test('applyQuestStep / questSteps / 직렬화', () {
      final m = LoreDialogueManager.instance;
      m.lordAhnQuestStep = 0;
      m.applyQuestStep('lordahn', inc: 1);
      expect(m.questStepValue('lordahn'), 1);
      m.applyQuestStep('gaia', set: 5);
      expect(m.questSteps, {
        'lordahn': 1,
        'lastditch': 0,
        'gaia': 5,
        'water': 0,
        'wivern': 0,
      });

      m.applyQuestStep('wivern', set: 2);
      expect(m.questStepValue('wivern'), 2);

      final saved = m.getSaveFlags();
      expect(saved['lordAhnQuestStep'], 1);
      expect(saved['gaiaQuestStep'], 5);
      expect(saved['etc37'], 2);

      m.lordAhnQuestStep = 0;
      m.gaiaQuestStep = 0;
      m.loadSaveFlags(saved);
      expect(m.questStepValue('wivern'), 2);
      m.loadSaveFlags({
        'lordAhnQuestStep': 4,
        'gaiaQuestStep': 2,
        'weaponRoomVisited': true,
      });
      expect(m.lordAhnQuestStep, 4);
      expect(m.gaiaQuestStep, 2);
      expect(m.weaponRoomVisited, isTrue);
      // 원작 etc 비트 플래그는 스크립트 조건(getFlagsCopy)에도 노출된다.
      expect(m.getFlagsCopy()['weaponRoomVisited'], isTrue);
    });
  });
}

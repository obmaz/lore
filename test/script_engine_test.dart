import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/logic/lore_join.dart';

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
  const esper5 = ScriptContext(mindReadActive: true, maxEspLevel: 5);

  setUp(() => LoreScriptEngine.instance.resetForTest());
  tearDown(() => LoreScriptEngine.instance.resetForTest());

  group('JSON 스크립트 엔진 (assets/data/scripts.json)', () {
    test('1. 스크립트를 로드한다', () async {
      await LoreScriptEngine.instance.load();
      expect(
        LoreScriptEngine.instance.usingJson,
        isTrue,
        reason: 'JSON 로드 실패: ${LoreScriptEngine.instance.loadError}',
      );
      expect(LoreScriptEngine.instance.scripts.length, 50);
      expect(LoreScriptEngine.instance.scripts.map((s) => s.trigger).toSet(), {
        'step',
        'talk',
      });
    });

    test('2. step 스크립트(금화 발견) 보상과 1회성', () async {
      await LoreScriptEngine.instance.load();

      final run = LoreScriptEngine.instance.startStep(9, 10, 24, noCtx);
      expect(run, isNotNull);
      expect(run!.outcome.goldDelta, 5000);
      expect(run.hasPendingChoice, isFalse);

      // 두 번째 진입에서는 once 스크립트가 다시 실행되지 않는다.
      expect(LoreScriptEngine.instance.startStep(9, 10, 24, noCtx), isNull);
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
      // 표에 없는 좌표는 null → 게임의 Dart 이벤트 로직으로 폴백
      expect(LoreScriptEngine.instance.startStep(9, 11, 24, noCtx), isNull);
    });

    test('3. talk 스크립트의 선택지 분기 (Rigel)', () async {
      await LoreScriptEngine.instance.load();

      final run = LoreScriptEngine.instance.startTalk(12, 12, 48, noCtx);
      expect(run, isNotNull);
      expect(run!.hasPendingChoice, isTrue);
      expect(run.pendingChoice!.length, 3);
      expect(run.pendingChoice!.first, '좋소, 같이 모험을 합시다');
      // 전투 전 안내 메시지가 누적되어 있다
      expect(run.outcome.messages.length, 2);

      // 1번 선택지: "식량과 치료는 해결해 주겠소" → 식량 -5 + 합류
      final after = run.choose(1);
      expect(after.hasPendingChoice, isFalse);
      expect(after.outcome.foodDelta, -5);
      expect(after.outcome.recruits.single.key, 'rigel');
      expect(LoreJoin.byKey('rigel')!.hp, 1); // 원작과 동일한 빈사 상태

      // 2번 선택지(거절)는 합류하지 않는다
      LoreScriptEngine.instance.resetForTest();
      await LoreScriptEngine.instance.load();
      final decline = LoreScriptEngine.instance
          .startTalk(12, 12, 48, noCtx)!
          .choose(2);
      expect(decline.outcome.recruits, isEmpty);
      expect(decline.outcome.messages.last, contains('어쩔수 없군'));
    });

    test('4. require 조건에 따라 다른 스크립트가 선택된다 (Red Antares)', () async {
      await LoreScriptEngine.instance.load();

      // 특수 마법을 배우기 전 → 전수 스크립트
      final teach = LoreScriptEngine.instance.startTalk(17, 75, 52, noCtx)!;
      expect(teach.outcome.messages.first, contains('용암으로 변하면서'));
      expect(teach.outcome.setFlags, contains('specialMagicLearned'));
      expect(teach.outcome.recruits, isEmpty);

      // 배운 뒤 → 합류 스크립트
      final join = LoreScriptEngine.instance.startTalk(17, 75, 52, learned)!;
      expect(join.hasPendingChoice, isTrue);
      final chosen = join.choose(0);
      expect(chosen.outcome.recruits.single.key, 'red_antares');
      final red = LoreJoin.byKey('red_antares')!;
      expect(red.hp, 0); // 원작과 동일
      expect(red.resistance, 15);
    });

    test('5. ESP 조건 미충족 시 안내 스크립트가 나온다 (Spica)', () async {
      await LoreScriptEngine.instance.load();

      // 독심술 미사용 → 마음을 읽을 수 없다는 안내
      final cannot = LoreScriptEngine.instance.startTalk(18, 37, 31, noCtx)!;
      expect(cannot.outcome.messages.first, contains('나의 마음을 끌어낼수는 없습니다'));
      expect(cannot.hasPendingChoice, isFalse);

      // 독심술 사용 + 초능력 Lv.5 → 합류 선택지
      final can = LoreScriptEngine.instance.startTalk(18, 37, 31, esper5)!;
      expect(can.hasPendingChoice, isTrue);
      expect(can.choose(0).outcome.recruits.single.key, 'spica');
      expect(LoreJoin.byKey('spica')!.sex.name, 'female');
    });

    test('6. Mad Joe는 원작과 동일하게 6번 슬롯 고정으로 합류한다', () async {
      await LoreScriptEngine.instance.load();

      final run = LoreScriptEngine.instance.startTalk(6, 40, 15, noCtx)!;
      expect(run.hasPendingChoice, isTrue);
      final joined = run.choose(0);
      expect(joined.outcome.recruits.single.key, 'mad_joe');
      expect(joined.outcome.recruits.single.slot, 4); // 0-based = 6번 슬롯
    });

    test('8. 지형 변형(setTile)과 강제 이동(teleport) 스텝', () async {
      await LoreScriptEngine.instance.load();

      // 맵 6 (62,82) 상자: 메시지 + 금 1000 + 타일 44로 변경(원작 map[62,82] := 44)
      final chest = LoreScriptEngine.instance.startStep(6, 62, 82, noCtx)!;
      expect(chest.outcome.messages.first, contains('상자 속에서'));
      expect(chest.outcome.goldDelta, 1000);
      final change = chest.outcome.tileChanges.single;
      expect(change.x, 62);
      expect(change.y, 82);
      expect(change.tile, 44);
      expect(change.map, isNull); // 현재 맵에 적용

      // 맵 4 (20,39) Ancient Evil: 첫 방문은 대륙 안내 + 플래그 (원작 LORESPEC 맵 4)
      final first = LoreScriptEngine.instance.startTalk(4, 20, 39, noCtx)!;
      expect(first.outcome.setFlags, contains('ancientEvilMet'));
      expect(first.outcome.teleportX, isNull);
      expect(first.outcome.messages.length, 5);

      // 재방문은 비밀 통로로 강제 이동 (원작 x := 46; y := 41)
      final later = LoreScriptEngine.instance.startTalk(
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
      expect(LoreScriptEngine.instance.startTalk(12, 12, 48, noCtx), isNull);
    });

    test('10. 원작 잔여 좌표 이벤트 이관 (맵 4/6/11/14/15)', () async {
      await LoreScriptEngine.instance.load();
      final engine = LoreScriptEngine.instance;

      // 1) 맵 4 (40,18) 공간 이동 (원작 x := 46; y := 41)
      final jump = engine.startStep(4, 40, 18, noCtx)!;
      expect(jump.outcome.teleportX, 46);
      expect(jump.outcome.teleportY, 41);
      expect(jump.outcome.messages.single, contains('공간 이동'));

      // 2) 맵 4 (26,16) Draconian: 강의 → 재방문 시 영입 선택
      final lecture = engine.startStep(4, 26, 16, noCtx)!;
      expect(lecture.outcome.setFlags, contains('draconianMet'));
      final join = engine.startStep(
        4,
        26,
        16,
        const ScriptContext(flags: {'draconianMet'}),
      )!;
      expect(join.pendingChoice, isNotNull);
      final joined = join.choose(0).outcome.recruits.single;
      expect(joined.key, 'draconian');
      expect(joined.slot, 4); // 원작 join(62,6) = 6번 슬롯
      // 원작 join(62,6)은 레벨 17로 편입시킨다.
      expect(LoreJoin.byKey('draconian')!.battleLevel, 17);

      // 3) 맵 6 (51,12) 수감소 병사 전투 (2명 → 재방문 7명)
      final prison = engine.startStep(6, 51, 12, noCtx)!;
      expect(prison.outcome.battleMonsters, [26, 26]);
      expect(prison.outcome.tileChanges.length, 4);
      expect(prison.outcome.setFlags, contains('prisonBattleDone'));
      final prisonAgain = engine.startStep(
        6,
        51,
        12,
        const ScriptContext(flags: {'prisonBattleDone'}),
      )!;
      expect(prisonAgain.outcome.battleMonsters.length, 7);

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
      final mummy = engine.startStep(11, 12, 24, noCtx)!;
      expect(mummy.outcome.battleMonsters, [35, 35, 26]);

      // 7) 맵 14 (16,20) 황금의 방패 / 맵 15 (14,7) 방패, (45,19) 갑옷
      expect(engine.startStep(14, 16, 20, noCtx)!.outcome.equips.single.kind, 'shield');
      expect(engine.startStep(15, 14, 7, noCtx)!.outcome.equips.single.kind, 'shield');
      expect(engine.startStep(15, 45, 19, noCtx)!.outcome.equips.single.kind, 'armor');

      // 8) 맵 15 y=27 QUAKE 보스 (Zombie ×2 + ArchiGagoyle)
      expect(engine.startStep(15, 20, 27, noCtx)!.outcome.battleMonsters, [36, 36, 42]);
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
  });
}

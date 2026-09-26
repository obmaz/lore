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
      expect(LoreScriptEngine.instance.scripts.length, 568);
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

    test('3. talk 스크립트의 선택지 분기 (Rigel)', () async {
      await LoreScriptEngine.instance.load();

      final run = LoreScriptEngine.instance.startTalk(12, 12, 48, noCtx);
      expect(run, isNotNull);
      expect(run!.hasPendingChoice, isTrue);
      expect(run.pendingChoice!.length, 3);
      expect(run.pendingChoice!.first, '좋소, 같이 모험을 합시다');
      // 원작 `Print` 줄 수만큼 안내 메시지가 누적된다(마주침 + Rigel의 말)
      expect(run.outcome.messages.length, 8);
      expect(run.outcome.messages.first, contains('몸을 가누지'));

      // 1번 선택지: "식량과 치료는 해결해 주겠소" → 식량 -5 + 합류
      final after = run.choose(1);
      expect(after.hasPendingChoice, isFalse);
      expect(after.outcome.foodDelta, -5);
      expect(after.outcome.recruits.single.key, 'rigel');
      expect(LoreJoin.byKey('rigel')!.hp, 1); // 원작과 동일한 빈사 상태

      // 2번 선택지(거절)는 합류하지 않는다(원작도 아무 말 없이 빠져나간다)
      LoreScriptEngine.instance.resetForTest();
      await LoreScriptEngine.instance.load();
      final base = LoreScriptEngine.instance.startTalk(12, 12, 48, noCtx)!;
      final decline = base.choose(2);
      expect(decline.outcome.recruits, isEmpty);
      // 거절은 안내 문구를 더하지 않는다(원작에 문구가 없다)
      expect(decline.outcome.messages.length, base.outcome.messages.length);
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

      // 독심술 미사용 → 마음을 읽을 수 없다는 안내(원작 문구 그대로)
      final cannot = LoreScriptEngine.instance.startTalk(18, 37, 31, noCtx)!;
      expect(cannot.outcome.messages.join(''), contains('나의 마음을 끌어낼수는 없습니'));
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
      final ancient = engine.startTalk(4, 20, 39, noCtx)!;
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
      expect(hidra.outcome.setFlags, contains('bossHidraDefeated'));
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
      expect(dragon.outcome.setFlags, contains('bossHugeDragonDefeated'));

      // 3) 지름길(맵 17 x = 72)은 통로 타일 3곳을 연다.
      final shortcut = engine.startStep(17, 72, 30, noCtx)!;
      expect(shortcut.outcome.tileChanges.length, 3);
      expect(shortcut.outcome.tileChanges.first.tile, 44);
    });

    test('14. 영역 지형 변형(setTileArea)과 난수 소환/난수 플래그', () async {
      await LoreScriptEngine.instance.load();
      final engine = LoreScriptEngine.instance;

      // 1) 맵 19 (41,39) 레버: 통로를 영역 단위로 열고 7개 방 중 하나를 뽑는다.
      final leverB = engine.startStep(19, 41, 39, noCtx)!;
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

      // 2) 늪위를 걷는 마법이 켜져 있으면 레버를 당길 수 없다 (원작 etc[3] > 0).
      const swampOn = ScriptContext(flags: {'swampWalkActive'});
      final blocked = engine.startStep(19, 11, 40, swampOn)!;
      expect(blocked.outcome.messages.single, contains('늪위를 걷는 마법'));
      expect(blocked.outcome.tileChanges, isEmpty);

      // 3) 정답 방에서만 Crab God 왕과 싸운다 (방 번호는 무작위로 정해진다).
      final room3 = engine.startStep(
        19,
        18,
        6,
        const ScriptContext(flags: {'evilSealRoom3'}),
      )!;
      expect(room3.outcome.battleMonsters, List.filled(7, 59));
      expect(room3.outcome.setFlags, contains('evilSealRoomCleared'));

      // 4) 다른 방은 "봉인이 발견되지 않았다" 안내만 나온다.
      final wrongRoom = engine.startStep(
        19,
        18,
        6,
        const ScriptContext(flags: {'evilSealRoom4'}),
      )!;
      expect(wrongRoom.outcome.battleMonsters, isEmpty);
      expect(wrongRoom.outcome.messages.single, contains('봉인이 발견되지 않았다'));

      // 5) 봉인이 남아 있는 동안 y 8~12에서는 난수 마리(3~5)의 수호 몬스터가 나온다.
      final guardians = engine.startStep(
        19,
        20,
        9,
        const ScriptContext(flags: {'evilSealLeverB'}),
      )!;
      expect(guardians.outcome.battleMonsters.length, inInclusiveRange(3, 5));
      expect(guardians.outcome.battleMonsters.every((id) => id == 59), isTrue);
      // 봉인을 이미 풀었다면 나오지 않는다.
      expect(
        engine.startStep(
          19,
          20,
          9,
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

      // 2) 맵 22 (25,18): Wraith 5 + Death Knight 1
      final ambush = engine.startStep(22, 25, 18, noCtx)!;
      expect(ambush.outcome.battleMonsters.where((m) => m == 60).length, 5);
      expect(ambush.outcome.battleMonsters.where((m) => m == 63).length, 1);
      expect(ambush.outcome.setFlags, contains('keep2AmbushCleared'));

      // 3) 맵 22 (y=25, x=24~26) 수문장 5명
      final guards = engine.startStep(22, 25, 25, noCtx)!;
      expect(guards.outcome.battleMonsters, [61, 58, 56, 55, 60]);

      // 4) 맵 23 (25,27): 함정 해제 + 영역 타일 변형(ifZero)
      final trap = engine.startStep(23, 25, 27, noCtx)!;
      final zeroArea = trap.outcome.tileAreas.firstWhere((a) => a.ifZero == 39);
      expect(zeroArea.xMin, 12);
      expect(zeroArea.xMax, 39);
      expect(zeroArea.yMin, 7);
      expect(zeroArea.yMax, 34);

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
      final corridor = engine.startStep(25, 15, 34, noCtx)!;
      expect(corridor.outcome.tileAreas.length, 3);
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
      // 미궁을 깨면 지상으로 돌아간다.
      final back = engine.startStep(
        20,
        30,
        13,
        const ScriptContext(flags: {'den7MazeCleared'}),
      )!;
      expect(back.outcome.teleportMap, 4);

      // 5) 맵 22 상시 습격: 좌표와 무관하게 Wraith 무리가 나오고 지형이 바뀐다.
      final ambush = engine.startStep(22, 40, 10, noCtx)!;
      expect(ambush.outcome.battleMonsters, [60, 60, 60, 60, 60]);
      final tile = ambush.outcome.playerTiles.single;
      expect(tile.ifZero, 40);
      expect(tile.tile, 46);
      // (25,18) 등 지정 이벤트가 우선한다.
      expect(
        engine.startStep(22, 25, 18, noCtx)!.outcome.battleMonsters.length,
        6,
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

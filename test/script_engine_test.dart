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
      expect(LoreScriptEngine.instance.scripts.length, 25);
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

    test('7. JSON이 없으면 스크립트 없음으로 동작하고 게임은 Dart 로직으로 폴백한다', () async {
      await LoreScriptEngine.instance.load(bundle: _MissingBundle());

      expect(LoreScriptEngine.instance.usingJson, isFalse);
      expect(LoreScriptEngine.instance.loadError, isNotNull);
      expect(LoreScriptEngine.instance.scripts, isEmpty);
      expect(LoreScriptEngine.instance.startStep(9, 10, 24, noCtx), isNull);
      expect(LoreScriptEngine.instance.startTalk(12, 12, 48, noCtx), isNull);
    });
  });
}

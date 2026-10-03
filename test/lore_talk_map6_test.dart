import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/game/lore_world_manager.dart';
import 'package:lore/logic/lore_talk_dispatcher.dart';
import 'package:lore/logic/lore_talk_procedures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LoreScriptEngine scripts;
  final world = LoreWorldManager.instance;
  final dialogues = LoreDialogueManager.instance;

  setUp(() async {
    world.resetRulesForTest();
    await world.loadData();
    dialogues.loadFlags({});
    scripts = LoreScriptEngine()
      ..loadFromJson(File('assets/data/scripts.json').readAsStringSync());
  });

  tearDown(() {
    world.resetRulesForTest();
    dialogues.loadFlags({});
  });

  LoreTalkDispatch resolve(
    int x,
    int y, [
    ScriptContext context = const ScriptContext(),
  ]) => LoreTalkDispatcher.resolve(
    mapId: 6,
    x: x,
    y: y,
    context: context,
    world: world,
    scripts: scripts,
  );

  group('LORETALK 맵 6 CASTLE LORE 대화 분기 검증 (LORETALK.PAS:17-383)', () {
    test('(9,64) 경비병 및 일반 주민 대사 분기 검증', () {
      // LoreTalkProcedures 직접 호출
      final direct = LoreTalkProcedures.map6(
        9,
        64,
        const ScriptContext(),
        scripts,
      )!;
      expect(direct.outcome.messages.any((m) => m.contains('Serpent')), isTrue);

      // 디스패처 호출
      final dispatched = resolve(9, 64);
      expect(dispatched.source, LoreTalkSource.script);
      expect(
        dispatched.script?.outcome.messages.any((m) => m.contains('Serpent')),
        isTrue,
      );
    });

    test('(51,72) 현자 대사: etc50_bit5 미설정 시 피라밋 안내, 설정 시 MENACE 몬스터 안내', () {
      // 1. 미설정 시 피라밋 안내
      final first = resolve(51, 72);
      expect(
        first.script?.outcome.messages.any((m) => m.contains('피라밋')),
        isTrue,
      );
      expect(first.script?.outcome.setFlags, contains('menaceInfoGiven'));

      // 2. etc50_bit5 설정 시 MENACE 몬스터 안내
      final second = resolve(
        51,
        72,
        const ScriptContext(flags: {'etc50_bit5'}),
      );
      expect(
        second.script?.outcome.messages.any((m) => m.contains('MENACE')),
        isTrue,
      );
    });

    test('(63,76) Jr. Antares 영혼: etc50_bit1 미설정 시 비밀 통로 개방 및 플래그 설정', () {
      final run = resolve(63, 76);
      expect(run.source, LoreTalkSource.script);
      expect(
        run.script?.outcome.messages.any((m) => m.contains('Jr. Antares')),
        isTrue,
      );
      expect(run.script?.outcome.setFlags, contains('jrAntaresSecretFound'));
      expect(run.script?.outcome.tileAreas.any((a) => a.tile == 44), isTrue);

      // 플래그 설정 후 재방문: 원본 `at(63,76) and (etc[50] and bit1 = 0)`는 아무것도 찍지 않는다.
      dialogues.setFlag('jrAntaresSecretFound');
      final rerun = resolve(
        63,
        76,
        const ScriptContext(flags: {'jrAntaresSecretFound'}),
      );
      expect(rerun.source, LoreTalkSource.none);
    });

    test('(40,15) Mad Joe 영혼 및 합류 분기', () {
      // 1. 첫 만남: 선택지(수락/거절)
      final first = resolve(40, 15);
      expect(first.source, LoreTalkSource.script);
      expect(first.script?.hasPendingChoice, isTrue);

      final accepted = first.script!.choose(0);
      expect(accepted.outcome.recruits.single.key, 'mad_joe');
      expect(accepted.outcome.setFlags, contains('madJoeJoined'));

      // 2. 합류 후: 원본 `at(40,15)`에는 else가 없고 칸도 47로 바뀌어 아무것도 없다.
      dialogues.setFlag('madJoeJoined');
      final second = resolve(
        40,
        15,
        const ScriptContext(flags: {'madJoeJoined'}),
      );
      expect(second.source, LoreTalkSource.none);
    });

    test('(50,51)/(52,51) 도전 관문: etc30_bit1, 퀘스트 단계별 분기', () {
      // lordahn 단계 < 3: 진입 거부
      final blocked = resolve(
        50,
        51,
        const ScriptContext(questSteps: {'lordahn': 1}),
      );
      expect(
        blocked.script?.outcome.messages.any((m) => m.contains('성주님을 만나')),
        isTrue,
      );

      // lordahn 단계 >= 3: 도전 수락 선택
      final challenge = resolve(
        50,
        51,
        const ScriptContext(questSteps: {'lordahn': 3}),
      );
      expect(challenge.script?.hasPendingChoice, isTrue);

      // 이미 수락/개방된 경우 (etc30_bit1)
      final passed = resolve(
        50,
        51,
        const ScriptContext(flags: {'etc30_bit1'}),
      );
      expect(
        passed.script?.outcome.messages.any((m) => m.contains('행운을 빌겠소')),
        isTrue,
      );
    });

    test('(51,87) 성문 외곽 경비병 축복: etc30_bit2 설정 및 성문 개방', () {
      final first = resolve(51, 87);
      expect(
        first.script?.outcome.messages.any((m) => m.contains('난 당신을 믿소')),
        isTrue,
      );
      expect(first.script?.outcome.setFlags, contains('loreChallengeBlessed'));
      expect(first.script?.outcome.tileAreas.any((a) => a.tile == 44), isTrue);

      final second = resolve(
        51,
        87,
        const ScriptContext(flags: {'etc30_bit2'}),
      );
      expect(
        second.script?.outcome.messages.any((m) => m.contains('힘내시오')),
        isTrue,
      );
    });

    test('(51,28) Lord Ahn 알현 퀘스트 0..6 단계 분기', () {
      for (var step = 0; step <= 6; step++) {
        final run = resolve(
          51,
          28,
          ScriptContext(questSteps: {'lordahn': step}),
        );
        expect(run.source, LoreTalkSource.script);
        expect(run.script?.script.id, 'talk-6-51-28-q$step');
      }
    });

    test('성내 시설 좌표(상점, 병원, 훈련소, 식료품점)는 facility로 우선 판정된다', () {
      expect(resolve(8, 71).source, LoreTalkSource.facility); // 무기점 (1)
      expect(resolve(87, 14).source, LoreTalkSource.facility); // 병원 (2)
      expect(resolve(21, 12).source, LoreTalkSource.facility); // 훈련소 (3)
      expect(resolve(87, 73).source, LoreTalkSource.facility); // 식료품점 (4)
    });
  });
}

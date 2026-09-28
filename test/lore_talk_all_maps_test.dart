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

  LoreTalkDispatch resolve(int map, int x, int y, [ScriptContext context = const ScriptContext()]) =>
      LoreTalkDispatcher.resolve(
        mapId: map,
        x: x,
        y: y,
        heroName: 'Hero',
        context: context,
        party: const [],
        mindReadCount: 0,
        world: world,
        scripts: scripts,
        dialogues: dialogues,
      );

  group('LORETALK 맵 7, 9, 10, 24, 27 전체 대화 분기 검증', () {
    test('맵 7 (LASTDITCH): 주민 대사, Polaris 합류, 퀘스트 게이트 및 성주 대사 검증', () {
      // 1. (51, 55) 주민
      final direct = LoreTalkProcedures.map7(51, 55, const ScriptContext(), scripts)!;
      expect(direct.outcome.messages.any((m) => m.contains('VALIANT PEOPLES')), isTrue);
      expect(resolve(7, 51, 55).script?.outcome.messages.any((m) => m.contains('VALIANT PEOPLES')), isTrue);

      // 2. (37, 41) Polaris 영입
      final polaris = resolve(7, 37, 41);
      expect(polaris.source, LoreTalkSource.script);
      expect(polaris.script?.hasPendingChoice, isTrue);
      final accepted = polaris.script!.choose(0);
      expect(accepted.outcome.recruits.single.key, 'polaris');
      expect(accepted.outcome.setFlags, contains('polarisJoined'));

      // 3. 성내 통로 게이트 (36, 19): lastditch 퀘스트 단계별
      final gateBlocked = resolve(7, 36, 19, const ScriptContext(questSteps: {'lastditch': 0}));
      expect(gateBlocked.script?.outcome.messages.any((m) => m.contains('성주님을 만나')), isTrue);
      final gatePassed = resolve(7, 36, 19, const ScriptContext(questSteps: {'lastditch': 1}));
      expect(gatePassed.script?.outcome.messages.any((m) => m.contains('성공하기를')), isTrue);

      // 4. (38, 17) LASTDITCH 성주 퀘스트 0..3 단계
      for (var step = 0; step <= 3; step++) {
        final lord = resolve(7, 38, 17, ScriptContext(questSteps: {'lastditch': step}));
        expect(lord.source, LoreTalkSource.script);
        expect(lord.script?.script.id, 'talk-7-38-17-q$step');
      }

      // 5. 시설 확인
      expect(resolve(7, 59, 56).source, LoreTalkSource.facility); // 무기점
      expect(resolve(7, 17, 56).source, LoreTalkSource.facility); // 병원
      expect(resolve(7, 18, 19).source, LoreTalkSource.facility); // 훈련소
      expect(resolve(7, 57, 17).source, LoreTalkSource.facility); // 식료품점
    });

    test('맵 9 (GAIA TERRA): 주민 대사, 퀘스트 게이트 및 성주 대사 검증', () {
      // 1. (24, 38) 주민
      final villager = resolve(9, 24, 38);
      expect(villager.script?.outcome.messages.any((m) => m.contains('EVIL SEAL')), isTrue);

      // 2. (34, 24) 게이트: gaia 퀘스트 단계별
      final gateBlocked = resolve(9, 34, 24, const ScriptContext(questSteps: {'gaia': 0}));
      expect(gateBlocked.script?.outcome.messages.any((m) => m.contains('성주님을 만나')), isTrue);
      final gatePassed = resolve(9, 34, 24, const ScriptContext(questSteps: {'gaia': 1}));
      expect(gatePassed.script?.outcome.messages.any((m) => m.contains('성공을 빌겠습니다')), isTrue);

      // 3. (42, 25) GAIA TERRA 성주 퀘스트 0..6 단계
      for (var step = 0; step <= 6; step++) {
        final lord = resolve(9, 42, 25, ScriptContext(questSteps: {'gaia': step}));
        expect(lord.source, LoreTalkSource.script);
        expect(lord.script?.script.id, 'talk-9-42-25-q$step');
      }

      // 4. 시설 확인
      expect(resolve(9, 37, 10).source, LoreTalkSource.facility); // 무기점
      expect(resolve(9, 9, 39).source, LoreTalkSource.facility); // 병원
      expect(resolve(9, 12, 11).source, LoreTalkSource.facility); // 훈련소
      expect(resolve(9, 40, 37).source, LoreTalkSource.facility); // 식료품점
    });

    test('맵 10 (WATER FIELD): 주민 대사, Lore Hunter 영입, 성주 대사 검증', () {
      // 1. (11, 16) 주민
      final villager = resolve(10, 11, 16);
      expect(villager.script?.outcome.messages.any((m) => m.contains('NOTICE')), isTrue);

      // 2. (40, 56) Lore Hunter 영입
      final hunter = resolve(10, 40, 56);
      expect(hunter.source, LoreTalkSource.script);
      expect(hunter.script?.hasPendingChoice, isTrue);
      final accepted = hunter.script!.choose(0);
      expect(accepted.outcome.recruits.single.key, 'lore_hunter');
      expect(accepted.outcome.setFlags, contains('loreHunterJoined'));

      // 3. (25, 18) WATER FIELD 성주 퀘스트 0..5 단계
      for (var step = 0; step <= 5; step++) {
        final lord = resolve(10, 25, 18, ScriptContext(questSteps: {'water': step}));
        expect(lord.source, LoreTalkSource.script);
        expect(lord.script?.script.id, 'talk-10-25-18-q$step');
      }

      // 4. 시설 확인
      expect(resolve(10, 11, 30).source, LoreTalkSource.facility); // 무기점
      expect(resolve(10, 33, 60).source, LoreTalkSource.facility); // 병원
      expect(resolve(10, 36, 32).source, LoreTalkSource.facility); // 훈련소
      expect(resolve(10, 17, 57).source, LoreTalkSource.facility); // 식료품점
    });

    test('맵 24 (LAST SHELTER): 피난민 대사 및 제작자 안 영기 대화 검증', () {
      // 1. (17, 15) 주민
      final resident = resolve(24, 17, 15);
      expect(resident.script?.outcome.messages.any((m) => m.contains('Ancient Evil')), isTrue);

      // 2. (33, 10) 제작자 안 영기
      final creator = resolve(24, 33, 10);
      expect(creator.source, LoreTalkSource.script);
      expect(creator.script?.outcome.messages.any((m) => m.contains('안 영기')), isTrue);
      expect(creator.script?.outcome.setFlags, contains('programmerMet'));

      // 3. 시설 확인
      expect(resolve(24, 33, 21).source, LoreTalkSource.facility); // 무기점
      expect(resolve(24, 15, 36).source, LoreTalkSource.facility); // 병원
      expect(resolve(24, 11, 22).source, LoreTalkSource.facility); // 훈련소
      expect(resolve(24, 33, 35).source, LoreTalkSource.facility); // 식료품점
    });

    test('맵 27 (운명의 피라미드): 영혼 대사, 유골 문서 선택지, 기본 fallback 대사 검증', () {
      // 1. (15, 6) 영웅의 영혼
      final hero = resolve(27, 15, 6);
      expect(hero.source, LoreTalkSource.script);
      expect(hero.script?.script.id, 'talk-27-15-6');

      // 2. (10, 14) Red Antares 영혼
      final red = resolve(27, 10, 14);
      expect(red.source, LoreTalkSource.script);
      expect(red.script?.script.id, 'talk-27-10-14');

      // 3. (21, 12) 유골 문서 선택지
      final doc = resolve(27, 21, 12);
      expect(doc.source, LoreTalkSource.script);
      expect(doc.script?.hasPendingChoice, isTrue);

      // 4. 기타 유골 좌표 fallback (talk-27-any)
      final anyBone = resolve(27, 18, 20);
      expect(anyBone.source, LoreTalkSource.script);
      expect(anyBone.script?.script.id, 'talk-27-any');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/game/lore_dungeon_event_manager.dart';
import 'package:lore/models/party_member.dart';

void main() {
  group('LORE 1993 [3단계] 4대 마을 고유 NPC 대화 & 던전 특수 이벤트 단위 테스트', () {
    late LoreDialogueManager dialogue;
    late LoreDungeonEventManager dungeonEvents;
    late PartyMember hero;

    setUp(() {
      dialogue = LoreDialogueManager.instance;
      // 플래그 초기화
      dialogue.loadFlags({});

      dungeonEvents = LoreDungeonEventManager.instance;

      hero = PartyMember(
        name: '카이저',
        sex: Gender.male,
        playerClass: PlayerClass.knight,
        strength: 18,
        mentality: 12,
        concentration: 12,
        endurance: 16,
        resistance: 20,
        agility: 15,
        accArms: 18,
        accMagic: 10,
        accEsp: 5,
        luck: 15,
      );
    });

    test('1. 맵 6 (성도 CASTLE LORE) 고유 대화 및 성주/영혼/현자 인터랙션 검증', () {
      // 1) 경비병
      final guardTalk = dialogue.getDialogue(6, 9, 64, hero.name);
      expect(guardTalk, contains('Serpent와 Insects와 Python은 맹독이 있으니'));

      // 2) 성주 Lord Ahn
      final lordTalk1 = dialogue.getDialogue(6, 50, 51, hero.name);
      expect(lordTalk1, contains('Lord Ahn'));
      expect(dialogue.metLordAhn, isTrue);

      final gateTalk = dialogue.getDialogue(6, 50, 51, hero.name);
      expect(gateTalk, contains('남쪽 성문을 개방했습니다'));
      expect(dialogue.castleGateOpen, isTrue);

      // 3) Jr. Antares의 영혼 (비밀 통로)
      final jrTalk = dialogue.getDialogue(6, 63, 76, hero.name);
      expect(jrTalk, contains('Jr. Antares'));
      expect(dialogue.jrAntaresSecretFound, isTrue);

      // 4) 피라밋 현자
      final sageTalk = dialogue.getDialogue(6, 51, 72, hero.name);
      expect(sageTalk, contains('또 다른 지식의 성전'));
      expect(dialogue.metPyramidSage, isTrue);
    });

    test('2. 맵 7 (LASTDITCH) 성주 퀘스트 및 전사 Polaris 동료 영입 검증', () {
      // 1) 전사 Polaris 영입
      final polarisTalk = dialogue.getDialogue(7, 37, 41, hero.name);
      expect(polarisTalk, contains('Polaris'));
      expect(dialogue.polarisJoined, isTrue);

      // 2) LASTDITCH 성주 첫 대면: Major Mummy 의뢰
      final quest1 = dialogue.getDialogue(7, 38, 17, hero.name);
      expect(quest1, contains('Major Mummy'));
      expect(dialogue.lastditchQuestStep, 1);

      // 3) 보스 처치 전 다시 말걸기
      final questWaiting = dialogue.getDialogue(7, 38, 17, hero.name);
      expect(questWaiting, contains('속히 처단해 주시오'));

      // 4) 보스 격퇴 후 보고: EXP 보상 및 GROUND GATE 안내
      dialogue.bossMajorMummyDefeated = true;
      final questComplete = dialogue.getDialogue(7, 38, 17, hero.name);
      expect(questComplete, contains('EXP +10,000'));
      expect(questComplete, contains('GROUND GATE'));
      expect(dialogue.lastditchQuestStep, 2);
    });

    test('3. 맵 9 (GAIA TERRA) 성주 퀘스트: 황금의 봉인 및 ArchiGagoyle 격퇴 검증', () {
      // 1) 성주 첫 대면: 황금의 봉인 의뢰
      final gQuest1 = dialogue.getDialogue(9, 42, 25, hero.name);
      expect(gQuest1, contains('황금의 봉인'));
      expect(dialogue.gaiaQuestStep, 1);

      // 2) 황금의 봉인 획득 후 보고
      dialogue.goldenSealFound = true;
      final gQuest2 = dialogue.getDialogue(9, 42, 25, hero.name);
      expect(gQuest2, contains('황금의 봉인을 찾아'));
      expect(gQuest2, contains('ArchiGagoyle'));
      expect(dialogue.gaiaQuestStep, 2);

      // 3) ArchiGagoyle 격퇴 후 보고: Water Key 획득
      dialogue.bossArchiGagoyleDefeated = true;
      final gQuest3 = dialogue.getDialogue(9, 42, 25, hero.name);
      expect(gQuest3, contains('Water Key'));
      expect(dialogue.hasWaterKey, isTrue);
      expect(dialogue.gaiaQuestStep, 3);
    });

    test(
      '4. 맵 10 (WATER FIELD) 성주 퀘스트: Hidra & Huge Dragon 및 Lore Hunter 영입 검증',
      () {
        // 1) 특공대장 Lore Hunter 영입
        final hunterTalk = dialogue.getDialogue(10, 40, 56, hero.name);
        expect(hunterTalk, contains('Lore Hunter'));
        expect(dialogue.loreHunterJoined, isTrue);

        // 2) 성주 첫 대면: NOTICE 동굴의 Hidra 처단 의뢰
        final wQuest1 = dialogue.getDialogue(10, 25, 18, hero.name);
        expect(wQuest1, contains('Hidra'));
        expect(dialogue.waterFieldQuestStep, 1);

        // 3) Hidra 격퇴 후 보고: Huge Dragon 처단 의뢰
        dialogue.bossHidraDefeated = true;
        final wQuest2 = dialogue.getDialogue(10, 25, 18, hero.name);
        expect(wQuest2, contains('Huge Dragon'));
        expect(dialogue.waterFieldQuestStep, 2);

        // 4) Huge Dragon 격퇴 후 보고: Swamp Key 획득
        dialogue.bossHugeDragonDefeated = true;
        final wQuest3 = dialogue.getDialogue(10, 25, 18, hero.name);
        expect(wQuest3, contains('Swamp Key'));
        expect(dialogue.hasSwampKey, isTrue);
        expect(dialogue.waterFieldQuestStep, 3);
      },
    );

    test('5. 던전 및 필드 특수 이벤트 (식량 나무, Draconian, 황금봉인, 보스전) 검증', () {
      // 1) 맵 1 식량 나무 (94, 68)
      final treeEvent = dungeonEvents.checkEvent(1, 94, 68, [hero]);
      expect(treeEvent, isNotNull);
      expect(treeEvent!.type, DungeonEventType.foodGain);
      expect(treeEvent.foodGained, 100);

      // 중복 수확 차단
      final treeAgain = dungeonEvents.checkEvent(1, 94, 68, [hero]);
      expect(treeAgain!.type, DungeonEventType.dialogueOnly);
      expect(treeAgain.foodGained, 0);

      // 2) 맵 4 Draconian 피라미드 (26, 16)
      final dracEvent = dungeonEvents.checkEvent(4, 26, 16, [hero]);
      expect(dracEvent, isNotNull);
      expect(dracEvent!.type, DungeonEventType.knowledgeGained);
      expect(dracEvent.message, contains('시그너스 X-1 블랙홀'));

      // 3) 맵 11 PYRAMID 보스전 (Major Mummy)
      final mummyEvent = dungeonEvents.checkEvent(11, 30, 30, [hero]);
      expect(mummyEvent, isNotNull);
      expect(mummyEvent!.type, DungeonEventType.bossBattle);
      expect(mummyEvent.bossEnemies!.first.name, 'Major Mummy');

      // 4) 맵 13 EVIL SEAL 황금의 봉인 해제
      final sealEvent = dungeonEvents.checkEvent(13, 25, 25, [hero]);
      expect(sealEvent, isNotNull);
      expect(sealEvent!.type, DungeonEventType.sealBroken);
      expect(dialogue.goldenSealFound, isTrue);

      // 5) 맵 17 NOTICE 보스전 (삼두룡 Hidra)
      final hidraEvent = dungeonEvents.checkEvent(17, 15, 15, [hero]);
      expect(hidraEvent, isNotNull);
      expect(hidraEvent!.bossEnemies!.length, 3);
      expect(hidraEvent.bossEnemies!.first.name, contains('Hidra'));

      // 6) 맵 18 LOCKUP 보스전 (Huge Dragon)
      final dragonEvent = dungeonEvents.checkEvent(18, 28, 28, [hero]);
      expect(dragonEvent, isNotNull);
      expect(dragonEvent!.bossEnemies!.first.name, 'Huge Dragon');
    });

    test('6. 세이브/로드 플래그 직렬화 및 복원 검증', () {
      dialogue.metLordAhn = true;
      dialogue.castleGateOpen = true;
      dialogue.bossMajorMummyDefeated = true;
      dialogue.hasWaterKey = true;
      dialogue.hasSwampKey = true;
      dialogue.polarisJoined = true;
      dialogue.loreHunterJoined = true;

      final flags = dialogue.getFlagsCopy();
      expect(flags['metLordAhn'], isTrue);
      expect(flags['hasWaterKey'], isTrue);
      expect(flags['hasSwampKey'], isTrue);

      // 새 매니저에 복원
      final newManager = LoreDialogueManager.instance;
      newManager.loadFlags({});
      expect(newManager.metLordAhn, isFalse);

      newManager.loadFlags(flags);
      expect(newManager.metLordAhn, isTrue);
      expect(newManager.hasWaterKey, isTrue);
      expect(newManager.hasSwampKey, isTrue);
    });
  });
}

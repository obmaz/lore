import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/game/lore_dungeon_event_manager.dart';
import 'package:lore/logic/lore_join.dart';
import 'package:lore/logic/lore_spec_procedures.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/party_member.dart';

void main() {
  // JSON 스크립트(scripts.json) 로드를 위해 필요하다.
  TestWidgetsFlutterBinding.ensureInitialized();

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

    test('5. 던전 및 필드 특수 이벤트 (식량 나무 / JSON 스크립트 이관분) 검증', () async {
      // 1) 맵 1 식량 나무 (94, 68) - 원작 on-enter 이벤트라 Dart가 담당
      final treeEvent = dungeonEvents.checkEvent(1, 94, 68, [hero]);
      expect(treeEvent, isNotNull);
      expect(treeEvent!.type, DungeonEventType.foodGain);
      expect(treeEvent.foodGained, 100);

      // 중복 수확 차단
      final treeAgain = dungeonEvents.checkEvent(1, 94, 68, [hero]);
      expect(treeAgain!.type, DungeonEventType.dialogueOnly);
      expect(treeAgain.foodGained, 0);

      // 2) 나머지 좌표 이벤트는 모두 JSON 스크립트가 담당한다.
      //    (근사 좌표로 만들어 두었던 Dart 이벤트는 제거했다.)
      await LoreScriptEngine.instance.load();
      expect(
        LoreScriptEngine.instance.usingJson,
        isTrue,
        reason: 'JSON 스크립트 로드 실패: ${LoreScriptEngine.instance.loadError}',
      );
      expect(
        dungeonEvents.checkEvent(11, 30, 30, [hero]),
        isNull,
        reason: '임의 좌표 근사 보스전은 더 이상 없어야 한다',
      );

      final engine = LoreScriptEngine.instance;
      // 맵 4 (26,16) Draconian 강의 → 영입
      expect(
        LoreSpecProcedures.map4(
          26,
          16,
          const ScriptContext(),
          engine,
        )!.outcome.messages,
        isNotEmpty,
      );
      // 맵 11 (y=24) 미이라의 방 → Major Mummy 전투
      // (원작 조건: `party.etc[13] = 1` = LASTDITCH 퀘스트 단계 1)
      final mummy = engine.startStep(
        11,
        12,
        24,
        const ScriptContext(questSteps: {'lastditch': 1}),
      )!;
      expect(mummy.outcome.battleMonsters, [35, 35, 26]);
      // 맵 12 (18,10) 황금의 봉인 → 원작 좌표
      final seal = engine.startStep(12, 18, 10, const ScriptContext())!;
      expect(seal.outcome.setFlags, contains('goldenSealFound'));
      expect(
        engine.startStep(13, 25, 25, const ScriptContext()),
        isNull,
        reason: '임의 좌표(맵 13) 봉인 이벤트는 제거되어야 한다',
      );
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

    test('7. 원작 join(num, partynum) 동료 영입 이식 검증', () {
      // 원작 LORESUB.PAS:1042 join - 몬스터 템플릿 기반 파티원 생성
      final orc = Monster.create(1);
      final joined = PartyMember.fromMonsterTemplate(orc, name: 'TestRecruit');
      expect(joined.name, 'TestRecruit');
      expect(joined.playerClass, PlayerClass.none); // 원작 class := 0
      expect(joined.resistance, orc.resistance ~/ 2); // 저항력 절반
      expect(joined.concentration, 0); // 집중력 0
      expect(joined.accEsp, 0); // 초능력 명중 0
      expect(joined.luck, 10);
      expect(joined.battleLevel, orc.level);
      expect(joined.magicLevel, orc.castLevel * 3 == 0 ? 1 : orc.castLevel * 3);
      expect(joined.espLevel, 1);
      expect(joined.weaPower, orc.level * 2 + 10); // 맨손 위력 공식
      expect(joined.armPower, orc.ac);
      expect(joined.hp, orc.endurance * orc.level);

      // Polaris (LORETALK.PAS:413): class 4 전사, 전투Lv=1, 마법Lv=3
      final polaris = LoreJoin.polaris();
      expect(polaris.name, 'Polaris');
      expect(polaris.playerClass, PlayerClass.warrior);
      expect(polaris.magicLevel, 3);
      expect(polaris.weaPower, 10);
      expect(polaris.ac, 3);

      // Lore Hunter (LORETALK.PAS:623): class 7 사냥꾼, 철퇴(위력 15)
      final hunter = LoreJoin.loreHunter();
      expect(hunter.name, 'Lore Hunter');
      expect(hunter.playerClass, PlayerClass.hunter);
      expect(hunter.weaPower, 15);
      expect(hunter.ac, 4);

      // Spica (LORESPEC.PAS:1230): 여성 에스퍼, Lv 11/6/11
      final spica = LoreJoin.spica();
      expect(spica.sex, Gender.female);
      expect(spica.playerClass, PlayerClass.esper);
      expect(spica.battleLevel, 11);
      expect(spica.magicLevel, 6);
      expect(spica.espLevel, 11);
      expect(spica.maxHp, 9 * 11);
      expect(spica.maxSp, 17 * 6);
      expect(spica.maxEsp, 20 * 11);

      // Rigel은 빈사(hp 1), Red Antares는 hp 0 상태로 합류한다.
      expect(LoreJoin.rigel().hp, 1);
      expect(LoreJoin.redAntares().hp, 0);
      expect(LoreJoin.redAntares().resistance, 15);

      // 원작 ReturnJoinMember: 슬롯 2~6번 중 하나를 골라 교체/충원한다.
      // (파티 6명 미만이면 마지막 6번 슬롯 라벨이 '보조 일원으로 둠'이 된다)
      final party = <PartyMember>[hero];
      expect(LoreJoin.joinMenuPrompt, '교체 시킬 인물은 누구입니까 ?');
      expect(LoreJoin.joinMenuLabels(party).length, 5);
      expect(LoreJoin.joinMenuLabels(party).last, LoreJoin.reserveSlotLabel);

      LoreJoin.applyJoin(party, polaris, 4); // 빈 6번 슬롯으로 합류
      expect(party.length, 2);
      expect(party.last.name, 'Polaris');

      // 6인 파티에서는 선택한 슬롯을 교체한다.
      final full = <PartyMember>[
        hero,
        for (var i = 0; i < 5; i++) LoreJoin.madJoe(),
      ];
      final fullLabels = LoreJoin.joinMenuLabels(full);
      expect(fullLabels.length, 5);
      expect(fullLabels.first, 'Mad Joe'); // 2번 슬롯
      expect(fullLabels.last, 'Mad Joe'); // 6번 슬롯 (빈 슬롯 아님)

      LoreJoin.applyJoin(full, LoreJoin.loreHunter(), 3); // 5번 슬롯 교체
      expect(full.length, LoreJoin.maxPartySize);
      expect(full[4].name, 'Lore Hunter');
      expect(full[0].name, hero.name); // 리더(1번)는 교체되지 않는다
    });
  });
}

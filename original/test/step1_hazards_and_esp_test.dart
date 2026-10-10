import 'package:flutter_test/flutter_test.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/services/save_manager.dart';

void main() {
  group('[1단계] 지형 위험, QuickView, ESP 예언 및 보조 마법 단위 테스트', () {
    test('1. 독 늪지대, 용암, 물 지형 카테고리 정확성 검증', () {
      // 100x100 TOWN grid mock
      final mapData = LoreMapData(
        name: 'TOWN1',
        xmax: 10,
        ymax: 10,
        grid: List.generate(
          10,
          (y) => List.generate(10, (x) => 27),
        ), // walkable 27
      );

      // 마을 타일 기준: 24=water, 25=swamp, 26=lava
      expect(mapData.getCategory(24), TileCategory.water);
      expect(mapData.getCategory(25), TileCategory.swamp);
      expect(mapData.getCategory(26), TileCategory.lava);

      // 필드 타일 기준: 48=water, 23/49=swamp, 50=lava
      final fieldMap = LoreMapData(
        name: 'GROUND1',
        xmax: 10,
        ymax: 10,
        grid: List.generate(10, (y) => List.generate(10, (x) => 30)),
      );
      expect(fieldMap.getCategory(48), TileCategory.water);
      expect(fieldMap.getCategory(49), TileCategory.swamp);
      expect(fieldMap.getCategory(23), TileCategory.swamp);
      expect(fieldMap.getCategory(50), TileCategory.lava);
    });

    test('2. 25단계 메인 스토리 예언(Prophecy) 및 퀘스트 단계 추적 검증', () {
      final dm = LoreDialogueManager.instance;
      dm.metLordAhn = false;
      dm.jrAntaresSecretFound = false;
      dm.castleGateOpen = false;

      // 1단계: Lord Ahn 을 만날
      expect(dm.currentQuestStep, 1);
      expect(dm.getProphecy(), contains('Lord Ahn 을 만날 것이다'));

      // 2단계: 성주 알현 후 MENACE 탐험
      dm.metLordAhn = true;
      expect(dm.currentQuestStep, 2);
      expect(dm.getProphecy(), contains('MENACE를 탐험할 것이다'));

      // 3단계: 비밀 발견 후 Lord Ahn 복귀
      dm.jrAntaresSecretFound = true;
      expect(dm.currentQuestStep, 3);
      expect(dm.getProphecy(), contains('Lord Ahn에게 다시 돌아갈 것이다'));

      // 4단계: 성문 개방 후 LASTDITCH로 진격
      dm.castleGateOpen = true;
      expect(dm.currentQuestStep, 4);
      expect(dm.getProphecy(), contains('LASTDITCH로 갈 것이다'));
    });

    test('3. 파티원 중독(Poison), 기절(Unconscious), HP 대미지 메커니즘 검증', () {
      final hero = PartyMember.createPreset(1); // Hercules
      expect(hero.isPoisoned, false);
      expect(hero.isUnconscious, false);
      expect(hero.isDead, false);

      // 늪지 중독
      hero.poison = 1;
      expect(hero.isPoisoned, true);
      expect(hero.condition, 'poisoned');

      // 화염 용암 대미지로 HP 소진 시 기절
      hero.hp = 0;
      hero.unconscious = 1;
      expect(hero.isUnconscious, true);
      expect(hero.condition, 'unconscious');

      // 누적 의식불명이 endurance * level 초과 시 사망
      hero.unconscious = hero.endurance * hero.battleLevel + 1;
      hero.dead = 1;
      expect(hero.isDead, true);
      expect(hero.condition, 'dead');
    });

    test('4. SaveData의 etc 맵을 통한 보조 마법/환경 지속 스텝 저장 검증', () {
      final hero = PartyMember.createPreset(1);
      final save = SaveData(
        slot: 1,
        slotName: '본 게임 데이타',
        timestamp: DateTime.now(),
        mapId: 6,
        mapTitle: 'CASTLE LORE',
        playerX: 51,
        playerY: 31,
        gold: 2000,
        food: 100,
        party: [hero],
        flags: {'metLordAhn': true},
        etc: {
          'torchSteps': 255,
          'waterWalkSteps': 120,
          'swampWalkSteps': 80,
          'levitateSteps': 150,
          'mindReadCount': 3,
        },
      );

      final json = save.toJson();
      final restored = SaveData.fromJson(json);

      expect(restored.etc['torchSteps'], 255);
      expect(restored.etc['waterWalkSteps'], 120);
      expect(restored.etc['swampWalkSteps'], 80);
      expect(restored.etc['levitateSteps'], 150);
      expect(restored.etc['mindReadCount'], 3);
    });
  });
}

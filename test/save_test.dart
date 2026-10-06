import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/services/save_manager.dart';
import 'package:lore/game/lore_dialogue_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LORE 1993 4-Slot Save/Load Manager Tests', () {
    test('저장 슬롯 왕복으로 퀘스트·원본 etc·동적 플래그를 복원한다', () async {
      final dialogue = LoreDialogueManager.instance;
      dialogue.loadFlags({});
      dialogue.applyQuestStep('lordahn', set: 3);
      dialogue.applyQuestStep('gaia', set: 5);
      dialogue.setEtcBit(39, 3);
      dialogue.setFlag('evilSealRoomCleared');
      dialogue.collectedTreasures.add('gold:9:10:24');

      await SaveManager.instance.saveGame(
        SaveData(
          slot: 1,
          slotName: '진행 상태',
          timestamp: DateTime.utc(1993, 7, 25),
          mapId: 6,
          mapTitle: 'CASTLE LORE',
          playerX: 51,
          playerY: 31,
          gold: 2000,
          food: 100,
          party: const [],
          flags: dialogue.getSaveFlags(),
        ),
      );
      dialogue.loadFlags({});
      expect(dialogue.lordAhnQuestStep, 0);

      final restored = await SaveManager.instance.loadGame(1);
      expect(restored, isNotNull);
      dialogue.loadFlags(restored!.flags);
      expect(dialogue.lordAhnQuestStep, 3);
      expect(dialogue.gaiaQuestStep, 5);
      expect(dialogue.partyEtc[39], 4);
      expect(dialogue.getFlagsCopy()['evilSealRoomCleared'], isTrue);
      expect(dialogue.collectedTreasures, contains('gold:9:10:24'));
      dialogue.loadFlags({});
    });

    test('구형 불리언 저장 플래그에서 etc 비트와 동적 플래그를 복원한다', () {
      final dialogue = LoreDialogueManager.instance;
      dialogue.loadFlags({
        'lordAhnQuestStep': 2,
        'etc39': true,
        'etc39_bit3': true,
        'evilSealRoomCleared': true,
        'gold:9:10:24': true,
      });
      expect(dialogue.lordAhnQuestStep, 2);
      expect(dialogue.partyEtc[39], 4);
      expect(dialogue.getFlagsCopy()['evilSealRoomCleared'], isTrue);
      expect(dialogue.collectedTreasures, contains('gold:9:10:24'));
      dialogue.loadFlags({});
    });

    test('스크립트가 만든 이름 있는 플래그를 저장하고 복원한다', () {
      final dialogue = LoreDialogueManager.instance;
      dialogue.loadFlags({});
      dialogue.setFlag('etc39_bit1');
      dialogue.setFlag('evilSealRoomCleared');
      dialogue.setFlag('lavaGateLeftGuardianDefeated');
      final saved = dialogue.getSaveFlags();
      dialogue.loadFlags({});
      expect(dialogue.getFlagsCopy()['evilSealRoomCleared'], isNull);
      dialogue.loadFlags(saved);
      expect(dialogue.getFlagsCopy()['etc39_bit1'], isTrue);
      expect(dialogue.getFlagsCopy()['evilSealRoomCleared'], isTrue);
      expect(dialogue.getFlagsCopy()['lavaGateLeftGuardianDefeated'], isTrue);
      dialogue.loadFlags({});
    });

    test('1. SaveData serialization and deserialization', () {
      final hero = PartyMember.createPreset(1);
      final wizard = PartyMember.createPreset(3);

      final save = SaveData(
        slot: 1,
        slotName: '본 게임 데이타 (Main)',
        timestamp: DateTime(1993, 7, 25, 12, 0),
        mapId: 6,
        mapTitle: 'CASTLE LORE',
        playerX: 51,
        playerY: 31,
        gold: 3500,
        food: 80,
        party: [hero, wizard],
        flags: {'metLordAhn': true, 'castleGateOpen': true},
        mapTiles: [44, 44, 0, 49],
        consumedScripts: ['rigel-join', 'den4-pyramid-chapters'],
      );

      final json = save.toJson();
      final restored = SaveData.fromJson(json);

      expect(restored.slot, 1);
      expect(restored.slotName, '본 게임 데이타 (Main)');
      expect(restored.mapId, 6);
      expect(restored.mapTitle, 'CASTLE LORE');
      expect(restored.playerX, 51);
      expect(restored.playerY, 31);
      expect(restored.gold, 3500);
      expect(restored.food, 80);
      expect(restored.party.length, 2);
      expect(restored.party[0].name, hero.name);
      expect(restored.party[1].name, wizard.name);
      expect(restored.flags['metLordAhn'], true);
      expect(restored.flags['castleGateOpen'], true);
      expect(restored.mapTiles, [44, 44, 0, 49]);
      expect(restored.consumedScripts, ['rigel-join', 'den4-pyramid-chapters']);

      // 이전 버전의 세이브에는 지도 배열이 없으므로 원본 지도를 사용한다.
      json.remove('mapTiles');
      json.remove('consumedScripts');
      expect(SaveData.fromJson(json).mapTiles, isEmpty);
      expect(SaveData.fromJson(json).consumedScripts, isEmpty);
    });

    test('2. SaveManager save and load slot 1..4', () async {
      final manager = SaveManager.instance;

      // Slot 1: 본 게임 데이타
      final slot1Data = SaveData(
        slot: 1,
        slotName: SaveManager.slotNames[0],
        timestamp: DateTime.now(),
        mapId: 6,
        mapTitle: 'CASTLE LORE',
        playerX: 51,
        playerY: 31,
        gold: 2000,
        food: 100,
        party: [PartyMember.createPreset(1)],
        flags: {'metLordAhn': false},
      );

      // Slot 2: 부 1
      final slot2Data = SaveData(
        slot: 2,
        slotName: SaveManager.slotNames[1],
        timestamp: DateTime.now(),
        mapId: 1,
        mapTitle: 'GROUND 1 (아대륙 필드)',
        playerX: 20,
        playerY: 15,
        gold: 8500,
        food: 65,
        party: [PartyMember.createPreset(1), PartyMember.createPreset(5)],
        flags: {'metLordAhn': true},
      );

      await manager.saveGame(slot1Data);
      await manager.saveGame(slot2Data);

      final loaded1 = await manager.loadGame(1);
      final loaded2 = await manager.loadGame(2);
      final loaded3 = await manager.loadGame(3);

      expect(loaded1, isNotNull);
      expect(loaded1!.slot, 1);
      expect(loaded1.gold, 2000);

      expect(loaded2, isNotNull);
      expect(loaded2!.slot, 2);
      expect(loaded2.gold, 8500);
      expect(loaded2.mapTitle, 'GROUND 1 (아대륙 필드)');

      expect(loaded3, isNull); // Slot 3 is empty

      final allSlots = await manager.getAllSlots();
      expect(allSlots.length, 4);
      expect(allSlots[0], isNotNull);
      expect(allSlots[1], isNotNull);
      expect(allSlots[2], isNull);
      expect(allSlots[3], isNull);
    });
  });
}

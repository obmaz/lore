import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/services/save_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LORE 1993 4-Slot Save/Load Manager Tests', () {
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

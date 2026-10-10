import 'support/legacy_json_fixture_engine.dart';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/logic/script_equip_reducer.dart';
import 'package:lore/logic/script_party_reducer.dart';
import 'package:lore/logic/script_world_reducer.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/services/save_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

PartyMember knight() => PartyMember(
  name: '기사',
  playerClass: PlayerClass.knight,
  strength: 12,
  mentality: 10,
  concentration: 10,
  endurance: 12,
  resistance: 10,
  agility: 10,
  accArms: 10,
  accMagic: 10,
  accEsp: 10,
  luck: 10,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('현재 버전은 스크립트 진행·파티·지도·소모 이력을 함께 복원한다', () async {
    final engine = LegacyJsonFixtureEngine();
    await engine.load();
    final map = await LoreMapData.loadFromAsset('TOWN1', category: 'town');

    final challenge = engine
        .startTalk(6, 52, 51, const ScriptContext(questSteps: {'lordahn': 3}))!
        .choose(0);
    final progress = ScriptWorldReducer.applyProgress(
      const ScriptProgressState(flags: {}, quests: {'lordahn': 3}),
      challenge.outcome,
    );
    final changedMap = ScriptWorldReducer.applyMap(
      ScriptMapState(mapId: 6, x: 51, y: 50, direction: 0, grid: map.grid),
      challenge.outcome,
    );

    final reward = engine.startTalk(
      6,
      51,
      28,
      const ScriptContext(questSteps: {'lordahn': 4}),
    )!;
    final rewarded = ScriptPartyReducer.applyProgress([
      knight(),
    ], reward.outcome);
    final spear = engine.startStep(11, 30, 44, const ScriptContext())!;
    final equipped = ScriptEquipReducer.apply(
      rewarded,
      spear.outcome.equips.single,
      selectedIndex: 0,
    );
    expect(equipped.accepted, isTrue);
    spear.completeEquipment();

    final save = SaveData(
      slot: 1,
      slotName: '시나리오',
      timestamp: DateTime.utc(1993, 7, 25),
      mapId: changedMap.mapId,
      mapTitle: 'CASTLE LORE',
      playerX: changedMap.x,
      playerY: changedMap.y,
      gold: 3600,
      food: 80,
      party: equipped.party,
      flags: {
        ...progress.flags,
        'lordAhnQuestStep': progress.quests['lordahn'],
      },
      etc: const {'torchSteps': 7},
      mapTiles: [for (final row in changedMap.grid) ...row],
      consumedScripts: engine.consumedScripts.toList(),
    );
    expect(save.toJson()['schemaVersion'], SaveData.currentSchemaVersion);
    expect(await SaveManager.instance.saveGame(save), isTrue);
    final restored = (await SaveManager.instance.loadGame(1))!;

    final restoredMap = await LoreMapData.loadFromAsset(
      'TOWN1',
      category: 'town',
    );
    restoredMap.applyTileSnapshot(restored.mapTiles);
    final restoredEngine = LegacyJsonFixtureEngine();
    await restoredEngine.load();
    restoredEngine.consumedScripts.addAll(restored.consumedScripts);

    expect(restored.mapId, 6);
    expect(restored.playerX, changedMap.x);
    expect(restored.playerY, changedMap.y);
    expect(restored.flags['loreChallengeAccepted'], isTrue);
    expect(restored.flags['lordAhnQuestStep'], 3);
    expect(restored.etc['torchSteps'], 7);
    expect(restored.party.single.experience, 1000);
    expect(restored.party.single.weapon, 3);
    expect(restored.party.single.weaPower, 18);
    expect(restoredMap.grid[52][52], 45);
    expect(restoredEngine.consumedScripts, contains(spear.script.id));
    expect(
      restoredEngine.startStep(11, 30, 44, const ScriptContext())?.script.id,
      isNot(spear.script.id),
    );
  });

  test('무버전 및 v1 저장은 현재 형식으로 명시적으로 변환된다', () async {
    final legacy =
        SaveData(
            slot: 1,
            slotName: '옛 저장',
            timestamp: DateTime.utc(1993, 7, 25),
            mapId: 6,
            mapTitle: 'CASTLE LORE',
            playerX: 51,
            playerY: 31,
            gold: 2000,
            food: 100,
            party: [knight()],
            flags: const {'lordAhnQuestStep': 4, 'etc39_bit3': true},
          ).toJson()
          ..remove('schemaVersion')
          ..remove('etc')
          ..remove('mapTiles')
          ..remove('consumedScripts');
    SharedPreferences.setMockInitialValues({
      'lore_save_slot_1': jsonEncode(legacy),
    });

    final restored = (await SaveManager.instance.loadGame(1))!;
    expect(restored.flags['lordAhnQuestStep'], 4);
    expect(restored.flags['etc39_bit3'], isTrue);
    expect(restored.etc, isEmpty);
    expect(restored.mapTiles, isEmpty);
    expect(restored.consumedScripts, isEmpty);
    expect(restored.party.single.name, '기사');
    expect(await SaveManager.instance.saveGame(restored), isTrue);
    final prefs = await SharedPreferences.getInstance();
    final upgraded = jsonDecode(prefs.getString('lore_save_slot_1')!);
    expect(upgraded['schemaVersion'], SaveData.currentSchemaVersion);

    legacy['schemaVersion'] = 1;
    expect(SaveData.fromJson(legacy).flags['etc39_bit3'], isTrue);
  });

  test('미래 버전은 읽기를 거절하고 저장 데이터를 덮어쓰지 않는다', () async {
    const raw = '{"schemaVersion":999,"slot":1,"gold":100}';
    SharedPreferences.setMockInitialValues({'lore_save_slot_1': raw});
    expect(
      () => SaveData.fromJson({'schemaVersion': 999}),
      throwsFormatException,
    );
    expect(await SaveManager.instance.loadGame(1), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('lore_save_slot_1'), raw);
  });
}

import 'support/legacy_json_fixture_engine.dart';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/logic/script_party_reducer.dart';
import 'package:lore/logic/script_world_reducer.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/services/save_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('황금의 봉인은 GAIA 1→2, 저장, 성주 보상 2→3으로 이어진다', () async {
    final engine = LegacyJsonFixtureEngine();
    await engine.load();
    final map = await LoreMapData.loadFromAsset('T_DEN2', category: 'den');
    final seal = engine.startStep(
      12,
      18,
      10,
      const ScriptContext(questSteps: {'gaia': 1}),
    )!;
    expect(seal.script.id, 'golden-seal-12-18-10');
    expect(seal.outcome.questChanges.single, (name: 'gaia', set: 2, inc: null));
    final progress = ScriptWorldReducer.applyProgress(
      const ScriptProgressState(flags: {}, quests: {'gaia': 1}),
      seal.outcome,
    );
    final terrain = ScriptWorldReducer.applyMap(
      ScriptMapState(mapId: 12, x: 18, y: 10, direction: 0, grid: map.grid),
      seal.outcome,
    );
    expect(progress.quests['gaia'], 2);
    expect(progress.flags['goldenSealFound'], isTrue);
    expect(terrain.grid[8][17], 0);

    final save = SaveData(
      slot: 1,
      slotName: '봉인 획득 직후',
      timestamp: DateTime.utc(1993, 7, 25),
      mapId: 12,
      mapTitle: 'EVIL SEAL',
      playerX: 18,
      playerY: 10,
      gold: 2000,
      food: 100,
      party: [PartyMember.createPreset(1)],
      flags: {
        ...progress.flags,
        'metLordAhn': true,
        'jrAntaresSecretFound': true,
        'castleGateOpen': true,
        'lastditchQuestStep': 2,
        'gaiaQuestStep': progress.quests['gaia'],
      },
      mapTiles: [for (final row in terrain.grid) ...row],
      consumedScripts: engine.consumedScripts.toList(),
    );
    final restored = SaveData.fromJson(
      jsonDecode(jsonEncode(save.toJson())) as Map<String, dynamic>,
    );
    expect(restored.flags['gaiaQuestStep'], 2);
    expect(restored.flags['goldenSealFound'], isTrue);
    expect(restored.mapTiles[8 * map.xmax + 17], 0);
    final dialogue = LoreDialogueManager.instance;
    addTearDown(() => dialogue.loadFlags({}));
    dialogue.loadFlags(restored.flags);
    expect(dialogue.currentQuestStep, 11); // 성주에게 보고할 단계

    final lord = engine.startTalk(
      9,
      42,
      25,
      const ScriptContext(questSteps: {'gaia': 2}),
    )!;
    expect(lord.script.id, 'talk-9-42-25-q2');
    expect(lord.outcome.expDelta, 10000);
    expect(lord.outcome.questChanges.single.inc, 1);
    final rewarded = ScriptPartyReducer.applyProgress(
      restored.party,
      lord.outcome,
    );
    expect(
      rewarded.single.experience,
      restored.party.single.experience + 10000,
    );
    expect(
      ScriptWorldReducer.applyProgress(progress, lord.outcome).quests['gaia'],
      3,
    );
    dialogue.applyQuestStep('gaia', set: 3);
    expect(dialogue.currentQuestStep, 12); // QUAKE로 향할 단계
  });

  test('GAIA 2 이상이면 봉인과 같은 행의 함정이 다시 발동하지 않는다', () async {
    final engine = LegacyJsonFixtureEngine();
    await engine.load();
    const completed = ScriptContext(questSteps: {'gaia': 2});
    expect(engine.startStep(12, 18, 10, completed), isNull);
    expect(engine.startStep(12, 19, 10, completed), isNull);

    final active = engine.startStep(
      12,
      19,
      10,
      const ScriptContext(questSteps: {'gaia': 1}),
    )!;
    expect(active.script.id, 't_den2-trap-y10');
    expect(active.outcome.tileAreas.single.tile, 49);
  });
}

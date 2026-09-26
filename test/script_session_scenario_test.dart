import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/logic/script_world_reducer.dart';
import 'package:lore/services/save_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('성의 도전 수락은 타일·플래그를 바꾸고 저장 후 대화 분기를 유지한다', () async {
    final engine = LoreScriptEngine();
    await engine.load();
    final map = await LoreMapData.loadFromAsset('TOWN1', category: 'town');
    const progress = ScriptProgressState(flags: {}, quests: {'lordahn': 3});

    final run = engine.startTalk(
      6,
      52,
      51,
      const ScriptContext(questSteps: {'lordahn': 3}),
    )!;
    expect(run.script.id, 'talk-6-52-51-c');
    expect(run.hasPendingChoice, isTrue);
    final chosen = run.choose(0);
    final delta = chosen.outcome.since(run.outcome);
    final nextProgress = ScriptWorldReducer.applyProgress(progress, delta);
    final nextMap = ScriptWorldReducer.applyMap(
      ScriptMapState(mapId: 6, x: 51, y: 50, direction: 0, grid: map.grid),
      delta,
    );

    expect(nextProgress.flags['loreChallengeAccepted'], isTrue);
    expect(nextMap.grid[51].sublist(48, 53), [47, 44, 44, 44, 47]);
    expect(nextMap.grid[52].sublist(48, 53), [47, 44, 44, 44, 45]);

    final dialogue = LoreDialogueManager.instance;
    dialogue.loadFlags({});
    for (final flag in nextProgress.flags.entries) {
      if (flag.value) dialogue.setFlag(flag.key);
    }
    for (final quest in nextProgress.quests.entries) {
      dialogue.applyQuestStep(quest.key, set: quest.value);
    }

    final save = SaveData(
      slot: 1,
      slotName: 'scenario',
      timestamp: DateTime.utc(1993, 7, 25),
      mapId: nextMap.mapId,
      mapTitle: 'CASTLE LORE',
      playerX: nextMap.x,
      playerY: nextMap.y,
      gold: 2000,
      food: 100,
      party: const [],
      flags: dialogue.getSaveFlags(),
      mapTiles: [for (final row in nextMap.grid) ...row],
      consumedScripts: engine.consumedScripts.toList(),
    );
    final restored = SaveData.fromJson(
      jsonDecode(jsonEncode(save.toJson())) as Map<String, dynamic>,
    );
    final restoredMap = await LoreMapData.loadFromAsset(
      'TOWN1',
      category: 'town',
    );
    restoredMap.applyTileSnapshot(restored.mapTiles);
    final restoredEngine = LoreScriptEngine();
    await restoredEngine.load();
    restoredEngine.consumedScripts.addAll(restored.consumedScripts);
    dialogue.loadFlags({});
    dialogue.loadFlags(restored.flags);

    expect(restoredMap.grid[52][52], 45);
    expect(
      restoredEngine
          .startTalk(
            restored.mapId,
            52,
            51,
            ScriptContext(
              flags: dialogue
                  .getFlagsCopy()
                  .entries
                  .where((entry) => entry.value)
                  .map((entry) => entry.key)
                  .toSet(),
              questSteps: dialogue.questSteps,
            ),
          )
          ?.script
          .id,
      'talk-6-52-51-a',
    );
    dialogue.loadFlags({});
  });
}

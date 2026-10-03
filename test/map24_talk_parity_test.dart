import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/logic/script_world_reducer.dart';

/// LORETALK.PAS 맵 24 대화의 영속 플래그와 NPC 타일 제거를 검증한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('맵 24 제작자 대화는 원본 플래그와 타일 효과를 남긴다', () async {
    final fixture = jsonDecode(
      File('test/fixtures/map24_talk_parity.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final talkAt = (fixture['talkAt'] as List<dynamic>).cast<int>();
    final tile = (fixture['tile'] as List<dynamic>).cast<int>();
    final map = await LoreMapData.loadFromAsset('K_DEN1', category: 'den');
    final engine = LoreScriptEngine();
    engine.loadFromJson(
      await rootBundle.loadString('assets/data/scripts.json'),
    );

    final talk = engine.startTalk(
      24,
      talkAt[0],
      talkAt[1],
      const ScriptContext(),
    );
    expect(talk, isNotNull, reason: 'LORETALK.PAS:${fixture['line']}');
    expect(talk!.outcome.setFlags, contains('programmerMet'));
    final afterTalk = ScriptWorldReducer.applyMap(
      ScriptMapState(mapId: 24, x: 25, y: 20, direction: 0, grid: map.grid),
      talk.outcome,
    );
    expect(afterTalk.grid[tile[1] - 1][tile[0] - 1], tile[2]);

    final enter = engine.startEnter(
      24,
      const ScriptContext(flags: {'programmerMet'}),
    );
    expect(enter, isNotNull);
    final afterReentry = ScriptWorldReducer.applyMap(
      ScriptMapState(mapId: 24, x: 25, y: 45, direction: 0, grid: map.grid),
      enter!.outcome,
    );
    expect(afterReentry.grid[tile[1] - 1][tile[0] - 1], tile[2]);
  });
}

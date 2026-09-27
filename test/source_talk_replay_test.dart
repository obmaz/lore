import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/game/lore_world_manager.dart';
import 'package:lore/logic/lore_talk_dispatcher.dart';
import 'package:lore/logic/lore_tile_protocol.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('LORETALK.PAS의 148개 at 좌표가 실제 대화 선택기에 연결된다', () async {
    final cases =
        (jsonDecode(
              File('test/fixtures/source_talk_replay.json').readAsStringSync(),
            ) as Map<String, dynamic>)['cases']
            as List<dynamic>;
    expect(cases, hasLength(148));
    final baseScripts = LoreScriptEngine()
      ..loadFromJson(File('assets/data/scripts.json').readAsStringSync());
    final world = LoreWorldManager.instance;
    final dialogues = LoreDialogueManager.instance;
    world.resetRulesForTest();
    await world.loadData();
    dialogues.resetDataForTest();
    await dialogues.loadData();
    final maps = <int, LoreMapData>{};
    final nonTalk = <String>[];

    for (final raw in cases) {
      final item = raw as Map<String, dynamic>;
      final map = item['map'] as int;
      final x = item['x'] as int;
      final y = item['y'] as int;
      final info = LoreWorldManager.mapRegistry[map]!;
      final mapData = maps[map] ??= await LoreMapData.loadFromAsset(
        info.fileName,
        category: info.category.name,
      );
      if (mapData.actionForTile(mapData.getTile(x, y)) != LoreTileAction.talk) {
        nonTalk.add('$map:$x,$y');
      }
      final candidates = <ScriptContext>[const ScriptContext()];
      for (final script in baseScripts.scripts.where(
        (s) =>
            s.trigger == 'talk' && !s.disabled && s.matches('talk', map, x, y),
      )) {
        final require = script.require;
        candidates.add(
          ScriptContext(
            flags: {?require.flag, ...require.allFlags},
            partyNames: {?require.partyMember},
            enteredFromMap: require.enteredFromMap,
            mindReadActive: require.mindRead,
            maxEspLevel: require.minEspLevel ?? 0,
            tileAtPlayer: require.tileAtPlayerZero
                ? 0
                : require.tileAtPlayerValue,
            moveDy: require.moveDyNot == 0 ? 1 : 0,
            questSteps: {
              for (final q in require.quests) q.name: q.eq ?? q.gte ?? 0,
            },
          ),
        );
      }
      var reached = false;
      for (final context in candidates) {
        final selected = LoreTalkDispatcher.resolve(
          mapId: map,
          x: x,
          y: y,
          heroName: 'Hero',
          context: context,
          party: null,
          mindReadCount: 0,
          world: world,
          scripts: baseScripts.fork(),
          dialogues: dialogues,
        );
        if (selected.source != LoreTalkSource.none) {
          reached = true;
          break;
        }
      }
      expect(
        reached,
        isTrue,
        reason: 'LORETALK.PAS:${item['line']} map $map ($x,$y)',
      );
    }
    world.resetRulesForTest();
    dialogues.resetDataForTest();
    expect(nonTalk, isEmpty, reason: '원본 at 좌표가 현재 지도에서 talk 타일이어야 한다');
  });
}

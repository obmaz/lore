import 'package:lore/logic/lore_talk_mode.dart';
import 'package:lore/logic/lore_source_memory.dart';
import 'package:lore/models/party_member.dart';

import 'support/talk_mode_io.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
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
    final baseScripts = LoreScriptEngine();
    final world = LoreWorldManager.instance;
    world.resetRulesForTest();
    await world.loadData();
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
      var reached = false;
      for (final context in candidates) {
        final selected = LoreTalkDispatcher.resolve(
          mapId: map,
          x: x,
          y: y,
          context: context,
          world: world,
          scripts: baseScripts.fork(),
        );
        if (selected.source != LoreTalkSource.none) {
          reached = true;
          break;
        }
      }
      if (world.findFacility(map, x, y) == null) {
        final io = TalkModeIo();
        await LoreTalkMode.run(
          mapId: map,
          targetX: x,
          targetY: y,
          x: 5,
          y: 5,
          party: [
            PartyMember.fromJson({'name': 'Hero'}),
          ],
          etc: LorePartyEtc(),
          roll: (_) => 0,
          io: io,
        );
        expect(
          io.pages.isNotEmpty ||
              io.recruits.isNotEmpty ||
              io.messages.isNotEmpty,
          isTrue,
          reason: 'Executed source LORETALK.PAS:${item['line']}',
        );
      }
      expect(
        reached,
        isTrue,
        reason: 'LORETALK.PAS:${item['line']} map $map ($x,$y)',
      );
    }
    world.resetRulesForTest();
    expect(nonTalk, isEmpty, reason: '원본 at 좌표가 현재 지도에서 talk 타일이어야 한다');
  });
}

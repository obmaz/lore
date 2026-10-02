import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/game/lore_dungeon_event_manager.dart';
import 'package:lore/logic/lore_special_event_dispatcher.dart';
import 'package:lore/logic/lore_tile_protocol.dart';
import 'package:lore/logic/script_world_reducer.dart';

/// LORESPEC.PAS 맵 25 두 레버의 모든 저장 비트 상태를 비교한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ScriptRun? sourceLever(
    LoreScriptEngine engine,
    int x,
    ScriptContext context,
  ) => LoreSpecialEventDispatcher.resolve(
    action: LoreTileAction.special,
    mapId: 25,
    x: x,
    y: 34,
    context: context,
    party: const [],
    scripts: engine,
    legacy: LoreDungeonEventManager.instance,
  ).script;

  test('맵 25 레버는 재방문해도 원본처럼 문 상태를 다시 적용한다', () async {
    final fixture = jsonDecode(
      File('test/fixtures/map25_lever_parity.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final map = await LoreMapData.loadFromAsset('K_DEN2', category: 'den');
    final loaded = LoreScriptEngine()
      ..loadFromJson(await rootBundle.loadString('assets/data/scripts.json'));
    final manager = LoreDialogueManager.instance;
    addTearDown(() => manager.loadSaveFlags({}));
    // Each source fixture supplies the two lever bits. Exercise every lower-bit
    // combination too, with and without the old JSON rules being available.
    for (final engine in [LoreScriptEngine(), loaded]) {
      for (final raw in fixture['cases'] as List<dynamic>) {
        final item = raw as Map<String, dynamic>;
        for (var lowerBits = 0; lowerBits < 64; lowerBits++) {
          final before =
              lowerBits +
              (item['a'] == true ? 64 : 0) +
              (item['b'] == true ? 128 : 0);
          final x = item['x'] as int;
          final y = item['y'] as int;
          final run = sourceLever(
            engine,
            x,
            ScriptContext(tileAtPlayer: 52, sourceEtc: {45: before}),
          );
          expect(
            run,
            isNotNull,
            reason: 'LORESPEC.PAS:${item['line']} etc45=$before',
          );
          final ownFlag = item['setBit'] == 7 ? 'keep3KeyA' : 'keep3KeyB';
          expect(run!.outcome.setFlags, contains(ownFlag));
          manager.loadSaveFlags({'etc45': before});
          for (final flag in run.outcome.setFlags) {
            manager.setFlag(flag);
          }
          expect(
            manager.partyEtc.read(45),
            before | (item['setBit'] == 7 ? 64 : 128),
          );
          final actual = ScriptWorldReducer.applyMap(
            ScriptMapState(mapId: 25, x: x, y: y, direction: 0, grid: map.grid),
            run.outcome,
          );
          final expected = [for (final row in map.grid) List<int>.from(row)];
          for (final rawTile in item['door'] as List<dynamic>) {
            final tile = (rawTile as List<dynamic>).cast<int>();
            expected[tile[1] - 1][tile[0] - 1] = tile[2];
          }
          expect(
            actual.grid,
            expected,
            reason: 'LORESPEC.PAS:${item['line']} etc45=$before',
          );
        }
      }
    }
  });

  test('맵 25 두 레버를 연속 작동한 뒤 첫 레버를 다시 당길 수 있다', () async {
    final engine = LoreScriptEngine();
    final first = sourceLever(engine, 5, const ScriptContext(tileAtPlayer: 0));
    expect(first?.outcome.setFlags, contains('keep3KeyA'));
    final second = sourceLever(
      engine,
      46,
      ScriptContext(tileAtPlayer: 0, flags: first!.outcome.setFlags.toSet()),
    );
    expect(second?.outcome.setFlags, contains('keep3KeyB'));
    final both = {...first.outcome.setFlags, ...second!.outcome.setFlags};
    final revisited = sourceLever(
      engine,
      5,
      ScriptContext(tileAtPlayer: 0, flags: both),
    );
    expect(revisited, isNotNull);
    expect(
      revisited!.outcome.tileChanges.map((tile) => [tile.x, tile.y, tile.tile]),
      containsAll([
        <int>[25, 27, 54],
        <int>[26, 27, 54],
      ]),
    );
  });

  test('원본 etc45의 0은 오래된 이름 플래그보다 우선한다', () {
    final run = sourceLever(
      LoreScriptEngine(),
      5,
      const ScriptContext(
        tileAtPlayer: 52,
        sourceEtc: {45: 0},
        flags: {'keep3KeyA', 'keep3KeyB', 'etc45_bit8'},
      ),
    )!;
    expect(run.outcome.tileChanges, isEmpty);
    expect(run.outcome.setFlags, contains('etc45_bit7'));
  });

  test('레버 비트와 문 타일을 저장한 뒤 JSON 없이 다시 작동한다', () async {
    final manager = LoreDialogueManager.instance;
    manager.loadSaveFlags({'etc45': 63});
    addTearDown(() => manager.loadSaveFlags({}));
    final engine = LoreScriptEngine();
    final map = await LoreMapData.loadFromAsset('K_DEN2', category: 'den');
    final first = sourceLever(
      engine,
      5,
      ScriptContext(tileAtPlayer: 52, sourceEtc: manager.partyEtc.snapshot()),
    )!;
    for (final flag in first.outcome.setFlags) {
      manager.setFlag(flag);
    }
    final savedFlags =
        jsonDecode(jsonEncode(manager.getSaveFlags())) as Map<String, dynamic>;
    final savedTiles = map.tileSnapshot();
    manager.loadSaveFlags({});
    manager.loadSaveFlags(savedFlags);
    final restored = await LoreMapData.loadFromAsset('K_DEN2', category: 'den');
    restored.applyTileSnapshot(savedTiles);
    final second = sourceLever(
      engine,
      46,
      ScriptContext(tileAtPlayer: 52, sourceEtc: manager.partyEtc.snapshot()),
    )!;
    for (final flag in second.outcome.setFlags) {
      manager.setFlag(flag);
    }
    final after = ScriptWorldReducer.applyMap(
      ScriptMapState(
        mapId: 25,
        x: 46,
        y: 34,
        direction: 0,
        grid: restored.grid,
      ),
      second.outcome,
    );
    restored.applyTileSnapshot([for (final row in after.grid) ...row]);
    final reopenedFlags = manager.getSaveFlags();
    manager.loadSaveFlags(reopenedFlags);
    final revisit = sourceLever(
      engine,
      5,
      ScriptContext(tileAtPlayer: 52, sourceEtc: manager.partyEtc.snapshot()),
    )!;
    expect(manager.partyEtc.read(45), 255);
    expect(restored.getTile(25, 27), 54);
    expect(restored.getTile(26, 27), 54);
    expect(revisit.outcome.tileChanges.length, 2);
  });
}

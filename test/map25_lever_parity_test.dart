import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/logic/script_world_reducer.dart';

/// LORESPEC.PAS 맵 25 두 레버의 모든 저장 비트 상태를 비교한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('맵 25 레버는 재방문해도 원본처럼 문 상태를 다시 적용한다', () async {
    final fixture = jsonDecode(
      File('test/fixtures/map25_lever_parity.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final map = await LoreMapData.loadFromAsset('K_DEN2', category: 'den');
    for (final raw in fixture['cases'] as List<dynamic>) {
      final item = raw as Map<String, dynamic>;
      final flags = <String>{
        if (item['a'] == true) 'keep3KeyA',
        if (item['b'] == true) 'keep3KeyB',
      };
      final engine = LoreScriptEngine();
      engine.loadFromJson(await rootBundle.loadString('assets/data/scripts.json'));
      final x = item['x'] as int;
      final y = item['y'] as int;
      final run = engine.startStep(25, x, y, ScriptContext(flags: flags));
      expect(run, isNotNull, reason: 'LORESPEC.PAS:${item['line']} $flags');
      final ownFlag = item['setBit'] == 7 ? 'keep3KeyA' : 'keep3KeyB';
      expect(run!.outcome.setFlags, contains(ownFlag));
      final actual = ScriptWorldReducer.applyMap(
        ScriptMapState(mapId: 25, x: x, y: y, direction: 0, grid: map.grid),
        run.outcome,
      );
      final expected = [for (final row in map.grid) List<int>.from(row)];
      for (final rawTile in item['door'] as List<dynamic>) {
        final tile = (rawTile as List<dynamic>).cast<int>();
        expected[tile[1] - 1][tile[0] - 1] = tile[2];
      }
      expect(actual.grid, expected, reason: 'LORESPEC.PAS:${item['line']} $flags');
    }
  });

  test('맵 25 두 레버를 연속 작동한 뒤 첫 레버를 다시 당길 수 있다', () async {
    final engine = LoreScriptEngine();
    engine.loadFromJson(await rootBundle.loadString('assets/data/scripts.json'));
    final first = engine.startStep(25, 5, 34, const ScriptContext());
    expect(first?.outcome.setFlags, contains('keep3KeyA'));
    final second = engine.startStep(
      25,
      46,
      34,
      ScriptContext(flags: first!.outcome.setFlags.toSet()),
    );
    expect(second?.outcome.setFlags, contains('keep3KeyB'));
    final both = {...first.outcome.setFlags, ...second!.outcome.setFlags};
    final revisited = engine.startStep(25, 5, 34, ScriptContext(flags: both));
    expect(revisited, isNotNull);
    expect(
      revisited!.outcome.tileChanges.map((tile) => [tile.x, tile.y, tile.tile]),
      containsAll([<int>[25, 27, 54], <int>[26, 27, 54]]),
    );
  });
}

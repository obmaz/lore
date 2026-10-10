import 'support/legacy_json_fixture_engine.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/logic/script_world_reducer.dart';

/// LORESPEC.PAS 맵 12의 분기 순서와 지형·좌표 결과를 비교한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('맵 12 정답 문·오답 문·봉인·함정이 원본 결과와 일치한다', () async {
    final fixture = jsonDecode(
      File('test/fixtures/map12_state_parity.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final map = await LoreMapData.loadFromAsset('T_DEN2', category: 'den');
    final engine = LegacyJsonFixtureEngine();
    engine.loadFromJson(
      await readHistoricalRuleAsset('test/fixtures/legacy_rules/scripts.json'),
    );
    for (final raw in fixture['cases'] as List<dynamic>) {
      final item = raw as Map<String, dynamic>;
      final x = item['x'] as int;
      final y = item['y'] as int;
      final gaia = item['gaia'] as int;
      final run = engine.startStep(
        12,
        x,
        y,
        ScriptContext(
          moveDy: item['moveDy'] as int,
          questSteps: {'gaia': gaia},
        ),
      );
      final ScriptMapResult actual = run == null
          ? ScriptMapResult(mapId: 12, x: x, y: y, grid: map.grid)
          : ScriptWorldReducer.applyMap(
              ScriptMapState(
                mapId: 12,
                x: x,
                y: y,
                direction: 0,
                grid: map.grid,
              ),
              run.outcome,
            );
      expect(
        [actual.x, actual.y],
        item['end'],
        reason: '원본 ${item['line']} ($x,$y)',
      );
      final expectedGrid = [for (final row in map.grid) List<int>.from(row)];
      final rawTile = item['tile'];
      if (rawTile != null) {
        final tile = (rawTile as List<dynamic>).cast<int>();
        expectedGrid[tile[1] - 1][tile[0] - 1] = tile[2];
      }
      final rawTrap = item['trap'];
      if (rawTrap != null) {
        final trap = (rawTrap as List<dynamic>).cast<int>();
        for (var ty = trap[1]; ty <= trap[2]; ty++) {
          expectedGrid[ty - 1][trap[0] - 1] = trap[3];
        }
      }
      expect(
        actual.grid,
        expectedGrid,
        reason: '원본 ${item['line']} ($x,$y) 지형',
      );
      final questSet = item['questSet'];
      expect(
        run?.outcome.questChanges
                .where((q) => q.name == 'gaia')
                .map((q) => q.set)
                .toList() ??
            <int?>[],
        questSet == null ? <int?>[] : <int?>[questSet as int],
        reason: '원본 ${item['line']} ($x,$y) 퀘스트',
      );
    }
  });
}

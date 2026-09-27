import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/logic/script_world_reducer.dart';

/// Pascal의 네 좌표 규칙을 source_route_pilot.py가 순서대로 실행한 결과와
/// 실제 지도 상태 전이를 비교한다. 재생성: python3 tool/source_route_pilot.py --write
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('맵 17의 통과 가능 경로는 원본의 순차 좌표 효과와 일치한다', () async {
    final fixture = jsonDecode(
      File('test/fixtures/map17_route_parity.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final cases = fixture['cases'] as List<dynamic>;
    expect(cases.length, greaterThan(100));

    final map = await LoreMapData.loadFromAsset('DEN4', category: 'den');
    final engine = LoreScriptEngine();
    engine.loadFromJson(await rootBundle.loadString('assets/data/scripts.json'));

    for (final raw in cases) {
      final item = raw as Map<String, dynamic>;
      final start = (item['start'] as List<dynamic>).cast<int>();
      final x = start[0];
      final y = start[1];
      final run = engine.startStep(17, x, y, const ScriptContext());
      expect(run, isNotNull, reason: '원본 좌표 ($x,$y) 규칙이 없다');

      final actual = ScriptWorldReducer.applyMap(
        ScriptMapState(
          mapId: 17,
          x: x,
          y: y,
          direction: 0,
          grid: map.grid,
        ),
        run!.outcome,
      );
      final safeEnd = (item['safeEnd'] as List<dynamic>).cast<int>();
      expect([actual.x, actual.y], safeEnd, reason: '맵 17 ($x,$y) 이동');

      final expectedGrid = [for (final row in map.grid) List<int>.from(row)];
      for (final rawWrite in item['writes'] as List<dynamic>) {
        final write = (rawWrite as List<dynamic>).cast<int>();
        for (var ty = write[2]; ty <= write[3]; ty++) {
          for (var tx = write[0]; tx <= write[1]; tx++) {
            expectedGrid[ty - 1][tx - 1] = write[4];
          }
        }
      }
      expect(actual.grid, expectedGrid, reason: '맵 17 ($x,$y) 지형');
    }
  });
}

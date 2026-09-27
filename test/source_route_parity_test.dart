import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/logic/script_world_reducer.dart';

/// Pascal 좌표 규칙을 source_route_pilot.py가 순서대로 실행한 결과와
/// 실제 지도 상태 전이를 비교한다.
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

  test('맵 20 통로는 현재 타일 값에 따라 이동하거나 필드로 돌아간다', () async {
    final fixture = jsonDecode(
      File('test/fixtures/map20_route_parity.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final cases = fixture['cases'] as List<dynamic>;
    expect(cases.length, greaterThan(100));
    final map = await LoreMapData.loadFromAsset('DEN7', category: 'den');
    final engine = LoreScriptEngine();
    engine.loadFromJson(await rootBundle.loadString('assets/data/scripts.json'));

    for (final raw in cases) {
      final item = raw as Map<String, dynamic>;
      final start = (item['start'] as List<dynamic>).cast<int>();
      final tile = item['tileAtPlayer'] as int;
      final x = start[0];
      final y = start[1];
      final grid = [for (final row in map.grid) List<int>.from(row)];
      grid[y - 1][x - 1] = tile;
      final run = engine.startStep(
        20,
        x,
        y,
        ScriptContext(tileAtPlayer: tile),
      );
      expect(run, isNotNull, reason: '맵 20 ($x,$y), 타일 $tile');
      final actual = ScriptWorldReducer.applyMap(
        ScriptMapState(mapId: 20, x: x, y: y, direction: 0, grid: grid),
        run!.outcome,
      );
      final expected = (item['sourceEnd'] as List<dynamic>).cast<int>();
      expect(
        [actual.mapId, actual.x, actual.y],
        [item['sourceMap'], ...expected],
        reason: '맵 20 ($x,$y), 타일 $tile',
      );
      expect(actual.grid, grid, reason: '맵 20 ($x,$y) 타일 보존');
    }
  });

  test('맵 19 두 번째 레버는 걷기 마법과 완료 비트에 따라 지형을 바꾼다', () async {
    final fixture = jsonDecode(
      File('test/fixtures/map19_route_parity.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final map = await LoreMapData.loadFromAsset('DEN6', category: 'den');
    for (final raw in fixture['cases'] as List<dynamic>) {
      final item = raw as Map<String, dynamic>;
      final walk = item['swampWalkActive'] as bool;
      final cleared = item['puzzleCleared'] as bool;
      final flags = <String>{
        if (walk) 'swampWalkActive',
        if (cleared) 'evilSealRoomCleared',
      };
      final engine = LoreScriptEngine();
      engine.loadFromJson(await rootBundle.loadString('assets/data/scripts.json'));
      final run = engine.startStep(
        19,
        41,
        39,
        ScriptContext(flags: flags, tileAtPlayer: 0),
      );
      expect(run, isNotNull, reason: '걷기 $walk, 완료 $cleared');
      final grid = [for (final row in map.grid) List<int>.from(row)];
      grid[38][40] = 0; // 첫 번째 레버가 두 번째 레버 칸을 연 상태
      final expectedGrid = [for (final row in grid) List<int>.from(row)];
      for (final rawWrite in item['writes'] as List<dynamic>) {
        final write = (rawWrite as List<dynamic>).cast<int>();
        for (var y = write[2]; y <= write[3]; y++) {
          for (var x = write[0]; x <= write[1]; x++) {
            expectedGrid[y - 1][x - 1] = write[4];
          }
        }
      }
      final actual = ScriptWorldReducer.applyMap(
        ScriptMapState(mapId: 19, x: 41, y: 39, direction: 0, grid: grid),
        run!.outcome,
      );
      expect(actual.grid, expectedGrid, reason: '걷기 $walk, 완료 $cleared');
      expect(
        run.outcome.setFlags.where((flag) => flag.startsWith('evilSealRoom')),
        hasLength(item['randomRoomCount'] == 0 ? 0 : 1),
        reason: '걷기 $walk, 완료 $cleared',
      );
    }
  });
}

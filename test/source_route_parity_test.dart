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

  test('맵 19 두 레버는 걷기 마법과 완료 비트에 따라 지형을 바꾼다', () async {
    final fixture = jsonDecode(
      File('test/fixtures/map19_route_parity.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final map = await LoreMapData.loadFromAsset('DEN6', category: 'den');
    for (final raw in fixture['cases'] as List<dynamic>) {
      final item = raw as Map<String, dynamic>;
      final start = (item['start'] as List<dynamic>).cast<int>();
      final x = start[0];
      final y = start[1];
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
        x,
        y,
        ScriptContext(flags: flags, tileAtPlayer: 0),
      );
      expect(run, isNotNull, reason: '($x,$y), 걷기 $walk, 완료 $cleared');
      final grid = [for (final row in map.grid) List<int>.from(row)];
      grid[y - 1][x - 1] = 0;
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
        ScriptMapState(mapId: 19, x: x, y: y, direction: 0, grid: grid),
        run!.outcome,
      );
      expect(actual.grid, expectedGrid, reason: '($x,$y), 걷기 $walk, 완료 $cleared');
      expect(
        run.outcome.setFlags.where((flag) => flag.startsWith('evilSealRoom')),
        hasLength(item['randomRoomCount'] == 0 ? 0 : 1),
        reason: '걷기 $walk, 완료 $cleared',
      );
    }
  });

  test('맵 19 첫 레버가 연 칸에서 두 번째 레버를 연속 실행한다', () async {
    final map = await LoreMapData.loadFromAsset('DEN6', category: 'den');
    final engine = LoreScriptEngine();
    engine.loadFromJson(await rootBundle.loadString('assets/data/scripts.json'));
    final first = engine.startStep(
      19,
      11,
      40,
      const ScriptContext(tileAtPlayer: 0),
    )!;
    final afterFirst = ScriptWorldReducer.applyMap(
      ScriptMapState(
        mapId: 19,
        x: 11,
        y: 40,
        direction: 0,
        grid: map.grid,
      ),
      first.outcome,
    );
    expect(afterFirst.grid[38][40], 0);
    final second = engine.startStep(
      19,
      41,
      39,
      ScriptContext(
        flags: first.outcome.setFlags.toSet(),
        tileAtPlayer: afterFirst.grid[38][40],
      ),
    )!;
    final afterSecond = ScriptWorldReducer.applyMap(
      ScriptMapState(
        mapId: 19,
        x: 41,
        y: 39,
        direction: 0,
        grid: afterFirst.grid,
      ),
      second.outcome,
    );
    expect(afterSecond.grid[38][40], 49);
    expect(afterSecond.grid[26][23], 25);
    expect(afterSecond.grid[36][26], 44);
    expect(second.outcome.setFlags, contains('evilSealLeverB'));
  });

  test('맵 27 특수 칸은 출구 이동 대신 중앙 쪽으로 한 칸 이동한다', () async {
    final fixture = jsonDecode(
      File('test/fixtures/map27_route_parity.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final map = await LoreMapData.loadFromAsset('PYRAMID1', category: 'town');
    final engine = LoreScriptEngine();
    engine.loadFromJson(await rootBundle.loadString('assets/data/scripts.json'));
    for (final raw in fixture['cases'] as List<dynamic>) {
      final item = raw as Map<String, dynamic>;
      final start = (item['start'] as List<dynamic>).cast<int>();
      final expected = (item['sourceEnd'] as List<dynamic>).cast<int>();
      final run = engine.startStep(
        27,
        start[0],
        start[1],
        const ScriptContext(tileAtPlayer: 0),
      )!;
      final actual = ScriptWorldReducer.applyMap(
        ScriptMapState(
          mapId: 27,
          x: start[0],
          y: start[1],
          direction: 0,
          grid: map.grid,
        ),
        run.outcome,
      );
      expect(
        [actual.mapId, actual.x, actual.y],
        [27, ...expected],
        reason: '특수 칸 ${item['start']}',
      );
    }
  });

  test('맵 25 양쪽 숨겨진 문은 원본 루프대로 지형을 바꾼다', () async {
    final fixture = jsonDecode(
      File('test/fixtures/map25_route_parity.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final map = await LoreMapData.loadFromAsset('K_DEN2', category: 'den');
    final engine = LoreScriptEngine();
    engine.loadFromJson(await rootBundle.loadString('assets/data/scripts.json'));
    for (final raw in fixture['cases'] as List<dynamic>) {
      final item = raw as Map<String, dynamic>;
      final start = (item['start'] as List<dynamic>).cast<int>();
      final grid = [for (final row in map.grid) List<int>.from(row)];
      grid[start[1] - 1][start[0] - 1] = 0;
      final run = engine.startStep(
        25,
        start[0],
        start[1],
        const ScriptContext(tileAtPlayer: 0),
      );
      expect(run, isNotNull, reason: 'LORESPEC.PAS:${item['start']}');
      final actual = ScriptWorldReducer.applyMap(
        ScriptMapState(
          mapId: 25,
          x: start[0],
          y: start[1],
          direction: 0,
          grid: grid,
        ),
        run!.outcome,
      );
      final expected = [for (final row in grid) List<int>.from(row)];
      for (final rawWrite in item['writes'] as List<dynamic>) {
        final write = (rawWrite as List<dynamic>).cast<int>();
        for (var y = write[2]; y <= write[3]; y++) {
          for (var x = write[0]; x <= write[1]; x++) {
            expected[y - 1][x - 1] = write[4];
          }
        }
      }
      expect(actual.grid, expected, reason: 'LORESPEC.PAS:${item['start']}');
      expect([actual.x, actual.y], item['sourceEnd']);
    }
  });

  test('맵 23 성 부상 레버는 0인 칸만 바꾸고 마지막 입구를 연다', () async {
    final fixture = jsonDecode(
      File('test/fixtures/map23_route_parity.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final item = (fixture['cases'] as List<dynamic>).single as Map<String, dynamic>;
    final start = (item['start'] as List<dynamic>).cast<int>();
    final map = await LoreMapData.loadFromAsset('KEEP3', category: 'keep');
    final grid = [for (final row in map.grid) List<int>.from(row)];
    grid[start[1] - 1][start[0] - 1] = item['tileAtPlayer'] as int;
    final engine = LoreScriptEngine();
    engine.loadFromJson(await rootBundle.loadString('assets/data/scripts.json'));
    final run = engine.startStep(
      23, start[0], start[1],
      ScriptContext(tileAtPlayer: item['tileAtPlayer'] as int),
    );
    expect(run?.script.id, 'keep3-trap-25-27');
    final actual = ScriptWorldReducer.applyMap(
      ScriptMapState(
        mapId: 23, x: start[0], y: start[1], direction: 0, grid: grid,
      ),
      run!.outcome,
    );
    final expected = [for (final row in grid) List<int>.from(row)];
    for (final rawWrite in item['writes'] as List<dynamic>) {
      final write = (rawWrite as List<dynamic>).cast<int>();
      for (var y = write[2]; y <= write[3]; y++) {
        for (var x = write[0]; x <= write[1]; x++) {
          expected[y - 1][x - 1] = write[4];
        }
      }
    }
    expect(actual.grid, expected);
    expect([actual.x, actual.y], item['sourceEnd']);
  });
}

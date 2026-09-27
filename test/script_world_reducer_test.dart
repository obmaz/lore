import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/logic/script_world_reducer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('맵 23 레버는 원본처럼 0인 칸만 성벽으로 바꾼다', () async {
    final source = File('repo_source/LORE_1993_src/LORESPEC.PAS')
        .readAsStringSync(encoding: latin1);
    expect(source, contains('if map[i,j] = 0 then map[i,j] := 39;'));
    final engine = LoreScriptEngine();
    engine.loadFromJson(
      await rootBundle.loadString('assets/data/scripts.json'),
    );
    final run = engine.startStep(
      23,
      25,
      27,
      const ScriptContext(tileAtPlayer: 52),
    )!;
    expect(run.script.id, 'keep3-trap-25-27');
    final grid = List.generate(50, (_) => List.filled(50, 0));
    grid[8 - 1][13 - 1] = 44;
    final result = ScriptWorldReducer.applyMap(
      ScriptMapState(mapId: 23, x: 25, y: 27, direction: 0, grid: grid),
      run.outcome,
    );
    expect(result.grid[7 - 1][12 - 1], 39);
    expect(result.grid[8 - 1][13 - 1], 44);
    expect(result.grid[12 - 1][25 - 1], 54);
  });

  test('식량은 원작 상한 255를 적용하고 입력 상태를 바꾸지 않는다', () {
    const before = ScriptResources(gold: 2000, food: 200);
    final after = ScriptWorldReducer.applyResources(
      before,
      const ScriptOutcome(goldDelta: 500, foodDelta: 100),
    );
    expect((after.gold, after.food), (2500, 255));
    expect((before.gold, before.food), (2000, 200));
  });

  test('퀘스트 단계는 순서대로 갱신하고 미확정 동료 플래그를 보류한다', () {
    const before = ScriptProgressState(
      flags: {'met': true},
      quests: {'water': 1},
    );
    const outcome = ScriptOutcome(
      setFlags: ['met', 'rigelJoined', 'gateOpen'],
      questChanges: [
        (name: 'water', set: null, inc: 1),
        (name: 'water', set: null, inc: 2),
        (name: 'gaia', set: 3, inc: null),
      ],
    );
    final after = ScriptWorldReducer.applyProgress(
      before,
      outcome,
      deferredFlags: {'rigelJoined'},
    );
    expect(after.flags['gateOpen'], isTrue);
    expect(after.flags['rigelJoined'], isNull);
    expect(after.quests, {'water': 4, 'gaia': 3});
    expect(before.quests, {'water': 1});
    expect(before.flags, {'met': true});
  });

  test('원본의 대상·영역·현재 칸 변경을 순서대로 적용한다', () {
    final grid = [
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
    ];
    final state = ScriptMapState(
      mapId: 19,
      x: 2,
      y: 3,
      direction: 0,
      grid: grid,
    );
    const outcome = ScriptOutcome(
      tileAtTarget: 47,
      tileChanges: [(map: null, x: 1, y: 1, tile: 44, ifZero: null)],
      tileAreas: [
        (
          map: null,
          xMin: 1,
          xMax: 1,
          yMin: 2,
          yMax: 2,
          tile: 49,
          ifZero: null,
          atPlayerX: true,
          atPlayerY: false,
          onlyIf: 0,
        ),
      ],
      playerTiles: [(tile: 46, ifZero: 40)],
    );
    final result = ScriptWorldReducer.applyMap(
      state,
      outcome,
      talkTargetX: 4,
      talkTargetY: 4,
    );

    expect(result.grid[0][0], 44);
    expect(result.grid[1][1], 49);
    expect(result.grid[2][1], 40);
    expect(result.grid[3][3], 47);
    expect(grid.expand((row) => row), everyElement(0));
  });

  test('다른 맵 지정 변경은 건너뛰고 이동 축 유지와 되돌리기를 적용한다', () {
    final state = ScriptMapState(
      mapId: 20,
      x: 2,
      y: 3,
      direction: 0,
      grid: [
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
      ],
    );
    const outcome = ScriptOutcome(
      tileChanges: [(map: 21, x: 1, y: 1, tile: 44, ifZero: null)],
      nudges: [(dx: 0, dy: 1)],
      stepBack: true,
      teleportMap: 4,
      teleportX: 99,
      teleportY: 2,
      teleportKeepX: true,
    );
    final result = ScriptWorldReducer.applyMap(state, outcome);
    expect((result.mapId, result.x, result.y), (4, 2, 2));
    expect(result.grid[0][0], 0);
    expect((state.mapId, state.x, state.y), (20, 2, 3));
  });
}

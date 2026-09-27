import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/game/lore_world_manager.dart';

class _AlwaysEncounterRandom implements Random {
  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('바이너리 타일맵 및 이동 충돌 테스트 (Map & Field Tests)', () {
    test('enter_water를 실제 이동 경로에서 한 번 실행하고 주문 횟수 뒤 조우한다', () {
      final grid = List.generate(20, (_) => List.filled(20, 24));
      grid[9][10] = 48;
      final map = LoreMapData(
        name: 'WATER_TEST',
        xmax: 20,
        ymax: 20,
        grid: grid,
        category: 'ground',
      );
      var steps = 2;
      final trace = <String>[];
      final game = LoreGame(
        initialMapId: 1,
        initialPlayerX: 10,
        initialPlayerY: 10,
        waterWalkStepsProvider: () => steps,
        onWaterWalkStepsChanged: (value) {
          steps = value;
          trace.add('steps:$value');
        },
        onEncounter: () => trace.add('encounter'),
        random: _AlwaysEncounterRandom(),
      )..currentMap = map;

      expect(game.tryMove(1, 0), isTrue);
      expect((game.playerX, game.playerY), (11, 10));
      expect(trace, ['steps:1', 'encounter']);

      game.playerX = 10;
      steps = 0;
      trace.clear();
      expect(game.tryMove(1, 0), isFalse);
      expect((game.playerX, game.playerY), (10, 10));
      expect(trace, isEmpty);
    });

    test('원본 특수 타일에 진입하면 좌표 스크립트 콜백이 실행된다', () async {
      for (final (mapId, file, category, x, y) in [
        (4, 'SWAMP', 'ground', 20, 39),
        (12, 'T_DEN2', 'den', 12, 48),
        (17, 'DEN4', 'den', 75, 52),
        (18, 'DEN5', 'den', 37, 31),
      ]) {
        final map = await LoreMapData.loadFromAsset(file, category: category);
        var events = 0;
        final game = LoreGame(
          initialMapId: mapId,
          initialPlayerX: x - 1,
          initialPlayerY: y,
          onStepTaken: () {
            events++;
            return true;
          },
        )..currentMap = map;
        expect(game.tryMove(1, 0), isTrue, reason: '맵 $mapId');
        expect(events, 1, reason: '맵 $mapId');
      }
    });

    test('KEEP3의 푯말을 읽으면 (25,27) 레버가 활성화된다', () {
      final grid = List.generate(30, (_) => List.filled(30, 46));
      grid[6][5] = 53;
      final map = LoreMapData(
        name: 'KEEP3',
        xmax: 30,
        ymax: 30,
        grid: grid,
        category: 'keep',
      );
      final game = LoreGame(
        initialMapId: 23,
        initialPlayerX: 6,
        initialPlayerY: 6,
      )..currentMap = map;
      expect(map.getTile(25, 27), 46);
      expect(game.tryMove(0, 1), isFalse);
      expect(map.getTile(25, 27), 52);
    });

    test('KEEP2의 52 특수 칸 출구도 포털 확인과 수문장 스크립트를 요청한다', () async {
      LoreWorldManager.instance.resetRulesForTest();
      final map = await LoreMapData.loadFromAsset('KEEP2', category: 'keep');
      PortalInfo? requested;
      final game = LoreGame(
        onPortalRequested: (portal, _, _) => requested = portal,
      )..currentMap = map;
      game.currentMapId = 22;
      game.playerX = 25;
      game.playerY = 45;
      expect(map.getTile(25, 46), 52);
      expect(game.tryMove(0, 1), isFalse);
      expect(requested?.scriptId, 'keep2-exit-guard');
      expect(game.playerY, 45);
    });

    test('실제 맵 로더가 맵 종류를 보존해 던전·필드 타일을 구분한다', () async {
      final den = await LoreMapData.loadFromAsset('DEN4', category: 'den');
      expect(den.category, 'den');
      expect(den.getTile(72, 19), 52);
      expect(den.getCategory(den.getTile(72, 19)), TileCategory.special);
      expect(den.getCategory(den.getTile(66, 13)), TileCategory.sign);
      expect(den.getCategory(den.getTile(80, 67)), TileCategory.portal);

      final ground = await LoreMapData.loadFromAsset(
        'GROUND1',
        category: 'ground',
      );
      expect(ground.category, 'ground');
      expect(ground.getCategory(ground.getTile(12, 5)), TileCategory.water);
      expect(ground.getCategory(ground.getTile(20, 11)), TileCategory.portal);

      final keep = await LoreMapData.loadFromAsset('KEEP3', category: 'keep');
      expect(keep.getCategory(40), TileCategory.walkable);
      expect(den.getCategory(40), TileCategory.wall);
      expect(
        keep.grid.expand((row) => row).where((tile) => tile == 40),
        isNotEmpty,
      );
    });

    test('저장한 현재 맵의 타일 변경을 다시 불러온다', () async {
      final original = await LoreMapData.loadFromAsset(
        'T_DEN2',
        category: 'den',
      );
      final tiles = [for (final row in original.grid) ...row];
      final index = (9 - 1) * original.xmax + (18 - 1);
      tiles[index] = 0; // 황금의 봉인을 얻고 통로가 열린 상태

      final restored = await LoreMapData.loadFromAsset(
        'T_DEN2',
        category: 'den',
      );
      restored.applyTileSnapshot(tiles);
      expect(restored.getTile(18, 9), 0);
    });

    test('좌표 이벤트가 처리한 걸음에는 일반 무작위 전투가 겹치지 않는다', () {
      final grid = List.generate(20, (_) => List.filled(20, 42));
      grid[5][6] = 0;
      final mapData = LoreMapData(name: 'TEST', xmax: 20, ymax: 20, grid: grid);
      var encounters = 0;
      final eventGame = LoreGame(
        initialMapId: 1,
        initialPlayerX: 6,
        initialPlayerY: 6,
        random: _AlwaysEncounterRandom(),
        onStepTaken: () => true,
        onEncounter: () => encounters++,
      )..currentMap = mapData;
      expect(eventGame.tryMove(1, 0), isTrue);
      expect(encounters, 0);

      grid[5][6] = 42;
      final ordinaryGame = LoreGame(
        initialMapId: 1,
        initialPlayerX: 6,
        initialPlayerY: 6,
        random: _AlwaysEncounterRandom(),
        onStepTaken: () => false,
        onEncounter: () => encounters++,
      )..currentMap = mapData;
      expect(ordinaryGame.tryMove(1, 0), isTrue);
      expect(encounters, 1);
    });

    test('원본 이동 핸들러 순서로 독·독심술·늪 효과를 호출한다', () {
      final grid = List.generate(20, (_) => List.filled(20, 42));
      final mapData = LoreMapData(
        name: 'TEST',
        xmax: 20,
        ymax: 20,
        grid: grid,
        category: 'town',
      );
      final effects = <String>[];
      final game = LoreGame(
        initialMapId: 6,
        initialPlayerX: 6,
        initialPlayerY: 6,
        onPoisonTick: () => effects.add('poison'),
        onMindReadTick: () => effects.add('mind-read'),
        onHazardTile: (_) => effects.add('hazard'),
        onStepTaken: () {
          effects.add('step');
          return false;
        },
      )..currentMap = mapData;
      expect(game.tryMove(1, 0), isTrue);
      expect(effects, ['poison', 'mind-read', 'step']);
      effects.clear();
      mapData.grid[5][7] = 25;
      expect(game.tryMove(1, 0), isTrue);
      expect(effects, ['poison', 'hazard', 'step']);
      effects.clear();
      mapData.grid[5][8] = 0;
      expect(game.tryMove(1, 0), isTrue);
      expect(effects, ['step']);
    });

    test('1. LoreMapData 타일 카테고리 판정 검증', () {
      // 10x10 테스트 맵 구성 (외곽은 벽 1, 내부는 42)
      final grid = List.generate(
        10,
        (y) => List.generate(10, (x) {
          if (x == 0 || y == 0 || x == 9 || y == 9) return 1; // 외곽 성벽
          if (x == 5 && y == 5) return 48; // NPC
          if (x == 8 && y == 8) return 22; // 성문
          return 42; // 바닥 길
        }),
      );

      final mapData = LoreMapData(name: 'TEST', xmax: 10, ymax: 10, grid: grid);

      // 성벽(1): wall -> 통과 불가
      expect(mapData.getCategory(1), equals(TileCategory.wall));
      expect(mapData.isPassable(1, 1), isFalse); // (1, 1)은 x=0, y=0 -> 벽(1)

      // 바닥(42): walkable -> 통과 가능
      expect(mapData.getCategory(42), equals(TileCategory.walkable));
      expect(mapData.isPassable(3, 3), isTrue); // (3, 3)은 x=2, y=2 -> 길(42)

      // NPC(48): npc -> 겹침 불가
      expect(mapData.getCategory(48), equals(TileCategory.npc));
      expect(mapData.isPassable(6, 6), isFalse); // (6, 6)은 x=5, y=5 -> NPC(48)

      // 성문(22): portal -> 통과 가능
      expect(mapData.getCategory(22), equals(TileCategory.portal));
      expect(mapData.isPassable(9, 9), isTrue); // (9, 9)은 x=8, y=8 -> 성문(22)
    });

    test('2. LoreGame 플레이어 이동 및 방향 전환 검증', () {
      // 원본 이동 경계 안쪽의 길과 벽을 검사한다.
      final grid = List.generate(
        20,
        (y) => List.generate(20, (x) {
          if (x == 0 || y == 0 || x == 19 || y == 19) return 1;
          if (x == 4 && y == 5) return 1; // (5, 6) 내부 벽
          return 42;
        }),
      );
      final mapData = LoreMapData(name: 'TEST', xmax: 20, ymax: 20, grid: grid);

      final game = LoreGame();
      game.currentMap = mapData;
      game.playerX = 6;
      game.playerY = 6;

      // 동쪽 이동 (1, 0) -> (7, 6)으로 이동 성공
      final moved = game.tryMove(1, 0);
      expect(moved, isTrue);
      expect(game.playerX, equals(7));
      expect(game.playerY, equals(6));
      expect(game.playerDirection, equals(2)); // 동

      // 서쪽으로 (6, 6) 이동 성공
      final movedLeft = game.tryMove(-1, 0);
      expect(movedLeft, isTrue);
      expect(game.playerX, equals(6));

      // 서쪽의 내부 벽 (5, 6) 충돌 차단
      final hitWall = game.tryMove(-1, 0);
      expect(hitWall, isFalse);
      expect(game.playerX, equals(6)); // 원래 위치 유지
    });

    test('3. 카메라 연출(원작 scroll(FALSE)) 상태 검증', () {
      final grid = List.generate(10, (y) => List.generate(10, (x) => 42));
      final mapData = LoreMapData(name: 'TEST', xmax: 10, ymax: 10, grid: grid);
      final game = LoreGame(
        initialMapId: 4,
        initialPlayerX: 3,
        initialPlayerY: 3,
      )..currentMap = mapData;

      // 연출 전: 시야는 파티 위치
      expect(game.isPeeking, isFalse);
      expect(game.viewCenterX, 3);
      expect(game.viewCenterY, 3);

      // 원작 `x := 48; y := 57; scroll(FALSE);` - 파티는 그대로, 시야만 이동
      game.peekAt(48, 57);
      expect(game.isPeeking, isTrue);
      expect(game.viewCenterX, 48);
      expect(game.viewCenterY, 57);
      expect(game.playerX, 3, reason: '연출 중에도 파티 좌표는 변하지 않는다');
      expect(game.playerY, 3);

      // 원작 `scroll(TRUE)` - 시야 복귀
      game.clearPeek();
      expect(game.isPeeking, isFalse);
      expect(game.viewCenterX, 3);
      expect(game.viewCenterY, 3);
    });
  });
}

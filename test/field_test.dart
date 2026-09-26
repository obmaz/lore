import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/game/lore_map_manager.dart';

void main() {
  group('바이너리 타일맵 및 이동 충돌 테스트 (Map & Field Tests)', () {
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
      // (1, 1)부터 (10, 10) 중 x=1, y=1 테두리는 벽(1), 내부는 42
      final grid = List.generate(
        10,
        (y) => List.generate(10, (x) {
          if (x == 0 || y == 0 || x == 9 || y == 9) return 1;
          return 42;
        }),
      );
      final mapData = LoreMapData(name: 'TEST', xmax: 10, ymax: 10, grid: grid);

      final game = LoreGame();
      game.currentMap = mapData;
      game.playerX = 3;
      game.playerY = 3;

      // 동쪽 이동 (1, 0) -> (4, 3)으로 이동 성공
      final moved = game.tryMove(1, 0);
      expect(moved, isTrue);
      expect(game.playerX, equals(4));
      expect(game.playerY, equals(3));
      expect(game.playerDirection, equals(2)); // 동

      // 서쪽으로 (2, 3) 이동 성공
      game.playerX = 3;
      final movedLeft = game.tryMove(-1, 0); // (2, 3) 바닥 -> 이동 성공
      expect(movedLeft, isTrue);
      expect(game.playerX, equals(2));

      // 서쪽으로 (1, 3) 벽으로 이동 시도 -> 벽 충돌 차단
      final hitWall = game.tryMove(-1, 0); // (1, 3)은 x=0 벽 -> 이동 실패
      expect(hitWall, isFalse);
      expect(game.playerX, equals(2)); // 원래 위치 유지
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

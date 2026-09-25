import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_game.dart';

void main() {
  group('Phase 4: 그리드 타일맵 이동 및 충돌 검증 (Field Navigation Tests)', () {
    test('1. 시작 위치 및 유효 이동 검증', () {
      final game = LoreGame();
      expect(game.playerX, equals(1));
      expect(game.playerY, equals(1));

      // (1,1)에서 (2,1)로 오른쪽 이동 (mapGrid[1][2] == 0 평지)
      final moved = game.tryMove(1, 0);
      expect(moved, isTrue);
      expect(game.playerX, equals(2));
      expect(game.playerY, equals(1));
      expect(game.playerDirection, equals(2)); // 동쪽
    });

    test('2. 성벽(1) 충돌 판정 및 이동 차단 검증', () {
      final game = LoreGame();
      // (1,1)에서 위쪽(0, -1) 이동 시도 -> (1,0)은 성벽(1)
      final moved = game.tryMove(0, -1);
      expect(moved, isFalse);
      expect(game.playerX, equals(1));
      expect(game.playerY, equals(1)); // 이동하지 않고 원래 위치 유지
    });

    test('3. 맵 외곽 경계 차단 검증', () {
      final game = LoreGame();
      game.playerX = 0;
      game.playerY = 0;

      // 맵 밖으로 이동 시도 (-1, 0)
      final moved = game.tryMove(-1, 0);
      expect(moved, isFalse);
      expect(game.playerX, equals(0));
    });
  });
}

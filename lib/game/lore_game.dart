import 'dart:math';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/retro_theme.dart';

/// 10x10 격자 기반 맵 및 플레이어 이동을 담당하는 Flame 2D 게임엔진 클래스
class LoreGame extends FlameGame {
  static const int mapWidth = 10;
  static const int mapHeight = 10;
  static const double tileSize = 32.0;

  // 1단계 테스트 10x10 맵 (0: 평지/바닥, 1: 성벽/바위산, 2: 마을 입구)
  final List<List<int>> mapGrid = [
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
    [1, 0, 0, 0, 0, 0, 0, 0, 2, 1],
    [1, 0, 1, 1, 0, 0, 1, 0, 0, 1],
    [1, 0, 1, 0, 0, 0, 1, 0, 0, 1],
    [1, 0, 0, 0, 1, 0, 0, 0, 0, 1],
    [1, 0, 0, 0, 1, 0, 0, 1, 0, 1],
    [1, 0, 1, 0, 0, 0, 0, 1, 0, 1],
    [1, 0, 1, 1, 0, 1, 0, 0, 0, 1],
    [1, 0, 0, 0, 0, 1, 0, 0, 0, 1],
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
  ];

  int playerX = 1;
  int playerY = 1;
  int playerDirection = 0; // 0: 남, 1: 북, 2: 동, 3: 서

  final void Function(String message)? onLog;
  final void Function()? onEncounter;
  final void Function()? onTownEntered;
  final void Function(int x, int y)? onPositionChanged;
  final Random _random = Random();

  LoreGame({
    this.onLog,
    this.onEncounter,
    this.onTownEntered,
    this.onPositionChanged,
  });

  @override
  Color backgroundColor() => RetroTheme.viewportBg;

  /// 플레이어 이동 처리 (D-Pad 및 키보드 공용)
  bool tryMove(int dx, int dy) {
    if (dx == 0 && dy == 1) playerDirection = 0; // 남
    if (dx == 0 && dy == -1) playerDirection = 1; // 북
    if (dx == 1 && dy == 0) playerDirection = 2; // 동
    if (dx == -1 && dy == 0) playerDirection = 3; // 서

    final targetX = playerX + dx;
    final targetY = playerY + dy;

    // 맵 경계 체크
    if (targetX < 0 || targetX >= mapWidth || targetY < 0 || targetY >= mapHeight) {
      onLog?.call('더 이상 나아갈 수 없는 경계 지역입니다.');
      return false;
    }

    final tile = mapGrid[targetY][targetX];

    // 벽(1) 충돌 처리
    if (tile == 1) {
      onLog?.call('벽이 가로막고 있어 통과할 수 없습니다.');
      return false;
    }

    // 이동 성공
    playerX = targetX;
    playerY = targetY;
    onPositionChanged?.call(playerX, playerY);

    if (tile == 2) {
      onLog?.call('마을 입구에 도착했습니다. (CASTLE LORE)');
      onTownEntered?.call();
    } else {
      onLog?.call('일행은 ($playerX, $playerY) 좌표로 이동했습니다.');
    }

    // 약 10% 확률로 몬스터 인카운터 발생
    if (_random.nextInt(10) == 0) {
      onLog?.call('!! 적의 기척이 느껴집니다! 전투 모드로 돌입합니다!');
      onEncounter?.call();
    }

    return true;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final offsetX = (size.x - (mapWidth * tileSize)) / 2;
    final offsetY = (size.y - (mapHeight * tileSize)) / 2;

    // 1. 타일맵 렌더링
    for (int y = 0; y < mapHeight; y++) {
      for (int x = 0; x < mapWidth; x++) {
        final tileType = mapGrid[y][x];
        final rect = Rect.fromLTWH(
          offsetX + x * tileSize,
          offsetY + y * tileSize,
          tileSize,
          tileSize,
        );

        final paint = Paint();
        if (tileType == 1) {
          // 벽 (어두운 회색/청색 벽돌)
          paint.color = const Color(0xFF222244);
          canvas.drawRect(rect, paint);
          // 벽돌 격자선
          final borderPaint = Paint()
            ..color = const Color(0xFF444477)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0;
          canvas.drawRect(rect, borderPaint);
        } else if (tileType == 2) {
          // 마을 (금색/황토색)
          paint.color = const Color(0xFF886622);
          canvas.drawRect(rect, paint);
          final starPaint = Paint()
            ..color = RetroTheme.yellow
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0;
          canvas.drawCircle(rect.center, tileSize * 0.25, starPaint);
        } else {
          // 바닥 (어두운 녹색/흙길)
          paint.color = const Color(0xFF0F2515);
          canvas.drawRect(rect, paint);
          final dotPaint = Paint()..color = const Color(0xFF1B4024);
          canvas.drawCircle(Offset(rect.left + 8, rect.top + 8), 1.5, dotPaint);
          canvas.drawCircle(Offset(rect.right - 8, rect.bottom - 8), 1.5, dotPaint);
        }
      }
    }

    // 2. 플레이어 캐릭터 렌더링 (도스 감성의 황금 기사 마크)
    final playerRect = Rect.fromLTWH(
      offsetX + playerX * tileSize + 4,
      offsetY + playerY * tileSize + 4,
      tileSize - 8,
      tileSize - 8,
    );

    // 캐릭터 본체
    final playerPaint = Paint()..color = RetroTheme.yellow;
    canvas.drawRRect(
      RRect.fromRectAndRadius(playerRect, const Radius.circular(4)),
      playerPaint,
    );

    // 캐릭터 테두리
    final playerBorder = Paint()
      ..color = RetroTheme.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(playerRect, const Radius.circular(4)),
      playerBorder,
    );

    // 바라보는 방향 표시 점
    final eyePaint = Paint()..color = RetroTheme.red;
    Offset eyeOffset;
    switch (playerDirection) {
      case 0: // 남
        eyeOffset = Offset(playerRect.center.dx, playerRect.bottom - 4);
        break;
      case 1: // 북
        eyeOffset = Offset(playerRect.center.dx, playerRect.top + 4);
        break;
      case 2: // 동
        eyeOffset = Offset(playerRect.right - 4, playerRect.center.dy);
        break;
      default: // 서
        eyeOffset = Offset(playerRect.left + 4, playerRect.center.dy);
        break;
    }
    canvas.drawCircle(eyeOffset, 2.5, eyePaint);
  }

  void handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
        event.logicalKey == LogicalKeyboardKey.keyW) {
      tryMove(0, -1);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
        event.logicalKey == LogicalKeyboardKey.keyS) {
      tryMove(0, 1);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.keyA) {
      tryMove(-1, 0);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.keyD) {
      tryMove(1, 0);
    }
  }
}

import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/retro_theme.dart';
import 'lore_map_manager.dart';
import 'bgi_font_decoder.dart';

/// 1993년 원작의 실제 100x100 바이너리 맵(TOWN1.MAP, GROUND1.MAP 등)과
/// 원작 CHARA.FNT 스프라이트 렌더링을 지원하는 Flame 2D 엔진
class LoreGame extends FlameGame {
  static const int viewTilesX = 11;
  static const int viewTilesY = 11;
  static const double tileSize = 28.0;

  LoreMapData? currentMap;
  String currentMapName = 'TOWN1'; // 1993년 원작 시작 맵: CASTLE LORE 성내 마을

  // 원작 4-plane BGI 폰트 디코더 (캐릭터 및 타일)
  BgiFontDecoder? charaFont;
  BgiFontDecoder? townFont;
  BgiFontDecoder? groundFont;

  // 원작 LORECRET.PAS 및 LOREMAIN.PAS 기준 초기 시작 좌표: (51, 31)
  int playerX = 51;
  int playerY = 31;
  int playerDirection = 0; // 0: 남, 1: 북, 2: 동, 3: 서

  final void Function(String message)? onLog;
  final void Function()? onEncounter;
  final void Function()? onTownEntered;
  final void Function(String npcName, String dialogue)? onNpcTalk;
  final void Function(int x, int y)? onPositionChanged;
  final Random _random = Random();

  LoreGame({
    this.onLog,
    this.onEncounter,
    this.onTownEntered,
    this.onNpcTalk,
    this.onPositionChanged,
  });

  @override
  Color backgroundColor() => RetroTheme.viewportBg;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      charaFont = await BgiFontDecoder.loadFromAsset('CHARA');
      townFont = await BgiFontDecoder.loadFromAsset('TOWN');
      groundFont = await BgiFontDecoder.loadFromAsset('GROUND');
    } catch (e) {
      // 폰트 에셋 로드 실패 시 무시 (fallback 벡터 드로잉)
    }
    await loadMap('TOWN1');
  }

  Future<void> loadMap(String mapName, {int? startX, int? startY}) async {
    try {
      currentMap = await LoreMapData.loadFromAsset(mapName);
      currentMapName = mapName;
      if (startX != null && startY != null) {
        playerX = startX;
        playerY = startY;
      }
      onLog?.call(
        '지도 [$mapName] 로드 완료 (크기: ${currentMap!.xmax}x${currentMap!.ymax})',
      );
    } catch (e) {
      // 에셋 로드 실패 시 안전 fallback
      onLog?.call('지도 파일 로드 실패: $e');
    }
  }

  /// 플레이어 이동 처리
  bool tryMove(int dx, int dy) {
    if (dx == 0 && dy == 1) playerDirection = 0; // 남
    if (dx == 0 && dy == -1) playerDirection = 1; // 북
    if (dx == 1 && dy == 0) playerDirection = 2; // 동
    if (dx == -1 && dy == 0) playerDirection = 3; // 서

    final targetX = playerX + dx;
    final targetY = playerY + dy;

    if (currentMap == null) return false;

    // 맵 경계 체크
    if (targetX < 1 ||
        targetX > currentMap!.xmax ||
        targetY < 1 ||
        targetY > currentMap!.ymax) {
      onLog?.call('더 이상 나아갈 수 없는 경계 지역입니다.');
      return false;
    }

    final tileVal = currentMap!.getTile(targetX, targetY);
    final cat = currentMap!.getCategory(tileVal);

    // 1. 벽 충돌 (1..21)
    if (cat == TileCategory.wall) {
      onLog?.call('단단한 성벽과 바위가 가로막아 지나갈 수 없습니다.');
      return false;
    }

    // 2. 주민/NPC 상호작용 (48+)
    if (cat == TileCategory.npc) {
      _handleNpcInteraction(tileVal, targetX, targetY);
      return false;
    }

    // 3. 성문/포털 이동 (22)
    if (cat == TileCategory.portal) {
      _handlePortal();
      return true;
    }

    // 4. 이동 성공
    playerX = targetX;
    playerY = targetY;
    onPositionChanged?.call(playerX, playerY);

    // 특수 타일 효과
    if (cat == TileCategory.swamp) {
      onLog?.call('독이 있는 늪지에 발을 디뎠습니다! 주의하십시오.');
    } else if (cat == TileCategory.lava) {
      onLog?.call('뜨거운 용암 지대에 접근했습니다!');
    }

    // 필드(GROUND1)일 때 약 10% 확률로 몬스터 인카운터 발생
    if (currentMapName.startsWith('GROUND') ||
        currentMapName.startsWith('DEN')) {
      if (_random.nextInt(10) == 0) {
        onLog?.call('!! 적의 기척이 느껴집니다! 전투 모드로 돌입합니다!');
        onEncounter?.call();
      }
    }

    return true;
  }

  void _handleNpcInteraction(int tileVal, int tx, int ty) {
    if (currentMapName == 'TOWN1') {
      if (tx == 9 && ty == 64) {
        onNpcTalk?.call(
          '경비병',
          '모험을 시작한다면 많은 괴물을 만날 것이오. Serpent와 Python은 맹독이 있으니 주의하시오.',
        );
      } else if (tx == 72 && ty == 73) {
        onNpcTalk?.call('마을 주민', 'Orc는 가장 하급 괴물이오.');
      } else if (tx == 19 && ty == 53) {
        onNpcTalk?.call('성전의 석판', '이 세계의 창시자는 안영기 님이시며, 그는 위대한 프로그래머입니다.');
      } else {
        onNpcTalk?.call('마을 주민', '어서 오십시오. 여기는 지식의 성전 성내 마을(CASTLE LORE)입니다.');
      }
      onTownEntered?.call();
    }
  }

  void _handlePortal() {
    if (currentMapName == 'TOWN1') {
      // 성 밖 대륙 필드로 나가기
      loadMap('GROUND1', startX: 20, startY: 12);
      onLog?.call('성문을 나와 광활한 LORE 대륙 필드(GROUND1)로 나섰습니다.');
    } else {
      // 마을로 귀환
      loadMap('TOWN1', startX: 51, startY: 95);
      onLog?.call('성전 마을 CASTLE LORE 성내로 귀환했습니다.');
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (currentMap == null) return;

    final halfX = viewTilesX ~/ 2;
    final halfY = viewTilesY ~/ 2;

    final offsetX = (size.x - (viewTilesX * tileSize)) / 2;
    final offsetY = (size.y - (viewTilesY * tileSize)) / 2;

    // 1. 플레이어 중심 11x11 뷰포트 렌더링
    for (int vy = 0; vy < viewTilesY; vy++) {
      for (int vx = 0; vx < viewTilesX; vx++) {
        final worldX = playerX - halfX + vx;
        final worldY = playerY - halfY + vy;

        final rect = Rect.fromLTWH(
          offsetX + vx * tileSize,
          offsetY + vy * tileSize,
          tileSize,
          tileSize,
        );

        final tileVal = currentMap!.getTile(worldX, worldY);
        final cat = currentMap!.getCategory(tileVal);

        // 원작 FNT 타일 스프라이트가 존재하면 원작 픽셀 아트로 즉시 렌더링
        final activeTileFont = currentMapName.startsWith('TOWN') ? townFont : groundFont;
        if (activeTileFont != null && tileVal >= 0 && tileVal < activeTileFont.totalSprites) {
          activeTileFont.renderSprite(canvas, tileVal, rect, opaqueBackground: true);
        } else {
          final paint = Paint();
          switch (cat) {
            case TileCategory.wall:
              paint.color = const Color(0xFF1E284A);
              canvas.drawRect(rect, paint);
              final brickPaint = Paint()
                ..color = const Color(0xFF384B78)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.0;
              canvas.drawRect(rect, brickPaint);
              break;

            case TileCategory.portal:
              paint.color = const Color(0xFF886622);
              canvas.drawRect(rect, paint);
              final gatePaint = Paint()
                ..color = RetroTheme.yellow
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.0;
              canvas.drawCircle(rect.center, tileSize * 0.35, gatePaint);
              break;

            case TileCategory.npc:
              paint.color = const Color(0xFF152A18);
              canvas.drawRect(rect, paint);
              final npcPaint = Paint()..color = RetroTheme.lightCyan;
              canvas.drawCircle(rect.center, tileSize * 0.28, npcPaint);
              break;

            case TileCategory.water:
              paint.color = const Color(0xFF0A2555);
              canvas.drawRect(rect, paint);
              break;

            case TileCategory.swamp:
              paint.color = const Color(0xFF253B15);
              canvas.drawRect(rect, paint);
              break;

            case TileCategory.lava:
              paint.color = const Color(0xFF551100);
              canvas.drawRect(rect, paint);
              break;

            case TileCategory.walkable:
            default:
              paint.color = const Color(0xFF101B12);
              canvas.drawRect(rect, paint);
              break;
          }
        }
      }
    }

    // 2. 뷰포트 정중앙에 위치한 플레이어 캐릭터 렌더링 (원작 CHARA.FNT 20x20 픽셀 아트)
    final centerRect = Rect.fromLTWH(
      offsetX + halfX * tileSize + 2,
      offsetY + halfY * tileSize + 2,
      tileSize - 4,
      tileSize - 4,
    );

    if (charaFont != null) {
      // 원작 LORESUB.PAS 기준 방향 인덱스:
      // 남: 0, 북: 1, 동: 2, 서: 3 (필드 시 +4)
      int face = playerDirection;
      if (!currentMapName.startsWith('TOWN')) {
        face += 4;
      }
      charaFont!.renderSprite(canvas, face, centerRect);
    } else {
      // Fallback 벡터 렌더링
      final playerPaint = Paint()..color = RetroTheme.yellow;
      canvas.drawRRect(
        RRect.fromRectAndRadius(centerRect, const Radius.circular(4)),
        playerPaint,
      );

      final playerBorder = Paint()
        ..color = RetroTheme.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawRRect(
        RRect.fromRectAndRadius(centerRect, const Radius.circular(4)),
        playerBorder,
      );

      final eyePaint = Paint()..color = RetroTheme.red;
      Offset eyeOffset;
      switch (playerDirection) {
        case 0: // 남
          eyeOffset = Offset(centerRect.center.dx, centerRect.bottom - 4);
          break;
        case 1: // 북
          eyeOffset = Offset(centerRect.center.dx, centerRect.top + 4);
          break;
        case 2: // 동
          eyeOffset = Offset(centerRect.right - 4, centerRect.center.dy);
          break;
        default: // 서
          eyeOffset = Offset(centerRect.left + 4, centerRect.center.dy);
          break;
      }
      canvas.drawCircle(eyeOffset, 2.5, eyePaint);
    }
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

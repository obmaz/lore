import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/retro_theme.dart';
import '../logic/lore_join.dart';
import '../models/party_member.dart';
import '../services/audio_manager.dart';
import 'lore_map_manager.dart';
import 'lore_world_manager.dart';
import 'lore_dialogue_manager.dart';
import 'bgi_font_decoder.dart';

/// 1993년 원작의 실제 100x100 바이너리 맵(TOWN1.MAP, GROUND1.MAP 등)과
/// 원작 CHARA.FNT 스프라이트 렌더링을 지원하는 Flame 2D 엔진
class LoreGame extends FlameGame {
  static const int viewTilesX = 11;
  static const int viewTilesY = 11;
  static const double tileSize = 28.0;

  LoreMapData? currentMap;
  int currentMapId = 6; // 원작 시작 맵: 6 (CASTLE LORE)
  String currentMapName = 'TOWN1';

  // 원작 4-plane BGI 폰트 디코더 (캐릭터 및 타일)
  BgiFontDecoder? charaFont;
  BgiFontDecoder? townFont;
  BgiFontDecoder? groundFont;
  BgiFontDecoder? denFont;
  BgiFontDecoder? keepFont;

  // 원작 LORECRET.PAS 및 LOREMAIN.PAS 기준 초기 시작 좌표: (51, 31)
  int playerX = 51;
  int playerY = 31;
  int playerDirection = 0; // 0: 남, 1: 북, 2: 동, 3: 서

  final void Function(String message)? onLog;
  final void Function()? onEncounter;
  final void Function()? onTownEntered;
  final void Function(String npcName, String dialogue)? onNpcTalk;
  final void Function(int facilityType)? onFacilityEntered;
  final void Function(int x, int y)? onPositionChanged;
  final void Function(TileCategory category)? onHazardTile;
  final void Function()? onStepTaken;

  /// 원작 `join(num, partynum)`으로 동료가 합류할 때 호출된다.
  final void Function(PendingRecruit recruit)? onRecruitRequested;

  /// 좌표 대화의 조건 분기(예: Spica 영입 조건)에 필요한 파티 상태 제공자.
  final List<PartyMember> Function()? partyProvider;

  /// 원작 `party.etc[5]`(독심술 사용 가능 횟수) 제공자.
  final int Function()? mindReadCountProvider;

  /// 성문/동굴 입구 앞에 섰을 때 호출된다 (원작 `wantenter`/`wantexit`).
  /// 확인 대화상자에서 승인하면 화면단이 [enterPortal]을 호출한다.
  final void Function(PortalInfo? portal, int tx, int ty)? onPortalRequested;

  final bool Function()? canWalkOnWater;
  final Random _random = Random();

  LoreGame({
    int initialMapId = 6,
    int initialPlayerX = 51,
    int initialPlayerY = 31,
    this.onLog,
    this.onEncounter,
    this.onTownEntered,
    this.onNpcTalk,
    this.onFacilityEntered,
    this.onPositionChanged,
    this.onHazardTile,
    this.onStepTaken,
    this.onRecruitRequested,
    this.partyProvider,
    this.mindReadCountProvider,
    this.onPortalRequested,
    this.canWalkOnWater,
  }) : currentMapId = initialMapId,
       playerX = initialPlayerX,
       playerY = initialPlayerY;

  @override
  Color backgroundColor() => RetroTheme.viewportBg;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      charaFont = await BgiFontDecoder.loadFromAsset('CHARA');
      townFont = await BgiFontDecoder.loadFromAsset('TOWN');
      groundFont = await BgiFontDecoder.loadFromAsset('GROUND');
      denFont = await BgiFontDecoder.loadFromAsset('DEN');
      keepFont = await BgiFontDecoder.loadFromAsset('KEEP');
    } catch (e) {
      // 폰트 에셋 로드 실패 시 무시 (fallback 벡터 드로잉)
    }
    await loadMapById(currentMapId, startX: playerX, startY: playerY);
  }

  Future<void> loadMapById(int mapId, {int? startX, int? startY}) async {
    final info = LoreWorldManager.mapRegistry[mapId];
    if (info == null) return;
    currentMapId = mapId;
    currentMapName = info.fileName;
    try {
      currentMap = await LoreMapData.loadFromAsset(info.fileName);
      if (startX != null && startY != null) {
        playerX = startX;
        playerY = startY;
      }
      onLog?.call(
        '지도 [${info.title}] 진입 (크기: ${currentMap!.xmax}x${currentMap!.ymax})',
      );
      // 원작 BGM 전환
      AudioManager.instance.playBgm(info.bgmTrack);
    } catch (e) {
      onLog?.call('지도 파일 로드 실패: $e');
    }
  }

  Future<void> loadMap(String mapName, {int? startX, int? startY}) async {
    int targetId = 6;
    for (final entry in LoreWorldManager.mapRegistry.entries) {
      if (entry.value.fileName.toUpperCase() == mapName.toUpperCase()) {
        targetId = entry.key;
        break;
      }
    }
    await loadMapById(targetId, startX: startX, startY: startY);
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

    // 2. 물/바다 진입 제약 (배 또는 물위를 걸음 마법 필요)
    if (cat == TileCategory.water) {
      if (canWalkOnWater?.call() != true) {
        onLog?.call('깊은 물속은 배나 [물위를 걸음] 마법 없이는 건널 수 없습니다!');
        return false;
      }
    }

    // 3. 주민/NPC 상호작용 (48+)
    if (cat == TileCategory.npc) {
      _handleNpcInteraction(tileVal, targetX, targetY);
      return false;
    }

    // 4. 성문/포털 이동 (22)
    if (cat == TileCategory.portal) {
      final portal = LoreWorldManager.instance.findPortal(
        currentMapId,
        targetX,
        targetY,
      );
      if (onPortalRequested != null) {
        // 원작 wantenter/wantexit: 화면단에서 확인을 받은 뒤 enterPortal 호출
        onPortalRequested!(portal, targetX, targetY);
        return false;
      }
      enterPortal(portal, targetX, targetY);
      return true;
    }

    // 5. 표지판/푯말 상호작용 (23)
    if (cat == TileCategory.sign) {
      _handleSign(targetX, targetY);
      return false;
    }

    // 6. 이동 성공
    playerX = targetX;
    playerY = targetY;
    onPositionChanged?.call(playerX, playerY);

    // 위험 지형 콜백 호출 (독 늪, 용암 등)
    if (cat == TileCategory.swamp ||
        cat == TileCategory.lava ||
        cat == TileCategory.water) {
      onHazardTile?.call(cat);
    }
    onStepTaken?.call();

    // 필드(GROUND1)일 때 약 10% 확률로 몬스터 인카운터 발생
    final mapCat = LoreWorldManager.mapRegistry[currentMapId]?.category;
    if (mapCat == MapCategory.ground || mapCat == MapCategory.den) {
      if (_random.nextInt(10) == 0) {
        onLog?.call('!! 적의 기척이 느껴집니다! 전투 모드로 돌입합니다!');
        onEncounter?.call();
      }
    }

    return true;
  }

  void _handleSign(int tx, int ty) {
    final msg = LoreWorldManager.instance.getSignMessage(currentMapId, tx, ty);
    if (msg != null) {
      onLog?.call(msg);
    } else {
      onLog?.call('푯말에 흐릿한 글씨가 적혀 있습니다.');
    }
  }

  void _handleNpcInteraction(int tileVal, int tx, int ty) {
    if (currentMapName == 'TOWN1') {
      // 1. 원작 LORETALK.PAS 마을 시설 상점 판정
      if ((tx == 8 && ty == 71) ||
          (tx == 14 && ty == 69) ||
          (tx == 14 && ty == 73)) {
        onFacilityEntered?.call(1); // 무기점
        return;
      }
      if ((tx == 87 && ty == 14) || (tx == 86 && ty == 12)) {
        onFacilityEntered?.call(2); // 병원
        return;
      }
      if ((tx == 21 && ty == 12) || (tx == 25 && ty == 13)) {
        onFacilityEntered?.call(3); // 훈련소
        return;
      }
      if ((tx == 87 && ty == 73) || (tx == 91 && ty == 65)) {
        onFacilityEntered?.call(4); // 식료품점
        return;
      }
    }

    // 2. 원작 LORETALK.PAS / LORESPEC.PAS 실제 주민, 영주, 동료 대화 연동
    //    (마을뿐 아니라 모든 맵에서 좌표 기반 대화가 동작한다)
    final dlg = LoreDialogueManager.instance.getDialogue(
      currentMapId,
      tx,
      ty,
      'Hero',
      party: partyProvider?.call(),
      mindReadCount: mindReadCountProvider?.call() ?? 0,
    );
    if (dlg != null) {
      onLog?.call(dlg);
      _flushPendingRecruits();
      return;
    }

    if (currentMapName == 'TOWN1') {
      onNpcTalk?.call('마을 주민', '어서 오십시오. 여기는 지식의 성전 성내 마을(CASTLE LORE)입니다.');
      onTownEntered?.call();
      return;
    }
    onLog?.call('주민은 더 이상 할 말이 없는 듯합니다.');
  }

  /// 원작 `join(num, partynum)` 대기열을 실제 일행 합류로 전환한다.
  void _flushPendingRecruits() {
    for (final recruit in LoreDialogueManager.instance.takePendingRecruits()) {
      onRecruitRequested?.call(recruit);
    }
  }

  /// 성문/동굴 입구 진입 처리.
  /// 원작 `LORESUB.PAS:986 wantenter` / `:999 wantexit` 확인을 통과한 뒤 호출된다.
  void enterPortal(PortalInfo? portal, int tx, int ty) {
    if (portal != null) {
      loadMapById(
        portal.targetMapId,
        startX: portal.targetX,
        startY: portal.targetY,
      );
      onLog?.call('${portal.name}에 진입했습니다.');
    } else {
      if (currentMapName.startsWith('TOWN')) {
        loadMapById(1, startX: 20, startY: 12);
        onLog?.call('성문을 나와 광활한 LORE 대륙 필드(GROUND1)로 나섰습니다.');
      } else {
        loadMapById(6, startX: 51, startY: 95);
        onLog?.call('성문 안으로 들어서 CASTLE LORE 성내 마을로 진입했습니다.');
      }
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

    // 현재 맵 카테고리에 맞는 타일 폰트 선택
    final mapCat = LoreWorldManager.mapRegistry[currentMapId]?.category;
    BgiFontDecoder? activeTileFont;
    switch (mapCat) {
      case MapCategory.town:
        activeTileFont = townFont;
        break;
      case MapCategory.ground:
        activeTileFont = groundFont;
        break;
      case MapCategory.den:
        activeTileFont = denFont ?? townFont;
        break;
      case MapCategory.keep:
        activeTileFont = keepFont ?? groundFont;
        break;
      default:
        activeTileFont = townFont;
    }

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
        if (activeTileFont != null &&
            tileVal >= 0 &&
            tileVal < activeTileFont.totalSprites) {
          activeTileFont.renderSprite(
            canvas,
            tileVal,
            rect,
            opaqueBackground: true,
          );
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

import 'dart:async';
import 'dart:math';

import '../logic/lore_encounter_logic.dart';
import '../logic/lore_ent_procedures.dart';
import '../logic/lore_field_session.dart';
import '../logic/lore_main_procedures.dart';
import '../logic/lore_tile_protocol.dart';
import '../logic/lore_talk_dispatcher.dart';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/retro_theme.dart';
import '../data/lore_script.dart';
import '../logic/lore_join.dart';
import '../models/party_member.dart';
import '../services/audio_manager.dart';
import 'lore_map_manager.dart';
import 'lore_world_manager.dart';
import 'lore_dialogue_manager.dart';
import 'bgi_font_decoder.dart';
import 'sprite_sheet.dart';

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
  bool _map26ArrowFacing = false;

  /// Explicit source cutscene face assignments replace the arrow face offset.
  void applySourceFace(int face) {
    RangeError.checkValueInInterval(face, 4, 7, 'field face');
    playerDirection = face - 4;
    _map26ArrowFacing = false;
  }

  /// `LOREMAIN.Main`: map 26 adds a second field-face offset after arrows.
  int get playerSpriteIndex => currentMapName.startsWith('TOWN')
      ? playerDirection
      : playerDirection + (currentMapId == 26 && _map26ArrowFacing ? 8 : 4);

  /// 원작 `scroll(FALSE)` 연출용 임시 시야 중심 (null이면 파티 위치).
  ///
  /// 원작은 Ancient Evil 안내처럼 다른 장소를 잠시 보여준 뒤 파티로 돌아온다.
  int? peekX;
  int? peekY;
  (int x, int y)? chamberEntryFrame;
  int? chamberDescentRow;

  void showChamberEntryFrame(int x, int y) {
    chamberEntryFrame = (x, y);
  }

  void clearChamberEntryFrame() {
    chamberEntryFrame = null;
  }

  void showChamberDescentRow(int row) {
    chamberDescentRow = row;
  }

  void clearChamberDescentRow() {
    chamberDescentRow = null;
  }

  /// 현재 뷰포트가 바라보는 좌표(연출 중이면 연출 대상).
  int get viewCenterX => peekX ?? playerX;
  int get viewCenterY => peekY ?? playerY;

  /// 연출 중인지(플레이어 스프라이트를 감출지) 여부.
  bool get isPeeking => peekX != null && peekY != null;

  /// 원작 `scroll(FALSE)`: 시야를 (x, y)로 옮긴다(파티는 이동하지 않는다).
  void peekAt(int x, int y) {
    peekX = x;
    peekY = y;
  }

  /// 원작 `scroll(TRUE)`: 시야를 파티 위치로 되돌린다.
  void clearPeek() {
    peekX = null;
    peekY = null;
  }

  final void Function(String message)? onLog;
  final void Function()? onEncounter;
  final int Function()? encounterFrequencyProvider;
  final void Function(String npcName, String dialogue)? onNpcTalk;
  final void Function(int facilityType)? onFacilityEntered;
  final void Function(int x, int y)? onPositionChanged;
  final void Function(TileCategory category)? onHazardTile;
  final void Function()? onPoisonTick;
  final void Function()? onMindReadTick;
  final void Function()? onMoveMode;

  /// true이면 좌표 이벤트가 걸음을 처리했으므로 일반 무작위 전투를 건너뛴다.
  final bool Function()? onStepTaken;

  /// 원작 `join(num, partynum)`으로 동료가 합류할 때 호출된다.
  final void Function(PendingRecruit recruit)? onRecruitRequested;

  /// 좌표 대화의 조건 분기(예: Spica 영입 조건)에 필요한 파티 상태 제공자.
  final List<PartyMember> Function()? partyProvider;

  /// 원작 `party.etc[5]`(독심술 사용 가능 횟수) 제공자.
  final int Function()? mindReadCountProvider;

  /// JSON 스크립트 실행에 필요한 상황(파티/플래그/독심술) 제공자.
  final ScriptContext Function()? scriptContextProvider;
  final LoreScriptEngine? scriptEngine;

  /// JSON 스크립트(talk 트리거)가 매칭되었을 때 호출된다.
  /// NPC 대화 스크립트 결과 + 대화 상대(앞 칸) 좌표.
  ///
  /// 원작 `talkmode`의 `map[x+x1,y+y1] := 값`(유골이 재로 변하는 연출)을
  /// 포트에서도 같은 칸에 적용하기 위해 좌표를 함께 넘긴다.
  final void Function(ScriptRun run, int tx, int ty)? onScriptTalk;

  /// 성문/동굴 입구 앞에 섰을 때 호출된다 (원작 `wantenter`/`wantexit`).
  /// 확인 대화상자에서 승인하면 화면단이 [enterPortal]을 호출한다.
  final void Function(PortalInfo portal, int tx, int ty)? onPortalRequested;

  final bool Function()? canWalkOnWater;
  final int Function()? waterWalkStepsProvider;
  final void Function(int steps)? onWaterWalkStepsChanged;
  final Random _random;
  final List<int>? initialMapTiles;

  LoreGame({
    int initialMapId = 6,
    int initialPlayerX = 51,
    int initialPlayerY = 31,
    this.onLog,
    this.onEncounter,
    this.encounterFrequencyProvider,
    this.onNpcTalk,
    this.onFacilityEntered,
    this.onPositionChanged,
    this.onHazardTile,
    this.onPoisonTick,
    this.onMindReadTick,
    this.onMoveMode,
    this.onStepTaken,
    this.onRecruitRequested,
    this.partyProvider,
    this.mindReadCountProvider,
    this.scriptContextProvider,
    this.scriptEngine,
    this.onScriptTalk,
    this.onPortalRequested,
    this.canWalkOnWater,
    this.waterWalkStepsProvider,
    this.onWaterWalkStepsChanged,
    this.initialMapTiles,
    Random? random,
  }) : currentMapId = initialMapId,
       playerX = initialPlayerX,
       playerY = initialPlayerY,
       _random = random ?? Random();

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
    await loadMapById(
      currentMapId,
      startX: playerX,
      startY: playerY,
      mapTiles: initialMapTiles,
    );
  }

  Future<void> loadMapById(
    int mapId, {
    int? startX,
    int? startY,
    List<int>? mapTiles,
  }) async {
    final info = LoreWorldManager.mapRegistry[mapId];
    if (info == null) return;
    currentMapId = mapId;
    currentMapName = info.fileName;
    _map26ArrowFacing = false;
    try {
      currentMap = await LoreMapData.loadFromAsset(
        info.fileName,
        category: info.category.name,
      );
      if (mapTiles != null) currentMap!.applyTileSnapshot(mapTiles);
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
    if (currentMapId == 26 && (dx != 0 || dy != 0)) {
      _map26ArrowFacing = true;
    }
    final targetX = playerX + dx;
    final targetY = playerY + dy;
    final map = currentMap;
    if (map == null) return false;
    final targetAction = map.actionForTile(map.getTile(targetX, targetY));
    final portal = targetAction == LoreTileAction.enter
        ? LoreEntProcedures.entranceAt(currentMapId, targetX, targetY)
        : LoreWorldManager.instance.findPortal(currentMapId, targetX, targetY);
    final transition = LoreFieldSession.move(
      map: map,
      x: playerX,
      y: playerY,
      direction: playerDirection,
      dx: dx,
      dy: dy,
      canWalkOnWater: waterWalkStepsProvider != null
          ? waterWalkStepsProvider!() > 0
          : canWalkOnWater?.call() == true,
      portal: portal,
    );
    playerDirection = transition.direction;
    var specialEventHandled = false;
    for (final effect in transition.effects) {
      switch (effect.kind) {
        case LoreFieldEffectKind.boundary:
          clearPeek();
          onLog?.call('더 이상 나아갈 수 없는 경계 지역입니다.');
        case LoreFieldEffectKind.wall:
          clearPeek();
          onLog?.call('단단한 성벽과 바위가 가로막아 지나갈 수 없습니다.');
        case LoreFieldEffectKind.waterBlocked:
          _enterWater();
          onLog?.call('깊은 물속은 배나 [물위를 걸음] 마법 없이는 건널 수 없습니다!');
        case LoreFieldEffectKind.talk:
          clearPeek();
          _handleNpcInteraction(targetX, targetY);
        case LoreFieldEffectKind.portalRequest:
          clearPeek();
          if (onPortalRequested != null) {
            onPortalRequested!(transition.portal!, targetX, targetY);
          } else {
            unawaited(enterPortal(transition.portal!, targetX, targetY));
          }
        case LoreFieldEffectKind.entranceNoMatch:
          clearPeek();
        case LoreFieldEffectKind.sign:
          clearPeek();
          _handleSign(targetX, targetY);
        case LoreFieldEffectKind.positionChanged:
          playerX = transition.x;
          playerY = transition.y;
          onPositionChanged?.call(playerX, playerY);
        case LoreFieldEffectKind.poisonTick:
          onPoisonTick?.call();
        case LoreFieldEffectKind.mindReadTick:
          onMindReadTick?.call();
        case LoreFieldEffectKind.moveMode:
          if (onMoveMode != null) {
            onMoveMode!();
          } else {
            // Compatibility adapter for callers not yet using the procedure.
            onPoisonTick?.call();
            onMindReadTick?.call();
            specialEventHandled = onStepTaken?.call() ?? false;
            if (!specialEventHandled &&
                LoreEncounterLogic.shouldEncounter(
                  currentMapId,
                  TileCategory.walkable,
                  _random,
                  frequency: encounterFrequencyProvider?.call() ?? 2,
                )) {
              onEncounter?.call();
            }
          }
        case LoreFieldEffectKind.hazard:
          if (effect.category == TileCategory.water) {
            _enterWater();
          } else {
            onHazardTile?.call(effect.category!);
          }
        case LoreFieldEffectKind.step:
          specialEventHandled = onStepTaken?.call() ?? false;
        case LoreFieldEffectKind.encounterCheck:
          // Transitional path for field effects not yet moved into a procedure.
          if (!specialEventHandled &&
              LoreEncounterLogic.shouldEncounter(
                currentMapId,
                effect.category!,
                _random,
                frequency: encounterFrequencyProvider?.call() ?? 2,
              )) {
            onEncounter?.call();
          }
      }
    }
    return transition.moved ||
        (transition.portal != null &&
            onPortalRequested == null &&
            transition.effects.any(
              (e) => e.kind == LoreFieldEffectKind.portalRequest,
            ));
  }

  void _enterWater() {
    LoreMainProcedures.enterWater(
      waterWalkSteps: () =>
          waterWalkStepsProvider?.call() ??
          (canWalkOnWater?.call() == true ? 1 : 0),
      setWaterWalkSteps: (steps) {
        if (onWaterWalkStepsChanged != null) {
          onWaterWalkStepsChanged!(steps);
        } else {
          onHazardTile?.call(TileCategory.water);
        }
      },
      scrollToParty: clearPeek,
      encounterFrequency: encounterFrequencyProvider?.call() ?? 2,
      random: _random.nextInt,
      encounterEnemy: () {
        if (LoreEncounterLogic.pools.containsKey(currentMapId)) {
          onEncounter?.call();
        }
      },
      // LoreFieldSession has not committed movement on a blocked water tile.
      restorePosition: () {},
    );
  }

  void _handleSign(int tx, int ty) {
    LoreEntProcedures.sign(
      mapId: currentMapId,
      x: tx,
      y: ty,
      messageFor: LoreWorldManager.instance.getSignMessage,
      display: (message) => onLog?.call(message),
      setTile: (x, y, tile) {
        final map = currentMap;
        if (map == null || x > map.xmax || y > map.ymax) return;
        map.setTile(x, y, tile);
      },
    );
  }

  void _handleNpcInteraction(int tx, int ty) {
    final selected = LoreTalkDispatcher.resolve(
      mapId: currentMapId,
      x: tx,
      y: ty,
      heroName: 'Hero',
      context: scriptContextProvider?.call(),
      party: partyProvider?.call(),
      mindReadCount: mindReadCountProvider?.call() ?? 0,
      world: LoreWorldManager.instance,
      scripts: scriptEngine ?? LoreScriptEngine.instance,
      dialogues: LoreDialogueManager.instance,
    );
    switch (selected.source) {
      case LoreTalkSource.facility:
        onFacilityEntered?.call(selected.facility!);
      case LoreTalkSource.script:
        onScriptTalk?.call(selected.script!, tx, ty);
      case LoreTalkSource.dialogue:
        onLog?.call(selected.dialogue!);
        _flushPendingRecruits();
      case LoreTalkSource.none:
        // LORETALK.PAS talkmode prints nothing for a cell it has no case for.
        break;
    }
  }

  /// 원작 `join(num, partynum)` 대기열을 실제 일행 합류로 전환한다.
  void _flushPendingRecruits() {
    for (final recruit in LoreDialogueManager.instance.takePendingRecruits()) {
      onRecruitRequested?.call(recruit);
    }
  }

  /// 성문/동굴 입구 진입 처리.
  /// 원작 `LORESUB.PAS:986 wantenter` / `:999 wantexit` 확인을 통과한 뒤 호출된다.
  Future<void> enterPortal(
    PortalInfo portal,
    int tx,
    int ty, {
    bool deferPostLoadEffects = false,
  }) async {
    final fromMap = currentMapId;
    await loadMapById(
      portal.targetMapId,
      startX: portal.targetX,
      startY: portal.targetY,
    );
    LoreEntProcedures.afterMapLoadBeforeScripts(
      fromMap: fromMap,
      toMap: currentMapId,
      setDirection: (direction) => playerDirection = direction,
    );
    if (!deferPostLoadEffects) finishEntrance();
    onLog?.call('${portal.name}에 진입했습니다.');
  }

  void finishEntrance() {
    LoreEntProcedures.finishEntrance(clearPeek);
  }

  void applyEntrancePostLoadTiles({
    required int fromMap,
    required Set<String> partyNames,
    required Set<String> flags,
    required Map<String, int> questSteps,
  }) {
    final map = currentMap;
    if (map == null) return;
    LoreEntProcedures.afterMapLoadTiles(
      fromMap: fromMap,
      toMap: currentMapId,
      partyNames: partyNames,
      flags: flags,
      questSteps: questSteps,
      setTile: (x, y, tile) {
        if (x < 1 || y < 1 || x > map.xmax || y > map.ymax) return;
        map.setTile(x, y, tile);
      },
    );
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (currentMap == null) return;

    // Scale the original 11x11 view uniformly; map coordinates and tile
    // identity remain unchanged. Restore even on cutscene early returns.
    final mapWidth = viewTilesX * tileSize;
    final mapHeight = viewTilesY * tileSize;
    final scale = min(size.x / mapWidth, size.y / mapHeight);
    if (scale <= 0) return;
    canvas.save();
    canvas.translate(
      (size.x - mapWidth * scale) / 2,
      (size.y - mapHeight * scale) / 2,
    );
    canvas.scale(scale);
    try {
      _renderMap(canvas);
    } finally {
      canvas.restore();
    }
  }

  void _renderMap(Canvas canvas) {
    final halfX = viewTilesX ~/ 2;
    final halfY = viewTilesY ~/ 2;

    const offsetX = 0.0;
    const offsetY = 0.0;

    // 현재 맵 카테고리에 맞는 타일 폰트 선택
    final mapCat = LoreWorldManager.mapRegistry[currentMapId]?.category;
    final tileFontName =
        LoreWorldManager.mapRegistry[currentMapId]?.fontName ?? 'TOWN';
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
        final worldX = viewCenterX - halfX + vx;
        final worldY = viewCenterY - halfY + vy;

        final rect = Rect.fromLTWH(
          offsetX + vx * tileSize,
          offsetY + vy * tileSize,
          tileSize,
          tileSize,
        );

        final tileVal = currentMap!.getTile(worldX, worldY);
        final cat = currentMap!.getCategory(tileVal);

        // 1순위: 이미지 파일(PNG) 스프라이트 시트
        final tileSheet = SpriteLibrary.instance.get(tileFontName);
        if (tileSheet != null && tileVal >= 0 && tileVal < tileSheet.count) {
          tileSheet.draw(canvas, tileVal, rect, opaqueBackground: true);
        } else if (activeTileFont != null &&
            tileVal >= 0 &&
            tileVal < activeTileFont.totalSprites) {
          // 2순위: 원작 FNT 픽셀 디코더
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

    if (chamberEntryFrame case final frame?) {
      final rect = Rect.fromLTWH(
        offsetX + (halfX + frame.$1) * tileSize + 2,
        offsetY + (halfY + frame.$2) * tileSize + 2,
        tileSize - 4,
        tileSize - 4,
      );
      final sheet = SpriteLibrary.instance.get('CHARA');
      if (sheet != null && sheet.count > 22) {
        sheet.draw(canvas, 22, rect);
      } else if (charaFont != null) {
        charaFont!.renderSprite(canvas, 22, rect);
      } else {
        canvas.drawCircle(
          rect.center,
          tileSize * 0.3,
          Paint()..color = RetroTheme.lightRed,
        );
      }
      return;
    }

    if (chamberDescentRow case final row?) {
      final rect = Rect.fromLTWH(
        offsetX + halfX * tileSize + 2,
        offsetY + (halfY + 1 + row) * tileSize + 2,
        tileSize - 4,
        tileSize - 4,
      );
      final sheet = SpriteLibrary.instance.get('CHARA');
      if (sheet != null && sheet.count > 5) {
        sheet.draw(canvas, 5, rect);
      } else if (charaFont != null) {
        charaFont!.renderSprite(canvas, 5, rect);
      } else {
        canvas.drawCircle(
          rect.center,
          tileSize * 0.3,
          Paint()..color = RetroTheme.yellow,
        );
      }
      return;
    }

    // 2. 뷰포트 정중앙에 위치한 플레이어 캐릭터 렌더링 (원작 CHARA.FNT 20x20 픽셀 아트)
    //    카메라 연출(원작 scroll(FALSE)) 중에는 파티를 그리지 않는다.
    if (isPeeking) return;

    final centerRect = Rect.fromLTWH(
      offsetX + halfX * tileSize + 2,
      offsetY + halfY * tileSize + 2,
      tileSize - 4,
      tileSize - 4,
    );

    // 원작 LORESUB.PAS 기준 방향 인덱스: 남: 0, 북: 1, 동: 2, 서: 3 (필드 시 +4)
    final face = playerSpriteIndex;

    final charaSheet = SpriteLibrary.instance.get('CHARA');
    if (charaSheet != null && face < charaSheet.count) {
      // 1순위: 이미지 파일(PNG) 스프라이트 시트
      charaSheet.draw(canvas, face, centerRect);
    } else if (charaFont != null) {
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

import 'dart:async';
import 'dart:math';

import '../logic/lore_random.dart';
import '../logic/lore_load_failure.dart';
import '../logic/lore_source_memory.dart';
import '../logic/lore_bgi_fill.dart';

import '../logic/lore_encounter_logic.dart';
import '../logic/lore_ent_procedures.dart';
import '../logic/lore_field_session.dart';
import '../logic/lore_main_procedures.dart';
import '../logic/lore_main_key.dart';
import '../logic/lore_tile_protocol.dart';
import '../logic/lore_talk_dispatcher.dart';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/retro_theme.dart';
import '../data/lore_script.dart';
import '../models/party_member.dart';
import '../services/audio_manager.dart';
import 'lore_map_manager.dart';
import 'lore_world_manager.dart';
import 'lore_dialogue_manager.dart';
import 'bgi_font_decoder.dart';
import '../logic/lore_load_weather.dart';
import '../logic/lore_remains_blink.dart';
import '../logic/lore_special_arrival.dart';
import 'sprite_sheet.dart';

/// 1993년 원작의 실제 100x100 바이너리 맵(TOWN1.MAP, GROUND1.MAP 등)과
/// 원작 CHARA.FNT 스프라이트 렌더링을 지원하는 Flame 2D 엔진
typedef LoreMapLoader = Future<LoreMapData> Function(
  String name, {
  required String category,
});
typedef LoreFontLoader = Future<BgiFontDecoder> Function(String name);

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
  int _playerDirection = 0; // 0: 남, 1: 북, 2: 동, 3: 서
  int? _sourceInputFace;
  int get playerDirection => _playerDirection;
  set playerDirection(int direction) {
    _playerDirection = direction;
    _sourceInputFace = null;
  }

  /// Explicit source cutscene face assignments use the field sprite bank.
  void applySourceFace(int face) {
    RangeError.checkValueInInterval(face, 4, 7, 'field face');
    playerDirection = face - 4;
    _sourceInputFace = null;
  }

  /// LORESUB.PAS:1722-1726/1758-1759 and LOREMAIN.PAS:169-184:
  /// town uses faces 0..3; map 26 adds 4 even though its position is town.
  /// Map identity, rather than the shared asset filename, owns this choice.
  int get playerSpriteIndex =>
      _sourceInputFace ??
      (playerDirection +
          (LoreWorldManager.mapRegistry[currentMapId]?.category ==
                      MapCategory.town &&
                  currentMapId != 26
              ? 0
              : 4));

  /// 원작 `scroll(FALSE)` 연출용 임시 시야 중심 (null이면 파티 위치).
  ///
  /// 원작은 Ancient Evil 안내처럼 다른 장소를 잠시 보여준 뒤 파티로 돌아온다.
  int? peekX;
  int? peekY;
  (int x, int y)? chamberEntryFrame;
  int? chamberDescentRow;
  LoreRemainsFrame? remainsBlinkFrame;
  final specialArrivalDraws = <LoreArrivalOp>[];

  void addSpecialArrivalDraw(LoreArrivalOp op) {
    if (op.kind == 'tile') {
      final map = currentMap!;
      RangeError.checkValueInInterval(op.index, 1, map.xmax, 'map x');
      RangeError.checkValueInInterval(op.operation, 1, map.ymax, 'map y');
      specialArrivalDraws.add(
        LoreArrivalOp(
          'font',
          op.x,
          op.y,
          map.grid[op.operation - 1][op.index - 1],
          0,
        ),
      );
    } else if (op.kind == 'chara' && op.operation == 2) {
      specialArrivalDraws.add(op);
    }
  }

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

  /// 투시(`Extrasense` 1): `font^[0]`(den/keep은 `font^[52]`도)을 0으로 지워 특수
  /// 칸을 검게 보이게 한다.
  bool seeThroughSpecial = false;

  /// 원작 `scroll(FALSE)`: 시야를 (x, y)로 옮긴다(파티는 이동하지 않는다).
  void peekAt(int x, int y) {
    peekX = x;
    peekY = y;
    onSourceScroll?.call();
  }

  /// 원작 `scroll(TRUE)`: 시야를 파티 위치로 되돌린다.
  void clearPeek() {
    peekX = null;
    peekY = null;
    onSourceScroll?.call();
  }

  final void Function(String message)? onLog;
  final void Function(List<(int, String)> lines)? onSign;

  /// Called after every map load (LORESUB `Load` ends with its bounds on
  /// `encounter^`/`maxenemy^`, run on every map change).
  final void Function()? onMapLoaded;
  final void Function(LoreLoadFailure failure)? onLoadFailure;
  final LoreMapLoader? mapLoader;
  LoreLoadFailure? _fatalLoadFailure;
  final void Function()? onEncounter;
  final int Function()? encounterFrequencyProvider;

  final void Function(int facilityType)? onFacilityEntered;
  final void Function(int x, int y)? onPositionChanged;
  final void Function(TileCategory category)? onHazardTile;
  final void Function()? onPoisonTick;
  final void Function()? onMindReadTick;
  final void Function()? onMoveMode;
  final void Function()? onSourceScroll;

  /// true이면 좌표 이벤트가 걸음을 처리했으므로 일반 무작위 전투를 건너뛴다.
  final bool Function()? onStepTaken;

  /// The party (the source's `player[1..6]`), for the screen and the tests.
  final List<PartyMember> Function()? partyProvider;
  final LoreScrollState sourceScroll;

  /// JSON 스크립트 실행에 필요한 상황(파티/플래그/독심술) 제공자.
  final ScriptContext Function()? scriptContextProvider;
  final LoreScriptEngine? scriptEngine;

  /// JSON 스크립트(talk 트리거)가 매칭되었을 때 호출된다.
  /// NPC 대화 스크립트 결과 + 대화 상대(앞 칸) 좌표.
  ///
  /// 원작 `talkmode`의 `map[x+x1,y+y1] := 값`(유골이 재로 변하는 연출)을
  /// 포트에서도 같은 칸에 적용하기 위해 좌표를 함께 넘긴다.
  final void Function(LoreTalkProcedure procedure, int x, int y)?
  onTalkProcedure;

  /// 성문/동굴 입구 앞에 섰을 때 호출된다 (원작 `wantenter`/`wantexit`).
  /// 확인 대화상자에서 승인하면 화면단이 [enterPortal]을 호출한다.
  final void Function(PortalInfo portal, int tx, int ty)? onPortalRequested;

  final bool Function()? canWalkOnWater;
  final int Function()? waterWalkStepsProvider;
  final void Function(int steps)? onWaterWalkStepsChanged;
  final Random _random;
  final List<int>? initialMapTiles;
  final LoreFontLoader? fontLoader;
  final int? initialMapWidth;
  final int? initialMapHeight;
  final String initialSnapshotName;

  LoreGame({
    int initialMapId = 6,
    int initialPlayerX = 51,
    int initialPlayerY = 31,
    this.onLog,
    this.onSign,
    this.onMapLoaded,
    this.onLoadFailure,
    this.mapLoader,
    this.onEncounter,
    this.encounterFrequencyProvider,
    this.onFacilityEntered,
    this.onPositionChanged,
    this.onHazardTile,
    this.onPoisonTick,
    this.onMindReadTick,
    this.onMoveMode,
    this.onSourceScroll,
    this.partyProvider,
    this.onStepTaken,
    this.scriptContextProvider,
    this.scriptEngine,
    this.onTalkProcedure,
    this.onPortalRequested,
    this.canWalkOnWater,
    this.waterWalkStepsProvider,
    this.onWaterWalkStepsChanged,
    this.initialMapTiles,
    this.fontLoader,
    this.initialMapWidth,
    this.initialMapHeight,
    this.initialSnapshotName = 'save.map',
    Random? random,
    LoreScrollState? sourceScroll,
  }) : currentMapId = LorePascal.byte(initialMapId),
       playerX = initialPlayerX,
       playerY = initialPlayerY,
       _random = random ?? LoreRandom.fromClock(),
       sourceScroll = sourceScroll ?? LoreScrollState();

  @override
  Color backgroundColor() => RetroTheme.viewportBg;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      charaFont = await _readSourceFont('CHARA');
    } catch (e) {
      await _failLoad(LoreLoadFailure('chara.fnt', cause: e));
      return;
    }
    await loadMapById(
      currentMapId,
      startX: playerX,
      startY: playerY,
      mapTiles: initialMapTiles,
      mapWidth: initialMapWidth,
      mapHeight: initialMapHeight,
      snapshotName: initialSnapshotName,
    );
  }

  Future<BgiFontDecoder> _readSourceFont(String name) async {
    final font = await (fontLoader ?? BgiFontDecoder.loadFromAsset)(name);
    const sourceBytes = 56 * BgiFontDecoder.spriteBytes;
    if (font.data.length < sourceBytes) {
      throw FormatException('$name: truncated source font[0..55]');
    }
    // Pascal Read consumes one complete record, ignoring trailing file bytes.
    return font.data.length == sourceBytes
        ? font
        : BgiFontDecoder(Uint8List.sublistView(font.data, 0, sourceBytes));
  }

  Future<void> loadMapById(
    int mapId, {
    int? startX,
    int? startY,
    List<int>? mapTiles,
    int? mapWidth,
    int? mapHeight,
    String snapshotName = 'save.map',
  }) async {
    if (_fatalLoadFailure case final failure?) {
      await _failLoad(failure);
      return;
    }
    mapId = LorePascal.byte(mapId);
    currentMapId = mapId;
    final info = LoreWorldManager.mapRegistry[mapId];
    if (info == null) {
      currentMapName = '';
      await _failLoad(const LoreLoadFailure('.map'));
      return;
    }
    currentMapName = info.fileName;
    late final LoreMapData loaded;
    final hasHeader = mapWidth != null || mapHeight != null;
    try {
      loaded = hasHeader
          ? LoreMapData.fromSnapshot(
              info.fileName,
              width: mapWidth,
              height: mapHeight,
              tiles: mapTiles ?? const [],
              category: info.category.name,
            )
          : await (mapLoader ?? LoreMapData.loadFromAsset)(
              info.fileName,
              category: info.category.name,
            );
    } catch (e) {
      await _failLoad(
        LoreLoadFailure(
          hasHeader ? snapshotName : '${info.fileName.toLowerCase()}.map',
          cause: e,
        ),
      );
      return;
    }
    if (_fatalLoadFailure case final failure?) {
      await _failLoad(failure);
      return;
    }
    late final BgiFontDecoder tileFont;
    try {
      // Source Load rereads only the selected region font, including warm Loads.
      tileFont = await _readSourceFont(info.fontName);
    } catch (e) {
      await _failLoad(
        LoreLoadFailure('${info.fontName.toLowerCase()}.fnt', cause: e),
      );
      return;
    }
    if (_fatalLoadFailure case final failure?) {
      await _failLoad(failure);
      return;
    }
    switch (info.fontName) {
      case 'GROUND':
        groundFont = tileFont;
      case 'DEN':
        denFont = tileFont;
      case 'KEEP':
        keepFont = tileFont;
      default:
        townFont = tileFont;
    }
    currentMap = loaded;
    if (!hasHeader && mapTiles != null) loaded.applyTileSnapshot(mapTiles);
    if (startX != null && startY != null) {
      playerX = startX;
      playerY = startY;
    }
    // LORESUB.PAS:1758: every Load resets face from the restored/entry y.
    playerDirection = loaded.ymax ~/ 2 > playerY ? 0 : 1;
    _sourceInputFace = null;
    AudioManager.instance.playBgm(info.bgmTrack);
    onMapLoaded?.call();
    onSourceScroll?.call();
  }

  /// A party/player logical storage failure ends the same Load as MAP/FNT IO.
  Future<void> haltLoad(LoreLoadFailure failure) => _failLoad(failure);

  Future<void> _failLoad(LoreLoadFailure failure) async {
    final firstFailure = _fatalLoadFailure == null;
    _fatalLoadFailure ??= failure;
    if (onLoadFailure case final halt?) {
      if (firstFailure) halt(_fatalLoadFailure!);
      // Original Halt never returns to Load, a portal or battle continuation.
      await Completer<void>().future;
    } else {
      throw _fatalLoadFailure!;
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
  /// The map whose `if position = ...` block LOREMAIN `Main` is running for
  /// the latest move; later blocks see the map loaded during it.
  int dispatchStartMapId = 0;

  bool tryMove(int dx, int dy) {
    if (_fatalLoadFailure != null) return false;
    if (dx != 0 || dy != 0) _sourceInputFace = null;
    dispatchStartMapId = currentMapId;
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
        case LoreFieldEffectKind.wall:
          clearPeek();
        case LoreFieldEffectKind.waterBlocked:
          _enterWater();
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
      encounterEnemy: () => onEncounter?.call(),
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
      display: (message) {
        if (onSign case final display?) {
          display(LoreWorldManager.instance.getSignLines(currentMapId, tx, ty));
        } else {
          onLog?.call(message);
        }
      },
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
      context: scriptContextProvider?.call(),
      world: LoreWorldManager.instance,
      scripts: scriptEngine ?? LoreScriptEngine.instance,
    );
    switch (selected.source) {
      case LoreTalkSource.facility:
        onFacilityEntered?.call(selected.facility!);
      case LoreTalkSource.procedure:
        onTalkProcedure?.call(selected.procedure!, tx, ty);
      case LoreTalkSource.none:
        // LORETALK.PAS talkmode prints nothing for a cell it has no case for.
        break;
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
  }

  void finishEntrance() {
    LoreEntProcedures.finishEntrance(clearPeek);
  }

  void applyEntrancePostLoadTiles({
    required int fromMap,
    required Set<String> partyNames,
    required Set<String> flags,
    required Map<String, int> questSteps,
    Map<int, int> sourceEtc = const {},
  }) {
    final map = currentMap;
    if (map == null) return;
    LoreEntProcedures.afterMapLoadTiles(
      fromMap: fromMap,
      toMap: currentMapId,
      partyNames: partyNames,
      flags: flags,
      questSteps: questSteps,
      sourceEtc: sourceEtc,
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

  /// `bar(20,20,200,200)` in color 0 and `HPrintXY(94,96,'어둠')` in color 8.
  void _renderDarkness(Canvas canvas, double offsetX, double offsetY) {
    final width = viewTilesX * tileSize;
    final height = viewTilesY * tileSize;
    canvas.drawRect(
      Rect.fromLTWH(offsetX, offsetY, width, height),
      Paint()..color = RetroTheme.ega(0),
    );
    final text = TextPainter(
      text: TextSpan(
        text: darknessText,
        style: RetroTheme.dosFont.copyWith(
          color: RetroTheme.ega(8),
          fontSize: tileSize * 0.6,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(
      canvas,
      Offset(
        offsetX + (width - text.width) / 2,
        offsetY + (height - text.height) / 2,
      ),
    );
  }

  /// LORESUB `Scroll`: `HPrintXY(94,96,'어둠')`.
  static const String darknessText = '어둠';

  /// Shared by the renderer and Load resource verification, not a test-only path.
  String get selectedTileFontName =>
      LoreWorldManager.mapRegistry[currentMapId]?.fontName ?? 'TOWN';

  BgiFontDecoder? get selectedTileFont => switch (selectedTileFontName) {
    'GROUND' => groundFont,
    'DEN' => denFont ?? townFont,
    'KEEP' => keepFont ?? groundFont,
    _ => townFont,
  };

  void _renderMap(Canvas canvas) {
    final halfX = viewTilesX ~/ 2;
    final halfY = viewTilesY ~/ 2;

    const offsetX = 0.0;
    const offsetY = 0.0;

    // 현재 맵 카테고리에 맞는 타일 폰트 선택
    final mapCat = LoreWorldManager.mapRegistry[currentMapId]?.category;
    final tileFontName = selectedTileFontName;
    final activeTileFont = selectedTileFont;

    // LORESUB `Scroll`/`AuxScroll`: in a den without the magic torch
    // (`party.etc[1] = 0`) the view is a black box with '어둠' and neither the
    // map nor the party is drawn (also while peeking).
    if (mapCat == MapCategory.den &&
        LoreDialogueManager.instance.partyEtc.read(1) == 0) {
      _renderDarkness(canvas, offsetX, offsetY);
      return;
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

        if (seeThroughSpecial &&
            (tileVal == 0 ||
                (tileVal == 52 &&
                    (mapCat == MapCategory.den ||
                        mapCat == MapCategory.keep)))) {
          canvas.drawRect(rect, Paint()..color = const Color(0xFF000000));
          continue;
        }

        // 1순위: 이미지 파일(PNG) 스프라이트 시트. 특수 칸(타일 0)은 `Load`가
        // `font^[0]` 에 복사한 맵별 기본 글꼴 칸으로 그린다(`ReturnDefaultFont`).
        final tileSheet = SpriteLibrary.instance.get(tileFontName);
        final drawIndex = tileVal == 0
            ? LoreTileProtocol.defaultFontSlot(currentMapId)
            : tileVal;
        if (sourceScroll.putStyle == 2 && activeTileFont != null) {
          // Scroll fills the viewport once, then ORs source-indexed tiles.
          // Pattern phase is anchored to DOS pixels rather than each tile.
          activeTileFont.renderOrSprite(
            canvas,
            drawIndex,
            rect,
            fillForm: sourceScroll.form,
            fillColor: sourceScroll.color,
            sourceX: 100 + (vx - halfX) * 20,
            sourceY: 100 + (vy - halfY) * 20,
          );
        } else if (tileSheet != null &&
            drawIndex >= 0 &&
            drawIndex < tileSheet.count) {
          tileSheet.draw(canvas, drawIndex, rect, opaqueBackground: true);
        } else if (activeTileFont != null &&
            drawIndex >= 0 &&
            drawIndex < activeTileFont.totalSprites) {
          // 2순위: 원작 FNT 픽셀 디코더
          activeTileFont.renderSprite(
            canvas,
            drawIndex,
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

    if (remainsBlinkFrame case final frame?) {
      final rect = Rect.fromLTWH(
        offsetX + (halfX + (frame.x - 100) / 20) * tileSize,
        offsetY + (halfY + (frame.y - 100) / 20) * tileSize,
        tileSize,
        tileSize,
      );
      final sheet = SpriteLibrary.instance.get(tileFontName);
      if (sheet != null && frame.tile < sheet.count) {
        sheet.draw(canvas, frame.tile, rect, opaqueBackground: true);
      } else if (activeTileFont != null) {
        activeTileFont.renderSprite(
          canvas,
          frame.tile,
          rect,
          opaqueBackground: true,
        );
      }
    }

    for (final draw in specialArrivalDraws) {
      final rect = Rect.fromLTWH(
        offsetX + (halfX + (draw.x - 100) / 20) * tileSize,
        offsetY + (halfY + (draw.y - 100) / 20) * tileSize,
        tileSize,
        tileSize,
      );
      final isTile = draw.kind == 'font';
      final index = isTile && draw.index == 0
          ? LoreTileProtocol.defaultFontSlot(currentMapId)
          : draw.index;
      final sheet = SpriteLibrary.instance.get(isTile ? tileFontName : 'CHARA');
      final font = isTile ? activeTileFont : charaFont;
      if (!isTile && charaFont != null) {
        charaFont!.renderMaskedSprite(canvas, index, rect);
      } else if (sheet != null) {
        sheet.draw(canvas, index, rect, opaqueBackground: isTile);
      } else if (font != null) {
        font.renderSprite(canvas, index, rect, opaqueBackground: isTile);
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
    RangeError.checkValueInInterval(face, 0, 55, 'source CHARA face');

    final charaSheet = SpriteLibrary.instance.get('CHARA');
    if (charaFont != null) {
      final sourceRect = Rect.fromLTWH(
        offsetX + halfX * tileSize,
        offsetY + halfY * tileSize,
        tileSize,
        tileSize,
      );
      charaFont!.renderMaskedSprite(
        canvas,
        face,
        sourceRect,
        backgroundPixel: (x, y) {
          final tile = currentMap!.getTile(playerX, playerY);
          if (seeThroughSpecial &&
              (tile == 0 ||
                  (tile == 52 &&
                      (mapCat == MapCategory.den ||
                          mapCat == MapCategory.keep)))) {
            return 0;
          }
          final index = tile == 0
              ? LoreTileProtocol.defaultFontSlot(currentMapId)
              : tile;
          final value = activeTileFont!.decodedSprites[index][y][x];
          return sourceScroll.putStyle == 2
              ? LoreBgiFill.orPixel(
                  value,
                  sourceScroll.form,
                  sourceScroll.color,
                  100 + x,
                  100 + y,
                )
              : value;
        },
      );
    } else if (charaSheet != null && face < charaSheet.count) {
      // 1순위: 이미지 파일(PNG) 스프라이트 시트
      charaSheet.draw(canvas, face, centerRect);
    } else if (charaFont != null) {
      charaFont!.renderMaskedSprite(canvas, face, centerRect);
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
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;
    final scans = <LogicalKeyboardKey, int>{
      LogicalKeyboardKey.arrowUp: 72,
      LogicalKeyboardKey.keyW: 72,
      LogicalKeyboardKey.arrowDown: 80,
      LogicalKeyboardKey.keyS: 80,
      LogicalKeyboardKey.arrowLeft: 75,
      LogicalKeyboardKey.keyA: 75,
      LogicalKeyboardKey.arrowRight: 77,
      LogicalKeyboardKey.keyD: 77,
      LogicalKeyboardKey.home: 71,
      LogicalKeyboardKey.end: 79,
      LogicalKeyboardKey.pageUp: 73,
      LogicalKeyboardKey.pageDown: 81,
      LogicalKeyboardKey.insert: 82,
      LogicalKeyboardKey.delete: 83,
      LogicalKeyboardKey.f1: 59,
      LogicalKeyboardKey.f2: 60,
      LogicalKeyboardKey.f3: 61,
      LogicalKeyboardKey.f4: 62,
      LogicalKeyboardKey.f5: 63,
      LogicalKeyboardKey.f6: 64,
      LogicalKeyboardKey.f7: 65,
      LogicalKeyboardKey.f8: 66,
      LogicalKeyboardKey.f9: 67,
      LogicalKeyboardKey.f10: 68,
      LogicalKeyboardKey.f11: 133,
      LogicalKeyboardKey.f12: 134,
    };
    final scan = scans[event.logicalKey];
    if (scan != null) handleSourceScanByte(scan);
  }

  /// An atomic modern extended event replaces DOS's #0 followed by ReadKey.
  /// Main adjusts map26's face even when an unsupported scan leaves ok=false.
  void handleSourceScanByte(int scan) {
    if (_fatalLoadFailure != null) return;
    final result = LoreMainKey.extended(
      scan,
      face: playerSpriteIndex,
      town: currentMap?.category == 'town',
      mapId: currentMapId,
    );
    if (result.ok) {
      tryMove(result.dx, result.dy);
    } else {
      _sourceInputFace = result.face;
    }
  }
}

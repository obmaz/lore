import '../logic/lore_sign.dart';

import 'package:flutter/services.dart' show AssetBundle;

import '../services/audio_manager.dart';

enum MapCategory { ground, town, den, keep }

class MapInfo {
  final int mapId;
  final String fileName;
  final String title;
  final MapCategory category;
  final BgmTrack bgmTrack;
  final String fontName;

  const MapInfo({
    required this.mapId,
    required this.fileName,
    required this.title,
    required this.category,
    required this.bgmTrack,
    required this.fontName,
  });
}

class PortalInfo {
  final int targetMapId;
  final int targetX;
  final int targetY;
  final String name;

  /// 진입 **전에** 실행할 스크립트 id (원작 LOREENT.PAS 의 수문장 전투/판정).
  final String? scriptId;

  const PortalInfo({
    required this.targetMapId,
    required this.targetX,
    required this.targetY,
    required this.name,
    this.scriptId,
  });
}

/// 1993년 원작 LORESUB.PAS 및 LOREENT.PAS 기반 27개 전체 맵 및 포털/표지판 관리자
class LoreWorldManager {
  static final LoreWorldManager instance = LoreWorldManager._internal();
  factory LoreWorldManager() => instance;
  LoreWorldManager._internal();

  /// 1..27 전체 맵 메타데이터 테이블 (LORESUB.PAS line 1677-1746)
  static final Map<int, MapInfo> mapRegistry = {
    1: const MapInfo(
      mapId: 1,
      fileName: 'GROUND1',
      title: 'GROUND 1 (아대륙 필드)',
      category: MapCategory.ground,
      bgmTrack: BgmTrack.ground,
      fontName: 'GROUND',
    ),
    2: const MapInfo(
      mapId: 2,
      fileName: 'GROUND2',
      title: 'GROUND 2 (본대륙 필드)',
      category: MapCategory.ground,
      bgmTrack: BgmTrack.ground,
      fontName: 'GROUND',
    ),
    3: const MapInfo(
      mapId: 3,
      fileName: 'WATER',
      title: 'WATER FIELD (해양 필드)',
      category: MapCategory.ground,
      bgmTrack: BgmTrack.ground,
      fontName: 'GROUND',
    ),
    4: const MapInfo(
      mapId: 4,
      fileName: 'SWAMP',
      title: 'SWAMP FIELD (늪지 필드)',
      category: MapCategory.ground,
      bgmTrack: BgmTrack.ground,
      fontName: 'GROUND',
    ),
    5: const MapInfo(
      mapId: 5,
      fileName: 'LAVA',
      title: 'LAVA FIELD (용암 필드)',
      category: MapCategory.ground,
      bgmTrack: BgmTrack.ground,
      fontName: 'GROUND',
    ),
    6: const MapInfo(
      mapId: 6,
      fileName: 'TOWN1',
      title: 'CASTLE LORE (로어 성내 마을)',
      category: MapCategory.town,
      bgmTrack: BgmTrack.town,
      fontName: 'TOWN',
    ),
    7: const MapInfo(
      mapId: 7,
      fileName: 'TOWN2',
      title: 'LASTDITCH (마지막 보루 마을)',
      category: MapCategory.town,
      bgmTrack: BgmTrack.town,
      fontName: 'TOWN',
    ),
    8: const MapInfo(
      mapId: 8,
      fileName: 'TOWN3',
      title: 'VALIANT PEOPLES (용사의 마을)',
      category: MapCategory.town,
      bgmTrack: BgmTrack.town,
      fontName: 'TOWN',
    ),
    9: const MapInfo(
      mapId: 9,
      fileName: 'TOWN4',
      title: 'GAIA TERRA (대지의 마을)',
      category: MapCategory.town,
      bgmTrack: BgmTrack.town,
      fontName: 'TOWN',
    ),
    10: const MapInfo(
      mapId: 10,
      fileName: 'TOWN5',
      title: 'WATER TOWN (수중 마을)',
      category: MapCategory.town,
      bgmTrack: BgmTrack.town,
      fontName: 'TOWN',
    ),
    11: const MapInfo(
      mapId: 11,
      fileName: 'T_DEN1',
      title: 'T_DEN 1 (시련의 동굴 1)',
      category: MapCategory.den,
      bgmTrack: BgmTrack.den,
      fontName: 'DEN',
    ),
    12: const MapInfo(
      mapId: 12,
      fileName: 'T_DEN2',
      title: 'T_DEN 2 (수수께끼의 동굴 2)',
      category: MapCategory.den,
      bgmTrack: BgmTrack.den,
      fontName: 'DEN',
    ),
    13: const MapInfo(
      mapId: 13,
      fileName: 'DEN4',
      title: 'DEN 4',
      category: MapCategory.den,
      bgmTrack: BgmTrack.den,
      fontName: 'DEN',
    ),
    14: const MapInfo(
      mapId: 14,
      fileName: 'DEN1',
      title: 'MENACE (위협의 동굴)',
      category: MapCategory.den,
      bgmTrack: BgmTrack.den,
      fontName: 'DEN',
    ),
    15: const MapInfo(
      mapId: 15,
      fileName: 'DEN2',
      title: 'QUAKE (지진의 동굴)',
      category: MapCategory.den,
      bgmTrack: BgmTrack.den,
      fontName: 'DEN',
    ),
    16: const MapInfo(
      mapId: 16,
      fileName: 'DEN3',
      title: 'WIVERN (와이번의 동굴)',
      category: MapCategory.den,
      bgmTrack: BgmTrack.den,
      fontName: 'DEN',
    ),
    17: const MapInfo(
      mapId: 17,
      fileName: 'DEN4',
      title: 'NOTICE (경고의 동굴)',
      category: MapCategory.den,
      bgmTrack: BgmTrack.den,
      fontName: 'DEN',
    ),
    18: const MapInfo(
      mapId: 18,
      fileName: 'DEN5',
      title: 'LOCKUP (감옥 동굴)',
      category: MapCategory.den,
      bgmTrack: BgmTrack.den,
      fontName: 'DEN',
    ),
    19: const MapInfo(
      mapId: 19,
      fileName: 'DEN6',
      title: 'DEN 6 (심연의 동굴)',
      category: MapCategory.den,
      bgmTrack: BgmTrack.den,
      fontName: 'DEN',
    ),
    20: const MapInfo(
      mapId: 20,
      fileName: 'DEN7',
      title: 'DEN 7 (봉인의 동굴)',
      category: MapCategory.den,
      bgmTrack: BgmTrack.den,
      fontName: 'DEN',
    ),
    21: const MapInfo(
      mapId: 21,
      fileName: 'KEEP1',
      title: 'SWAMP KEEP (늪의 요새)',
      category: MapCategory.keep,
      bgmTrack: BgmTrack.keep,
      fontName: 'KEEP',
    ),
    22: const MapInfo(
      mapId: 22,
      fileName: 'KEEP2',
      title: 'KEEP 2 (암흑의 성채)',
      category: MapCategory.keep,
      bgmTrack: BgmTrack.keep,
      fontName: 'KEEP',
    ),
    23: const MapInfo(
      mapId: 23,
      fileName: 'KEEP3',
      title: 'DUNGEON OF EVIL (악의 요새)',
      category: MapCategory.keep,
      bgmTrack: BgmTrack.keep,
      fontName: 'KEEP',
    ),
    24: const MapInfo(
      mapId: 24,
      fileName: 'K_DEN1',
      title: 'LAST SHELTER (최후의 피난처)',
      category: MapCategory.town,
      bgmTrack: BgmTrack.town,
      fontName: 'TOWN',
    ),
    25: const MapInfo(
      mapId: 25,
      fileName: 'K_DEN2',
      title: 'K_DEN 2 (악의 심연)',
      category: MapCategory.den,
      bgmTrack: BgmTrack.den,
      fontName: 'DEN',
    ),
    26: const MapInfo(
      mapId: 26,
      fileName: 'K_DEN2',
      title: 'CHAMBER OF NECROMANCER (결전의 방)',
      category: MapCategory.town,
      bgmTrack: BgmTrack.town,
      fontName: 'TOWN',
    ),
    27: const MapInfo(
      mapId: 27,
      fileName: 'PYRAMID1',
      title: 'ANOTHER LORE (또 다른 지식의 성전 피라미드)',
      category: MapCategory.town,
      bgmTrack: BgmTrack.town,
      fontName: 'TOWN',
    ),
  };

  // =========================================================================
  // 원본 절차 기반 좌표 선택
  // =========================================================================

  /// Source rules require no asset loading. Kept async for startup callers.
  Future<void> loadData({AssetBundle? bundle}) async {}
  void resetRulesForTest() {}

  /// 원작 `LORETALK.PAS`가 시설(무기점/병원/훈련소/식료품점)로 진입시키는 좌표.
  ///
  /// 반환값: 1=무기점, 2=병원, 3=훈련소, 4=식료품점 (없으면 null).
  int? findFacility(int currentMapId, int x, int y) {
    for (final f in _builtInFacilities) {
      if (f.matches(currentMapId, x, y)) return f.facility;
    }
    return null;
  }

  /// `wantexit` refusal inside LORESPEC: the y the party is left on, or null
  /// when the exit is not a source specialevent boundary.
  static int? sourceExitRejectY(
    int mapId,
    int y, {
    int x = 0,
  }) => switch (mapId) {
    // LORESPEC.PAS:334-340: a refused wantenter leaves the party on the gate.
    // LORESPEC.PAS:302-304: map 6 refusal.
    6 => y - 1,
    7 when x == 50 => y,
    7 when y == 71 => y - 1,
    8 when x == 50 => y,
    9 when y == 5 => y + 1,
    9 when y == 46 => y - 1,
    13 when y == 96 => y - 1,
    14 when y == 46 => y - 1,
    15 when y == 71 => y - 1,
    16 when y == 36 => y - 1,
    17 when y == 95 => y - 1,
    18 when y == 95 => y - 1,
    19 when y == 46 => y - 1,
    // LORESPEC.PAS:515-521 has no refusal branch: the party stays on y = 46.
    11 when y == 46 => y,
    12 when y == 71 => y - 1,
    8 || 10 when y == 71 => y - 1,
    21 || 22 || 23 || 24 || 25 when y == 46 => y - 1,
    27 => y < 25 ? y + 1 : y - 1,
    _ => null,
  };

  /// LORESPEC.PAS:334/383: map 8 x = 50 and map 9 y = 5 ask `wantenter`.
  static bool sourceAsksEnter(int mapId, int x, int y) =>
      ((mapId == 7 || mapId == 8) && x == 50) || (mapId == 9 && y == 5);

  /// LOREENT.PAS의 월드맵/마을 간 포털 연결 정의 (맵ID, x, y) -> PortalInfo
  PortalInfo? findPortal(int currentMapId, int x, int y) {
    // LORESPEC.PAS:308-326: the gate is tested before the town exit.
    if (currentMapId == 7 && x == 50) {
      return const PortalInfo(
        targetMapId: 8,
        targetX: 50,
        targetY: 10,
        name: 'GROUND GATE',
      );
    }
    if (currentMapId == 7 && y >= 71) {
      return y == 71
          ? const PortalInfo(
              targetMapId: 1,
              targetX: 77,
              targetY: 57,
              name: 'TOWN2 출구',
            )
          : null;
    }
    // LORESPEC.PAS:1368-1374: not a y >= 46 exit.
    if (currentMapId == 19 && y >= 46) {
      return y == 46
          ? const PortalInfo(
              targetMapId: 4,
              targetX: 48,
              targetY: 58,
              name: 'DEN6 출구',
            )
          : null;
    }
    // LORESPEC.PAS:1762-1795, 1818-1839, 1883-1894, 1982-1993 and 1997-2006
    // own the exact map 21..25 exits; any other row of those maps never exits.
    if (currentMapId >= 21 && currentMapId <= 25) {
      if (y == 46) {
        return switch (currentMapId) {
          21 => const PortalInfo(
            targetMapId: 4,
            targetX: 48,
            targetY: 36,
            name: 'SWAMP KEEP 출구',
            scriptId: 'keep1-exit-guard',
          ),
          22 => const PortalInfo(
            targetMapId: 5,
            targetX: 15,
            targetY: 32,
            name: 'KEEP2 출구',
            scriptId: 'keep2-exit-guard',
          ),
          23 => const PortalInfo(
            targetMapId: 5,
            targetX: 34,
            targetY: 15,
            name: 'KEEP3 출구',
          ),
          24 => const PortalInfo(
            targetMapId: 22,
            targetX: 25,
            targetY: 24,
            name: 'LAST SHELTER 출구',
          ),
          _ => const PortalInfo(
            targetMapId: 23,
            targetX: 25,
            targetY: 45,
            name: 'K_DEN2 출구',
          ),
        };
      }
      if (y > 46) return null;
    }
    // LORESPEC.PAS:562-572: map 12 exits only at y = 71.
    if (currentMapId == 12 && y >= 71) {
      if (y > 71) return null;
      return const PortalInfo(
        targetMapId: 8,
        targetX: 39,
        targetY: 7,
        name: 'VALIANT PEOPLES',
      );
    }
    // LORESPEC.PAS:671-680: map 13 exits only at y = 96.
    if (currentMapId == 13 && y >= 96) {
      if (y > 96) return null;
      return const PortalInfo(
        targetMapId: 9,
        targetX: 26,
        targetY: 6,
        name: 'GAIA TERRA',
      );
    }
    // LORESPEC.PAS:1012-1021: map 17 exits only at y = 95.
    if (currentMapId == 17 && y >= 95) {
      if (y > 95) return null;
      return const PortalInfo(
        targetMapId: 3,
        targetX: 23,
        targetY: 63,
        name: 'NOTICE 출구',
      );
    }
    // LORESPEC.PAS:1176-1186: map 18 exits only at y = 95.
    if (currentMapId == 18 && y >= 95) {
      if (y > 95) return null;
      return const PortalInfo(
        targetMapId: 3,
        targetX: 96,
        targetY: 43,
        name: 'LOCKUP 출구',
      );
    }
    // LORESPEC.PAS:968-977: map 16 exits only at y = 36.
    if (currentMapId == 16 && y >= 36) {
      if (y > 36) return null;
      return const PortalInfo(
        targetMapId: 2,
        targetX: 44,
        targetY: 8,
        name: 'WIVERN 출구',
      );
    }
    // LORESPEC.PAS:881-890: map 15 exits only at y = 71.
    if (currentMapId == 15 && y >= 71) {
      if (y > 71) return null;
      return const PortalInfo(
        targetMapId: 2,
        targetX: 82,
        targetY: 48,
        name: 'QUAKE 출구',
      );
    }
    // LORESPEC.PAS:816-825: map 14 exits only at y = 46.
    if (currentMapId == 14 && y >= 46) {
      if (y > 46) return null;
      return const PortalInfo(
        targetMapId: 1,
        targetX: 18,
        targetY: 89,
        name: 'MENACE 출구',
      );
    }
    if (currentMapId == 11 && y >= 46) {
      if (y > 46) return null;
      return const PortalInfo(
        targetMapId: 7,
        targetX: 38,
        targetY: 7,
        name: 'LASTDITCH',
      );
    }
    // LORESPEC.PAS:190-304: on map 6 every special tile other than the
    // chest, prison and armoury cells is the `wantexit` arm.
    if (currentMapId == 6) {
      final event =
          (x == 62 && y == 82) ||
          ((x == 51 || x == 52) && y == 12) ||
          (x == 41 && y == 79);
      if (event) return null;
      return const PortalInfo(
        targetMapId: 1,
        targetX: 20,
        targetY: 12,
        name: 'GROUND FIELD',
        scriptId: 'castle-exit-skeleton',
      );
    }
    // LORESPEC.PAS:383-439: map 9 SWAMP GATE (y = 5) and exit (y = 46).
    if (currentMapId == 9 && (y == 5 || y >= 46)) {
      if (y > 46) return null;
      return y == 5
          ? const PortalInfo(
              targetMapId: 13,
              targetX: 81,
              targetY: 95,
              name: 'SWAMP GATE',
              scriptId: 'portal-9-13-swamp-gate',
            )
          : const PortalInfo(
              targetMapId: 2,
              targetX: 32,
              targetY: 82,
              name: 'GROUND 2',
            );
    }
    // LORESPEC.PAS:332-353 and 444-464: map 8/10 gate and y = 71 exits.
    if (currentMapId == 8 && x == 50) {
      return const PortalInfo(
        targetMapId: 7,
        targetX: 50,
        targetY: 10,
        name: 'GROUND GATE',
      );
    }
    if ((currentMapId == 8 || currentMapId == 10) && y >= 71) {
      if (y > 71) return null;
      return currentMapId == 8
          ? const PortalInfo(
              targetMapId: 2,
              targetX: 19,
              targetY: 27,
              name: 'GROUND 2',
            )
          : const PortalInfo(
              targetMapId: 3,
              targetX: 74,
              targetY: 20,
              name: 'WATER FIELD',
            );
    }
    // LORESPEC.PAS:2202-2212: every specialevent on map 27 is `wantexit`.
    if (currentMapId == 27) {
      return const PortalInfo(
        targetMapId: 1,
        targetX: 20,
        targetY: 8,
        name: 'ANOTHER LORE 출구',
      );
    }
    return _findPortalBuiltIn(currentMapId, x, y);
  }

  PortalInfo? _findPortalBuiltIn(int currentMapId, int x, int y) {
    for (final rule in _builtInPortals) {
      if (!rule.matches(currentMapId, x, y)) continue;
      return PortalInfo(
        targetMapId: rule.targetMap,
        targetX: rule.targetX,
        targetY: rule.targetY,
        name: rule.name,
        scriptId: rule.script,
      );
    }
    return null;
  }

  /// Direct source sign text. Map mutation is owned by LoreEntProcedures.sign.
  List<(int, String)> getSignLines(int mapId, int x, int y) =>
      LoreSign.lines(mapId, x, y);
  String getSignMessage(int mapId, int x, int y) =>
      getSignLines(mapId, x, y).map((l) => l.$2).join('\n');
}

/// Original LOREENT/LORESPEC entrance and exit destinations.
class _BuiltInPortal {
  final int map;
  final int? x;
  final int? y;
  final int? xMin;
  final int? xMax;
  final int? yMin;
  final int? yMax;
  final int targetMap;
  final int targetX;
  final int targetY;
  final String name;
  final String? script;

  const _BuiltInPortal(
    this.map, {
    this.x,
    this.y,
    this.xMin,
    this.xMax,
    this.yMin,
    this.yMax,
    required this.targetMap,
    required this.targetX,
    required this.targetY,
    required this.name,
    this.script,
  });

  bool matches(int m, int tx, int ty) {
    if (map != m) return false;
    if (x != null && x != tx) return false;
    if (y != null && y != ty) return false;
    if (xMin != null && tx < xMin!) return false;
    if (xMax != null && tx > xMax!) return false;
    if (yMin != null && ty < yMin!) return false;
    if (yMax != null && ty > yMax!) return false;
    return true;
  }
}

// ignore: constant_identifier_names
const List<_BuiltInPortal> _builtInPortals = [
  // 원작 LOREENT.PAS(진입) / LORESPEC.PAS(출구) 좌표.
  // Source destination coordinates; JSON is not read by the runtime.
  _BuiltInPortal(
    6,
    yMin: 96,
    targetMap: 1,
    targetX: 20,
    targetY: 12,
    name: 'GROUND FIELD',
    script: 'castle-exit-skeleton',
  ),
  _BuiltInPortal(
    7,
    yMin: 71,
    targetMap: 1,
    targetX: 77,
    targetY: 57,
    name: 'GROUND FIELD',
  ),
  _BuiltInPortal(
    8,
    yMin: 71,
    targetMap: 2,
    targetX: 19,
    targetY: 27,
    name: 'GROUND 2',
  ),
  _BuiltInPortal(
    7,
    x: 50,
    yMin: 9,
    yMax: 10,
    targetMap: 8,
    targetX: 50,
    targetY: 10,
    name: 'GROUND GATE',
  ),
  _BuiltInPortal(
    8,
    x: 50,
    yMin: 9,
    yMax: 10,
    targetMap: 7,
    targetX: 50,
    targetY: 10,
    name: 'GROUND GATE',
  ),
  _BuiltInPortal(
    9,
    xMin: 24,
    xMax: 29,
    y: 5,
    targetMap: 13,
    targetX: 81,
    targetY: 95,
    name: 'SWAMP GATE',
    script: 'portal-9-13-swamp-gate',
  ),
  _BuiltInPortal(
    9,
    yMin: 46,
    targetMap: 2,
    targetX: 32,
    targetY: 82,
    name: 'GROUND 2',
  ),
  _BuiltInPortal(
    10,
    yMin: 71,
    targetMap: 3,
    targetX: 74,
    targetY: 20,
    name: 'WATER FIELD',
  ),
  _BuiltInPortal(
    11,
    yMin: 46,
    targetMap: 7,
    targetX: 38,
    targetY: 7,
    name: 'LASTDITCH',
  ),
  _BuiltInPortal(
    12,
    yMin: 71,
    targetMap: 8,
    targetX: 39,
    targetY: 7,
    name: 'VALIANT PEOPLES',
  ),
  _BuiltInPortal(
    13,
    yMin: 96,
    targetMap: 9,
    targetX: 26,
    targetY: 6,
    name: 'GAIA TERRA',
  ),
  _BuiltInPortal(
    14,
    yMin: 46,
    targetMap: 1,
    targetX: 18,
    targetY: 89,
    name: 'MENACE 출구',
  ),
  _BuiltInPortal(
    15,
    yMin: 71,
    targetMap: 2,
    targetX: 82,
    targetY: 48,
    name: 'QUAKE 출구',
  ),
  _BuiltInPortal(
    16,
    yMin: 36,
    targetMap: 2,
    targetX: 44,
    targetY: 8,
    name: 'WIVERN 출구',
  ),
  _BuiltInPortal(
    17,
    yMin: 95,
    targetMap: 3,
    targetX: 23,
    targetY: 63,
    name: 'NOTICE 출구',
  ),
  _BuiltInPortal(
    18,
    yMin: 95,
    targetMap: 3,
    targetX: 96,
    targetY: 43,
    name: 'LOCKUP 출구',
  ),
  _BuiltInPortal(
    19,
    yMin: 46,
    targetMap: 4,
    targetX: 48,
    targetY: 58,
    name: 'EVIL GOD 출구',
  ),
  _BuiltInPortal(
    20,
    yMin: 96,
    targetMap: 4,
    targetX: 82,
    targetY: 17,
    name: 'DEN7 출구',
  ),
  _BuiltInPortal(
    21,
    y: 46,
    targetMap: 4,
    targetX: 48,
    targetY: 36,
    name: 'SWAMP KEEP 출구',
    script: 'keep1-exit-guard',
  ),
  _BuiltInPortal(
    22,
    y: 46,
    targetMap: 5,
    targetX: 15,
    targetY: 32,
    name: 'KEEP2 출구',
    script: 'keep2-exit-guard',
  ),
  _BuiltInPortal(
    23,
    x: 25,
    y: 12,
    targetMap: 25,
    targetX: 25,
    targetY: 45,
    name: 'DUNGEON OF EVIL',
    script: 'portal-23-25-dungeon',
  ),
  _BuiltInPortal(
    23,
    x: 26,
    y: 12,
    targetMap: 25,
    targetX: 25,
    targetY: 45,
    name: 'DUNGEON OF EVIL',
    script: 'portal-23-25-dungeon',
  ),
  _BuiltInPortal(
    25,
    x: 25,
    y: 27,
    targetMap: 26,
    targetX: 25,
    targetY: 15,
    name: 'CHAMBER OF NECROMANCER',
    script: 'portal-25-26-chamber',
  ),
  _BuiltInPortal(
    25,
    x: 26,
    y: 27,
    targetMap: 26,
    targetX: 25,
    targetY: 15,
    name: 'CHAMBER OF NECROMANCER',
    script: 'portal-25-26-chamber',
  ),
  _BuiltInPortal(
    23,
    yMin: 46,
    targetMap: 5,
    targetX: 34,
    targetY: 15,
    name: 'KEEP3 출구',
  ),
  _BuiltInPortal(
    24,
    yMin: 46,
    targetMap: 22,
    targetX: 25,
    targetY: 24,
    name: 'LAST SHELTER 출구',
  ),
  _BuiltInPortal(
    25,
    yMin: 46,
    targetMap: 23,
    targetX: 25,
    targetY: 45,
    name: 'K_DEN2 출구',
  ),
  _BuiltInPortal(
    27,
    yMin: 50,
    targetMap: 1,
    targetX: 20,
    targetY: 8,
    name: 'ANOTHER LORE 출구',
  ),
  _BuiltInPortal(
    1,
    x: 20,
    y: 11,
    targetMap: 6,
    targetX: 51,
    targetY: 95,
    name: 'CASTLE LORE',
  ),
  _BuiltInPortal(
    1,
    x: 76,
    y: 57,
    targetMap: 7,
    targetX: 37,
    targetY: 70,
    name: 'LASTDITCH',
  ),
  _BuiltInPortal(
    1,
    x: 17,
    y: 89,
    targetMap: 14,
    targetX: 25,
    targetY: 45,
    name: 'MENACE',
  ),
  _BuiltInPortal(
    1,
    x: 20,
    y: 6,
    targetMap: 27,
    targetX: 15,
    targetY: 45,
    name: 'ANOTHER LORE',
  ),
  _BuiltInPortal(
    2,
    x: 19,
    y: 26,
    targetMap: 8,
    targetX: 38,
    targetY: 70,
    name: 'VALIANT PEOPLES',
  ),
  _BuiltInPortal(
    2,
    x: 31,
    y: 82,
    targetMap: 9,
    targetX: 26,
    targetY: 45,
    name: 'GAIA TERRA',
  ),
  _BuiltInPortal(
    2,
    x: 82,
    y: 47,
    targetMap: 15,
    targetX: 25,
    targetY: 70,
    name: 'QUAKE',
  ),
  _BuiltInPortal(
    2,
    x: 44,
    y: 7,
    targetMap: 16,
    targetX: 20,
    targetY: 35,
    name: 'WIVERN',
  ),
  _BuiltInPortal(
    3,
    x: 74,
    y: 19,
    targetMap: 10,
    targetX: 25,
    targetY: 70,
    name: 'WATER FIELD',
  ),
  _BuiltInPortal(
    3,
    x: 23,
    y: 62,
    targetMap: 17,
    targetX: 56,
    targetY: 94,
    name: 'NOTICE',
  ),
  _BuiltInPortal(
    3,
    x: 96,
    y: 42,
    targetMap: 18,
    targetX: 25,
    targetY: 94,
    name: 'LOCKUP',
  ),
  _BuiltInPortal(
    4,
    x: 48,
    y: 35,
    targetMap: 21,
    targetX: 25,
    targetY: 45,
    name: 'SWAMP KEEP',
  ),
  _BuiltInPortal(
    4,
    x: 48,
    y: 57,
    targetMap: 19,
    targetX: 25,
    targetY: 45,
    name: 'EVIL GOD',
  ),
  _BuiltInPortal(
    4,
    x: 82,
    y: 16,
    targetMap: 20,
    targetX: 25,
    targetY: 95,
    name: 'MUDDY',
  ),
  _BuiltInPortal(
    5,
    x: 15,
    y: 31,
    targetMap: 22,
    targetX: 25,
    targetY: 45,
    name: 'IMPERIUM MINOR',
  ),
  _BuiltInPortal(
    5,
    x: 34,
    y: 14,
    targetMap: 23,
    targetX: 25,
    targetY: 45,
    name: 'EVIL CONCENTRATION',
    script: 'portal-5-23-frostdragon',
  ),
  _BuiltInPortal(
    7,
    x: 37,
    y: 6,
    targetMap: 11,
    targetX: 25,
    targetY: 45,
    name: 'PYRAMID',
  ),
  _BuiltInPortal(
    7,
    x: 38,
    y: 6,
    targetMap: 11,
    targetX: 25,
    targetY: 45,
    name: 'PYRAMID',
  ),
  _BuiltInPortal(
    7,
    x: 39,
    y: 6,
    targetMap: 11,
    targetX: 25,
    targetY: 45,
    name: 'PYRAMID',
  ),
  _BuiltInPortal(
    7,
    x: 40,
    y: 6,
    targetMap: 11,
    targetX: 25,
    targetY: 45,
    name: 'PYRAMID',
  ),
  _BuiltInPortal(
    8,
    x: 37,
    y: 6,
    targetMap: 12,
    targetX: 25,
    targetY: 70,
    name: 'EVIL SEAL',
  ),
  _BuiltInPortal(
    8,
    x: 38,
    y: 6,
    targetMap: 12,
    targetX: 25,
    targetY: 70,
    name: 'EVIL SEAL',
  ),
  _BuiltInPortal(
    8,
    x: 39,
    y: 6,
    targetMap: 12,
    targetX: 25,
    targetY: 70,
    name: 'EVIL SEAL',
  ),
  _BuiltInPortal(
    8,
    x: 40,
    y: 6,
    targetMap: 12,
    targetX: 25,
    targetY: 70,
    name: 'EVIL SEAL',
  ),
  _BuiltInPortal(
    10,
    x: 25,
    y: 7,
    targetMap: 16,
    targetX: 20,
    targetY: 9,
    name: 'WIVERN',
  ),
  _BuiltInPortal(
    10,
    x: 26,
    y: 7,
    targetMap: 16,
    targetX: 20,
    targetY: 9,
    name: 'WIVERN',
  ),
  _BuiltInPortal(
    13,
    x: 80,
    y: 67,
    targetMap: 21,
    targetX: 25,
    targetY: 6,
    name: 'SWAMP KEEP',
  ),
  _BuiltInPortal(
    13,
    x: 81,
    y: 67,
    targetMap: 21,
    targetX: 25,
    targetY: 6,
    name: 'SWAMP KEEP',
  ),
  _BuiltInPortal(
    13,
    x: 82,
    y: 67,
    targetMap: 21,
    targetX: 25,
    targetY: 6,
    name: 'SWAMP KEEP',
  ),
  _BuiltInPortal(
    16,
    x: 20,
    y: 8,
    targetMap: 10,
    targetX: 26,
    targetY: 8,
    name: 'WATER FIELD',
  ),
  _BuiltInPortal(
    16,
    x: 21,
    y: 8,
    targetMap: 10,
    targetX: 26,
    targetY: 8,
    name: 'WATER FIELD',
  ),
  _BuiltInPortal(
    21,
    x: 24,
    y: 5,
    targetMap: 13,
    targetX: 81,
    targetY: 68,
    name: 'SWAMP GATE',
  ),
  _BuiltInPortal(
    21,
    x: 25,
    y: 5,
    targetMap: 13,
    targetX: 81,
    targetY: 68,
    name: 'SWAMP GATE',
  ),
  _BuiltInPortal(
    21,
    x: 26,
    y: 5,
    targetMap: 13,
    targetX: 81,
    targetY: 68,
    name: 'SWAMP GATE',
  ),
  _BuiltInPortal(
    21,
    x: 25,
    y: 19,
    targetMap: 22,
    targetX: 25,
    targetY: 6,
    name: 'IMPERIUM MINOR',
    script: 'portal-21-22-lavagate',
  ),
  _BuiltInPortal(
    22,
    x: 24,
    y: 5,
    targetMap: 21,
    targetX: 25,
    targetY: 20,
    name: 'SWAMP KEEP',
  ),
  _BuiltInPortal(
    22,
    x: 25,
    y: 5,
    targetMap: 21,
    targetX: 25,
    targetY: 20,
    name: 'SWAMP KEEP',
  ),
  _BuiltInPortal(
    22,
    x: 26,
    y: 5,
    targetMap: 21,
    targetX: 25,
    targetY: 20,
    name: 'SWAMP KEEP',
  ),
  _BuiltInPortal(
    22,
    x: 25,
    y: 23,
    targetMap: 24,
    targetX: 25,
    targetY: 45,
    name: 'LAST SHELTER',
  ),
];

/// 시설 규칙 1건 (원작 `LORETALK.PAS`의 `then train_center;` 같은 트리거).
class _FacilityRule {
  final int map;
  final int x;
  final int y;
  final int facility;

  const _FacilityRule({
    required this.map,
    required this.x,
    required this.y,
    required this.facility,
  });

  bool matches(int mapId, int px, int py) => map == mapId && x == px && y == py;

  int? match(int mapId, int px, int py) =>
      matches(mapId, px, py) ? facility : null;
}

/// Original LORETALK.PAS facility coordinates.
// ignore: constant_identifier_names
const List<_FacilityRule> _builtInFacilities = [
  _FacilityRule(map: 6, x: 8, y: 71, facility: 1), // 무기점
  _FacilityRule(map: 6, x: 14, y: 69, facility: 1), // 무기점
  _FacilityRule(map: 6, x: 14, y: 73, facility: 1), // 무기점
  _FacilityRule(map: 6, x: 86, y: 12, facility: 2), // 병원
  _FacilityRule(map: 6, x: 87, y: 14, facility: 2), // 병원
  _FacilityRule(map: 6, x: 21, y: 12, facility: 3), // 훈련소
  _FacilityRule(map: 6, x: 25, y: 13, facility: 3), // 훈련소
  _FacilityRule(map: 6, x: 87, y: 73, facility: 4), // 식료품점
  _FacilityRule(map: 6, x: 91, y: 65, facility: 4), // 식료품점
  _FacilityRule(map: 7, x: 59, y: 56, facility: 1), // 무기점
  _FacilityRule(map: 7, x: 59, y: 58, facility: 1), // 무기점
  _FacilityRule(map: 7, x: 59, y: 60, facility: 1), // 무기점
  _FacilityRule(map: 7, x: 17, y: 56, facility: 2), // 병원
  _FacilityRule(map: 7, x: 17, y: 58, facility: 2), // 병원
  _FacilityRule(map: 7, x: 17, y: 60, facility: 2), // 병원
  _FacilityRule(map: 7, x: 16, y: 24, facility: 3), // 훈련소
  _FacilityRule(map: 7, x: 18, y: 19, facility: 3), // 훈련소
  _FacilityRule(map: 7, x: 21, y: 21, facility: 3), // 훈련소
  _FacilityRule(map: 7, x: 24, y: 19, facility: 3), // 훈련소
  _FacilityRule(map: 7, x: 54, y: 20, facility: 4), // 식료품점
  _FacilityRule(map: 7, x: 57, y: 17, facility: 4), // 식료품점
  _FacilityRule(map: 7, x: 58, y: 22, facility: 4), // 식료품점
  _FacilityRule(map: 7, x: 59, y: 25, facility: 4), // 식료품점
  _FacilityRule(map: 9, x: 37, y: 10, facility: 1), // 무기점
  _FacilityRule(map: 9, x: 40, y: 12, facility: 1), // 무기점
  _FacilityRule(map: 9, x: 41, y: 15, facility: 1), // 무기점
  _FacilityRule(map: 9, x: 9, y: 39, facility: 2), // 병원
  _FacilityRule(map: 9, x: 12, y: 41, facility: 2), // 병원
  _FacilityRule(map: 9, x: 16, y: 40, facility: 2), // 병원
  _FacilityRule(map: 9, x: 12, y: 11, facility: 3), // 훈련소
  _FacilityRule(map: 9, x: 12, y: 15, facility: 3), // 훈련소
  _FacilityRule(map: 9, x: 15, y: 12, facility: 3), // 훈련소
  _FacilityRule(map: 9, x: 37, y: 39, facility: 4), // 식료품점
  _FacilityRule(map: 9, x: 40, y: 37, facility: 4), // 식료품점
  _FacilityRule(map: 9, x: 41, y: 41, facility: 4), // 식료품점
  _FacilityRule(map: 10, x: 11, y: 30, facility: 1), // 무기점
  _FacilityRule(map: 10, x: 11, y: 32, facility: 1), // 무기점
  _FacilityRule(map: 10, x: 13, y: 34, facility: 1), // 무기점
  _FacilityRule(map: 10, x: 33, y: 60, facility: 2), // 병원
  _FacilityRule(map: 10, x: 35, y: 54, facility: 2), // 병원
  _FacilityRule(map: 10, x: 41, y: 58, facility: 2), // 병원
  _FacilityRule(map: 10, x: 36, y: 32, facility: 3), // 훈련소
  _FacilityRule(map: 10, x: 38, y: 33, facility: 3), // 훈련소
  _FacilityRule(map: 10, x: 39, y: 35, facility: 3), // 훈련소
  _FacilityRule(map: 10, x: 11, y: 55, facility: 4), // 식료품점
  _FacilityRule(map: 10, x: 12, y: 59, facility: 4), // 식료품점
  _FacilityRule(map: 10, x: 17, y: 57, facility: 4), // 식료품점
  _FacilityRule(map: 24, x: 33, y: 21, facility: 1), // 무기점
  _FacilityRule(map: 24, x: 37, y: 24, facility: 1), // 무기점
  _FacilityRule(map: 24, x: 40, y: 23, facility: 1), // 무기점
  _FacilityRule(map: 24, x: 11, y: 38, facility: 2), // 병원
  _FacilityRule(map: 24, x: 14, y: 40, facility: 2), // 병원
  _FacilityRule(map: 24, x: 15, y: 36, facility: 2), // 병원
  _FacilityRule(map: 24, x: 11, y: 22, facility: 3), // 훈련소
  _FacilityRule(map: 24, x: 14, y: 24, facility: 3), // 훈련소
  _FacilityRule(map: 24, x: 33, y: 35, facility: 4), // 식료품점
  _FacilityRule(map: 24, x: 35, y: 37, facility: 4), // 식료품점
  _FacilityRule(map: 24, x: 41, y: 38, facility: 4), // 식료품점
];

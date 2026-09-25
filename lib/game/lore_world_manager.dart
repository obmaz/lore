import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

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

  const PortalInfo({
    required this.targetMapId,
    required this.targetX,
    required this.targetY,
    required this.name,
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
  // JSON 데이터 (assets/data/portals.json)
  // =========================================================================

  List<_PortalRule> _portalRules = [];
  List<_SignRule> _signRules = [];
  bool _loadedRules = false;

  /// JSON 규칙을 사용 중인지(테스트/디버깅용).
  bool usingJsonRules = false;
  String? rulesLoadError;

  /// `assets/data/portals.json`을 읽는다. 실패하면 아래 코드 내장 규칙을 사용한다.
  Future<void> loadData({AssetBundle? bundle}) async {
    if (_loadedRules) return;
    try {
      final decoded = json.decode(
        await (bundle ?? rootBundle).loadString('assets/data/portals.json'),
      ) as Map<String, dynamic>;
      _portalRules = (decoded['portals'] as List<dynamic>)
          .map((e) => _PortalRule.fromJson(e as Map<String, dynamic>))
          .toList();
      _signRules = (decoded['signs'] as List<dynamic>)
          .map((e) => _SignRule.fromJson(e as Map<String, dynamic>))
          .toList();
      usingJsonRules = true;
    } catch (e) {
      _portalRules = [];
      _signRules = [];
      usingJsonRules = false;
      rulesLoadError = e.toString();
    }
    _loadedRules = true;
  }

  void resetRulesForTest() {
    _loadedRules = false;
    usingJsonRules = false;
    rulesLoadError = null;
    _portalRules = [];
    _signRules = [];
  }

  /// LOREENT.PAS의 월드맵/마을 간 포털 연결 정의 (맵ID, x, y) -> PortalInfo
  PortalInfo? findPortal(int currentMapId, int x, int y) {
    // 1순위: JSON 규칙 (assets/data/portals.json)
    for (final rule in _portalRules) {
      final portal = rule.match(currentMapId, x, y);
      if (portal != null) return portal;
    }
    // JSON이 로드되었다면 JSON이 단일 소스이므로 내장 규칙은 쓰지 않는다.
    if (usingJsonRules) return null;
    return _findPortalBuiltIn(currentMapId, x, y);
  }

  PortalInfo? _findPortalBuiltIn(int currentMapId, int x, int y) {
    // 1. GROUND1 (맵 1) 에서 진입
    if (currentMapId == 1) {
      if (x == 20 && y == 11) {
        return const PortalInfo(
          targetMapId: 6,
          targetX: 51,
          targetY: 95,
          name: 'CASTLE LORE',
        );
      }
      if (x == 76 && y == 57) {
        return const PortalInfo(
          targetMapId: 7,
          targetX: 37,
          targetY: 70,
          name: 'LASTDITCH',
        );
      }
      if (x == 17 && y == 89) {
        return const PortalInfo(
          targetMapId: 14,
          targetX: 25,
          targetY: 45,
          name: 'MENACE',
        );
      }
      if (x == 20 && y == 6) {
        return const PortalInfo(
          targetMapId: 27,
          targetX: 15,
          targetY: 45,
          name: 'ANOTHER LORE',
        );
      }
    }

    // 2. CASTLE LORE 성 (맵 6) 성문 -> 필드(GROUND1)로 출구
    if (currentMapId == 6) {
      if (y >= 96 || (x == 51 && y == 96)) {
        return const PortalInfo(
          targetMapId: 1,
          targetX: 20,
          targetY: 12,
          name: 'GROUND FIELD',
        );
      }
    }

    // 3. LASTDITCH (맵 7) -> 출구
    if (currentMapId == 7) {
      if (y >= 71) {
        return const PortalInfo(
          targetMapId: 1,
          targetX: 76,
          targetY: 58,
          name: 'GROUND FIELD',
        );
      }
    }

    // 4. GROUND2 (맵 2) 에서 진입
    if (currentMapId == 2) {
      if (x == 19 && y == 26) {
        return const PortalInfo(
          targetMapId: 8,
          targetX: 38,
          targetY: 70,
          name: 'VALIANT PEOPLES',
        );
      }
      if (x == 31 && y == 82) {
        return const PortalInfo(
          targetMapId: 9,
          targetX: 26,
          targetY: 45,
          name: 'GAIA TERRA',
        );
      }
      if (x == 82 && y == 47) {
        return const PortalInfo(
          targetMapId: 15,
          targetX: 25,
          targetY: 70,
          name: 'QUAKE',
        );
      }
      if (x == 44 && y == 7) {
        return const PortalInfo(
          targetMapId: 16,
          targetX: 20,
          targetY: 35,
          name: 'WIVERN',
        );
      }
    }

    // 5. 일반 성문 타일(22)이나 탈출구 기본 fallback
    return null;
  }

  /// LOREENT.PAS sign 프로시저 기반 표지판/푯말 메시지
  String? getSignMessage(int mapId, int x, int y) {
    // 1순위: 좌표가 정확히 일치하는 JSON 규칙
    for (final rule in _signRules) {
      if (rule.mapDefault) continue;
      final text = rule.match(mapId, x, y);
      if (text != null) return text;
    }
    // 2순위: 맵 기본 문구 규칙
    for (final rule in _signRules) {
      final text = rule.match(mapId, x, y);
      if (text != null) return text;
    }
    // JSON이 로드되었다면 JSON이 단일 소스이므로 내장 규칙은 쓰지 않는다.
    if (usingJsonRules) return null;
    if (mapId == 2) {
      if (x == 31 && y == 44) return '푯말: WIVERN 가는길';
      if ((x == 29 && y == 50) || (x == 35 && y == 72)) {
        return '푯말: 북쪽: VALIANT PEOPLES 가는길 / 남쪽: GAIA TERRA 가는길';
      }
      if (x == 44 && y == 77) {
        return '푯말: 북동쪽: QUAKE 가는길 / 남서쪽: GAIA TERRA 가는길';
      }
    }
    if (mapId == 6) {
      if (x == 51 && y == 84) {
        return "푯말: '여기는 CASTLE LORE 성. 여러분을 환영합니다.' - Lord Ahn";
      }
      if (x == 24 && y == 31) {
        return "푯말: '여기는 LORE 주점. 여러분 모두를 환영합니다 !!'";
      }
      if (x == 51 && y == 18 || x == 52 && y == 18) {
        return "푯말: 'LORE 왕립 죄수 수용소 - 면회 사절'";
      }
    }
    if (mapId == 7) {
      if (x == 39 && y == 68) return "푯말: '여기는 LASTDITCH. 여러분을 환영합니다.'";
      if (x == 39 && y == 8) return "푯말: '여기는 PYRAMID의 입구'";
      if (x == 54 && y == 9) return "푯말: '여기는 GROUND GATE의 입구'";
    }
    if (mapId == 8) {
      if (x == 39 && y == 67) {
        return "푯말: '여기는 VALIANT PEOPLES. 용사의 영혼은 대륙을 지킨다.'";
      }
    }
    if (mapId == 9) {
      if (x == 24 && y == 26) return "푯말: '여기는 거인의 안식처 입구'";
      return "푯말: '여기는 GAIA TERRA. 여러분을 환영합니다.'";
    }
    if (mapId == 12) {
      if (x == 24 && y == 68) return "벽에 적힌 글: 'X 는 7'";
      if (x == 27 && y == 68) return "벽에 적힌 글: 'Y 는 9'";
      if (x == 25 && y == 63) return "벽에 적힌 글: '첫번째 문의 열쇠는 X + Y'";
      if (x == 26 && y == 42) return "벽에 적힌 글: 'Z 는 2 * Y + X'";
    }
    return null;
  }
}

/// 포털 규칙 1건 (정확 좌표 또는 범위 조건).
class _PortalRule {
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

  const _PortalRule({
    required this.map,
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
  });

  factory _PortalRule.fromJson(Map<String, dynamic> json) => _PortalRule(
    map: json['map'] as int,
    x: json['x'] as int?,
    y: json['y'] as int?,
    xMin: json['xMin'] as int?,
    xMax: json['xMax'] as int?,
    yMin: json['yMin'] as int?,
    yMax: json['yMax'] as int?,
    targetMap: json['targetMap'] as int,
    targetX: json['targetX'] as int,
    targetY: json['targetY'] as int,
    name: json['name'] as String,
  );

  PortalInfo? match(int mapId, int px, int py) {
    if (mapId != map) return null;
    if (x != null && px != x) return null;
    if (y != null && py != y) return null;
    if (xMin != null && px < xMin!) return null;
    if (xMax != null && px > xMax!) return null;
    if (yMin != null && py < yMin!) return null;
    if (yMax != null && py > yMax!) return null;
    return PortalInfo(
      targetMapId: targetMap,
      targetX: targetX,
      targetY: targetY,
      name: name,
    );
  }
}

/// 표지판 규칙 1건 (좌표 또는 맵 기본 문구).
class _SignRule {
  final int map;
  final int? x;
  final int? y;
  final bool mapDefault;
  final String text;

  const _SignRule({
    required this.map,
    this.x,
    this.y,
    this.mapDefault = false,
    required this.text,
  });

  factory _SignRule.fromJson(Map<String, dynamic> json) => _SignRule(
    map: json['map'] as int,
    x: json['x'] as int?,
    y: json['y'] as int?,
    mapDefault: json['mapDefault'] == true,
    text: json['text'] as String,
  );

  String? match(int mapId, int px, int py) {
    if (mapId != map) return null;
    if (mapDefault) return text;
    // 정확 좌표 규칙은 맵 기본 문구보다 우선한다.
    if (x == px && y == py) return text;
    return null;
  }
}

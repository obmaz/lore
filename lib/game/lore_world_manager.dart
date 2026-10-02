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
  // JSON 데이터 (assets/data/portals.json)
  // =========================================================================

  List<_PortalRule> _portalRules = [];
  List<_SignRule> _signRules = [];
  List<_FacilityRule> _facilityRules = [];
  bool _loadedRules = false;

  /// JSON 규칙을 사용 중인지(테스트/디버깅용).
  bool usingJsonRules = false;

  /// `assets/data/facilities.json`의 시설 좌표를 사용 중인지.
  bool usingJsonFacilities = false;
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
      // 시설 좌표는 별도 파일이므로, 있으면 함께 읽는다(없어도 동작).
      try {
        final facilities = json.decode(
          await (bundle ?? rootBundle).loadString(
            'assets/data/facilities.json',
          ),
        ) as Map<String, dynamic>;
        _facilityRules = (facilities['facilities'] as List<dynamic>)
            .map((e) => _FacilityRule.fromJson(e as Map<String, dynamic>))
            .toList();
        usingJsonFacilities = true;
      } catch (e) {
        _facilityRules = [];
        usingJsonFacilities = false;
      }
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
    usingJsonFacilities = false;
    rulesLoadError = null;
    _portalRules = [];
    _signRules = [];
    _facilityRules = [];
  }

  /// 원작 `LORETALK.PAS`가 시설(무기점/병원/훈련소/식료품점)로 진입시키는 좌표.
  ///
  /// 반환값: 1=무기점, 2=병원, 3=훈련소, 4=식료품점 (없으면 null).
  int? findFacility(int currentMapId, int x, int y) {
    for (final rule in _facilityRules) {
      final code = rule.match(currentMapId, x, y);
      if (code != null) return code;
    }
    if (usingJsonFacilities) return null;
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
    8 when x == 50 => y,
    9 when y == 5 => y + 1,
    9 when y == 46 => y - 1,
    // LORESPEC.PAS:515-521 has no refusal branch: the party stays on y = 46.
    11 when y == 46 => y,
    8 || 10 when y == 71 => y - 1,
    21 || 22 || 23 || 24 || 25 when y == 46 => y - 1,
    27 => y < 25 ? y + 1 : y - 1,
    _ => null,
  };

  /// LORESPEC.PAS:334/383: map 8 x = 50 and map 9 y = 5 ask `wantenter`.
  static bool sourceAsksEnter(int mapId, int x, int y) =>
      (mapId == 8 && x == 50) || (mapId == 9 && y == 5);

  /// LOREENT.PAS의 월드맵/마을 간 포털 연결 정의 (맵ID, x, y) -> PortalInfo
  PortalInfo? findPortal(int currentMapId, int x, int y) {
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
    if (currentMapId == 11 && y >= 46) {
      if (y > 46) return null;
      return const PortalInfo(
        targetMapId: 7,
        targetX: 38,
        targetY: 7,
        name: 'LASTDITCH',
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

  /// 원작 `LOREENT.PAS:440` 맵 12 의 **동적** 퐷말 문구.
  ///
  /// 미로의 문 번호는 원작에서 플레이어 좌표로 계산해 출력하므로 JSON 에 담을
  /// 수 없다(`j := (x+x1-6) div 7 + 12` / `j := (x+x1-3) div 5 + 2`).
  String? _dynamicSignMessage(int mapId, int x, int y) {
    if (mapId != 12) return null;
    if (y == 56) {
      final number = (x - 6) ~/ 7 + 12;
      return "퐷말에 쓰여있기로 ...\n           문의 번호는 '$number'";
    }
    if (y == 29) {
      final number = (x - 3) ~/ 5 + 2;
      return "퐷말에 쓰여있기로 ...\n           패스코드는 '$number'";
    }
    return null;
  }

  /// LOREENT.PAS sign 프로시저 기반 표지판/퐷말 메시지
  String? getSignMessage(int mapId, int x, int y) {
    final dynamicText = _dynamicSignMessage(mapId, x, y);
    if (dynamicText != null) return dynamicText;
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
      if (x == 31 && y == 44) {
        return '푯말에 쓰여있기로 ...\n          WIVERN 가는길';
      }
      if (x == 29 && y == 50) {
        return '푯말에 쓰여있기로 ...\n  북쪽 :\n       VALIANT PEOPLES 가는길\n  남쪽 :\n       GAIA TERRA 가는길';
      }
      if (x == 35 && y == 72) {
        return '푯말에 쓰여있기로 ...\n  북쪽 :\n       VALIANT PEOPLES 가는길\n  남쪽 :\n       GAIA TERRA 가는길';
      }
      if (x == 44 && y == 77) {
        return '푯말에 쓰여있기로 ...\n  북동쪽 :\n       QUAKE 가는길\n  남서쪽 :\n       GAIA TERRA 가는길';
      }
    }
    if (mapId == 6) {
      if (x == 51 && y == 84) {
        return '푯말에 쓰여있기로 ...\n       여기는 `CASTLE LORE\'성\n         여러분을 환영합니다';
      }
      if (x == 24 && y == 31) {
        return '푯말에 쓰여있기로 ...\n             여기는 LORE 주점\n       여러분 모두를 환영합니다 !!';
      }
      if (x == 51 && y == 18) {
        return '푯말에 쓰여있기로 ...\n          LORE 왕립  죄수 수용소';
      }
      if (x == 52 && y == 18) {
        return '푯말에 쓰여있기로 ...\n          LORE 왕립  죄수 수용소';
      }
    }
    if (mapId == 7) {
      if (x == 39 && y == 68) {
        return '푯말에 쓰여있기로 ...\n        여기는 `LASTDITCH\'성\n         여러분을 환영합니다';
      }
      if (x == 39 && y == 8) {
        return '푯말에 쓰여있기로 ...\n       여기는 PYRAMID 의 입구';
      }
      if (x == 54 && y == 9) {
        return '푯말에 쓰여있기로 ...\n     여기는 GROUND GATE 의 입구';
      }
    }
    if (mapId == 8) {
      if (x == 39 && y == 67) {
        return '푯말에 쓰여있기로 ...\n      여기는`VALIANT PEOPLES\'성\n    우리의 미덕은 굽히지 않는 용기\n   우리는 어떤 악에도 굽히지 않는다';
      }
      return '푯말에 쓰여있기로 ...\n     여기는 EVIL SEAL 의 입구';
    }
    if (mapId == 9) {
      if (x == 24 && y == 26) {
        return '푯말에 쓰여있기로 ...\n       여기는 국왕의 보물 창고';
      }
      return '푯말에 쓰여있기로 ...\n         여기는 `GAIA TERRA\'성\n          여러분을 환영합니다';
    }
    if (mapId == 12) {
      if (x == 24 && y == 68) {
        return '푯말에 쓰여있기로 ...\n               X 는 7';
      }
      if (x == 27 && y == 68) {
        return '푯말에 쓰여있기로 ...\n               Y 는 9';
      }
      if (x == 25 && y == 63) {
        return '푯말에 쓰여있기로 ...\n       바른 문의 번호는 X + Y';
      }
      if (x == 26 && y == 42) {
        return '푯말에 쓰여있기로 ...\n            Z 는 2 * Y + X';
      }
      if (x == 26 && y == 33) {
        return '푯말에 쓰여있기로 ...\n        패스코드 x 패스코드 는 Z 라면\n            패스코드는 무엇인가 ?';
      }
    }
    if (mapId == 15) {
      if (x == 26 && y == 63) {
        return '푯말에 쓰여있기로 ...\n            길의 마지막';
      }
      if (x == 22 && y == 15) {
        return '푯말에 쓰여있기로 ...\n     (12,15) 로 공간이동 하시오';
      }
      if (x == 11 && y == 14) {
        return '푯말에 쓰여있기로 ...\n     (13,7) 로 공간이동 하시오';
      }
      if (x == 27 && y == 14) {
        return '푯말에 쓰여있기로 ...\n   황금의 갑옷은 (45,19) 에 숨겨져있음';
      }
      return '푯말에 쓰여있기로 ...';
    }
    if (mapId == 17) {
      if (x == 68 && y == 47) {
        return '푯말에 쓰여있기로 ...\n    하! 하! 하!  너는 우리에게 속았다';
      }
      if (x == 58 && y == 53) {
        return '푯말에 쓰여있기로 ...\n      이 게임을 만든 사람\n  : 동아 대학교 전기 공학과\n        92 학번  안 영기';
      }
      if (x == 51 && y == 30) {
        return '푯말에 쓰여있기로 ...\n       오른쪽 : Hidra 의 보물창고\n       왼  쪽 : Hidra 가 있는 방';
      }
      if (x == 66 && y == 13) {
        return '푯말에 쓰여있기로 ...\n     일찌감치 이 곳 탐험을 포기해라';
      }
      if (x == 9 && y == 28) {
        return '푯말에 쓰여있기로 ...\n         위쪽이 진짜 보물창고임';
      }
      return '푯말에 쓰여있기로 ...';
    }
    if (mapId == 19) {
      if (x == 26 && y == 40) {
        return '푯말에 쓰여있기로 ...\n       이 길을 통과하고자하는 사람은\n     양측의 늪속에 있는 레버를 당기시오';
      }
    }
    if (mapId == 23) {
      return '푯말에 쓰여있기로 ...\n      (25,27)에 있는 레버를 움직이면\n          성을 볼수 있을 것이오.\n             제작자 안 영기 씀';
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
  final String? script;

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
    this.script,
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
    script: json['script'] as String?,
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
      scriptId: script,
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

/// JSON(`assets/data/portals.json`)을 읽지 못했을 때 쓰는 내장 포털 표.
///
/// 원작 `LOREENT.PAS`(마을 진입)와 `LORESPEC.PAS`(맵 출구 `wantexit`)의
/// 목적지 좌표를 그대로 옮긴 것으로, JSON 규칙과 항상 같은 결과를 내야 한다
/// (`test/world_rules_test.dart`가 둘을 대조한다).
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
  // `tool/export_lore_ent.py --write` 가 JSON 에서 자동 생성한다.
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

  factory _FacilityRule.fromJson(Map<String, dynamic> json) => _FacilityRule(
    map: json['map'] as int,
    x: json['x'] as int,
    y: json['y'] as int,
    facility: json['facility'] as int,
  );

  bool matches(int mapId, int px, int py) => map == mapId && x == px && y == py;

  int? match(int mapId, int px, int py) =>
      matches(mapId, px, py) ? facility : null;
}

/// JSON(`assets/data/facilities.json`)을 읽지 못했을 때 쓰는 내장 시설 표.
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

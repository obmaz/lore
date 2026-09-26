import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/game/lore_world_manager.dart';

class _MissingBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => throw Exception('asset not found');
}

/// 맵 연결(포털)과 표지판을 JSON(`assets/data/portals.json`)으로 관리하는지 검증.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final manager = LoreWorldManager.instance;

  /// 내장 규칙으로 조회한 결과(참조값).
  Map<String, String?> builtInLookup(List<(int, int, int)> coords) {
    manager.resetRulesForTest(); // JSON 미로드 상태 → 내장 규칙 사용
    return {
      for (final (map, x, y) in coords)
        '$map,$x,$y': _describePortal(manager.findPortal(map, x, y)),
    };
  }

  setUp(() => manager.resetRulesForTest());
  tearDown(() => manager.resetRulesForTest());

  group('JSON 월드 규칙 (assets/data/portals.json)', () {
    test('명시 좌표 포털은 실제 맵의 진입 타일에 놓인다', () async {
      final raw = jsonDecode(
        await rootBundle.loadString('assets/data/portals.json'),
      ) as Map<String, dynamic>;
      final maps = <int, LoreMapData>{};
      for (final entry in raw['portals'] as List<dynamic>) {
        final portal = entry as Map<String, dynamic>;
        final x = portal['x'] as int?;
        final y = portal['y'] as int?;
        if (x == null || y == null) continue;
        final mapId = portal['map'] as int;
        final info = LoreWorldManager.mapRegistry[mapId]!;
        final map = maps[mapId] ??= await LoreMapData.loadFromAsset(
          info.fileName,
          category: info.category.name,
        );
        final category = map.getCategory(map.getTile(x, y));
        expect(
          category == TileCategory.portal || category == TileCategory.special,
          isTrue,
          reason: '맵 $mapId ($x,$y)의 타일은 포털이 아니다',
        );
      }
      for (final (mapId, x, y) in <(int, int, int)>[
        (7, 50, 9),
        (7, 50, 10),
        (8, 50, 9),
        (8, 50, 10),
        (9, 24, 5),
        (9, 29, 5),
      ]) {
        final info = LoreWorldManager.mapRegistry[mapId]!;
        final map = maps[mapId] ??= await LoreMapData.loadFromAsset(
          info.fileName,
          category: info.category.name,
        );
        expect(map.getCategory(map.getTile(x, y)), TileCategory.special);
      }
    });

    test('1. 포털: JSON 규칙이 내장 규칙과 완전히 일치한다', () async {
      final raw = jsonDecode(
        await rootBundle.loadString('assets/data/portals.json'),
      ) as Map<String, dynamic>;
      // 모든 명시 좌표와 범위 경계를 비교한다.
      final coords = <(int, int, int)>[
        for (final item in raw['portals'] as List<dynamic>)
          if ((item as Map<String, dynamic>)['x'] is int && item['y'] is int)
            (item['map'] as int, item['x'] as int, item['y'] as int),
        (1, 20, 11),
        (1, 76, 57),
        (1, 17, 89),
        (1, 20, 6),
        (6, 51, 96), // 성문 y>=96 범위 규칙
        (6, 51, 97),
        (7, 39, 75), // LASTDITCH 출구 y>=71
        (7, 39, 71),
        (7, 50, 9),
        (7, 50, 10),
        (8, 50, 9),
        (8, 50, 10),
        (9, 24, 5),
        (9, 29, 5),
        (2, 19, 26),
        (2, 31, 82),
        (2, 82, 47),
        (2, 44, 7),
        (22, 25, 46), // KEEP2 출구 수문장 전투
        (22, 25, 23), // LAST SHELTER 입구
        (21, 25, 19), // IMPERIUM MINOR 입구
        (23, 25, 12),
        (23, 26, 12),
        (25, 25, 27),
        (25, 26, 27),
        // 포털이 아닌 좌표
        (1, 0, 0),
        (6, 10, 10),
        (2, 20, 20),
      ];

      final before = builtInLookup(coords);

      await manager.loadData();
      expect(
        manager.usingJsonRules,
        isTrue,
        reason: 'JSON 로드 실패: ${manager.rulesLoadError}',
      );

      for (final (map, x, y) in coords) {
        final key = '$map,$x,$y';
        expect(
          _describePortal(manager.findPortal(map, x, y)),
          before[key],
          reason: '포털 불일치: 맵 $map ($x,$y)',
        );
      }
    });

    test('2. 포털 목적지 값이 원작과 일치한다', () async {
      await manager.loadData();

      final castle = manager.findPortal(1, 20, 11)!;
      expect(castle.targetMapId, 6);
      expect(castle.targetX, 51);
      expect(castle.targetY, 95);
      expect(castle.name, 'CASTLE LORE');

      final gate = manager.findPortal(6, 51, 96)!;
      expect(gate.targetMapId, 1);
      expect(gate.name, 'GROUND FIELD');

      expect(manager.findPortal(7, 50, 9)!.targetMapId, 8);
      expect(manager.findPortal(8, 50, 10)!.targetMapId, 7);
      final swampGate = manager.findPortal(9, 25, 5)!;
      expect(swampGate.targetMapId, 13);
      expect((swampGate.targetX, swampGate.targetY), (81, 95));
      expect(swampGate.scriptId, 'portal-9-13-swamp-gate');

      final quake = manager.findPortal(2, 82, 47)!;
      expect(quake.targetMapId, 15);
      expect(quake.targetX, 25);
      expect(quake.targetY, 70);

      final shelter = manager.findPortal(22, 25, 23)!;
      expect(shelter.targetMapId, 24);
      expect(shelter.targetX, 25);
      expect(shelter.targetY, 45);
      expect(shelter.name, 'LAST SHELTER');

      final imperium = manager.findPortal(21, 25, 19)!;
      expect(imperium.targetMapId, 22);
      expect(imperium.targetX, 25);
      expect(imperium.targetY, 6);
      expect(imperium.scriptId, 'portal-21-22-lavagate');

      final swampKeepExit = manager.findPortal(21, 25, 46)!;
      expect(swampKeepExit.targetMapId, 4);
      expect(swampKeepExit.scriptId, 'keep1-exit-guard');
      expect(manager.findPortal(21, 25, 47), isNull);

      final evilConcentration = manager.findPortal(5, 34, 14)!;
      expect(evilConcentration.targetMapId, 23);
      expect(evilConcentration.scriptId, 'portal-5-23-frostdragon');
    });
    test('2-1. 원작 LORESPEC의 맵 출구(wantexit) 20곳이 모두 있다', () async {
      await manager.loadData();

      // (맵, 조건 y, 목적지 맵/좌표) - 원작 `if y = N then if wantexit`
      const exits = <(int, int, int, int, int)>[
        (6, 96, 1, 20, 12),
        (7, 71, 1, 77, 57),
        (8, 71, 2, 19, 27),
        (9, 46, 2, 32, 82),
        (10, 71, 3, 74, 20),
        (11, 46, 7, 38, 7),
        (12, 71, 8, 39, 7),
        (13, 96, 9, 26, 6),
        (14, 46, 1, 18, 89),
        (15, 71, 2, 82, 48),
        (16, 36, 2, 44, 8),
        (17, 95, 3, 23, 63),
        (18, 95, 3, 96, 43),
        (19, 46, 4, 48, 58),
        (20, 96, 4, 82, 17),
        (21, 46, 4, 48, 36),
        (22, 46, 5, 15, 32),
        (23, 46, 5, 34, 15),
        (24, 46, 22, 25, 24),
        (25, 46, 23, 25, 45),
        (27, 50, 1, 20, 8),
      ];

      for (final (map, y, tm, tx, ty) in exits) {
        final portal = manager.findPortal(map, 10, y);
        expect(portal, isNotNull, reason: '맵 $map y=$y 출구 누락');
        expect(portal!.targetMapId, tm, reason: '맵 $map y=$y 목적지 맵');
        expect(portal.targetX, tx, reason: '맵 $map y=$y 목적지 x');
        expect(portal.targetY, ty, reason: '맵 $map y=$y 목적지 y');
        // 출구 행 바로 위에서는 발동하지 않는다.
        expect(
          manager.findPortal(map, 10, y - 1),
          isNull,
          reason: '맵 $map y=${y - 1} 오발동',
        );
      }
    });
    test('3. 표지판: JSON 규칙이 내장 규칙과 일치한다', () async {
      const coords = <(int, int, int)>[
        (2, 31, 44),
        (2, 29, 50),
        (2, 35, 72),
        (2, 44, 77),
        (6, 51, 84),
        (6, 24, 31),
        (6, 51, 18),
        (6, 52, 18),
        (7, 39, 68),
        (7, 39, 8),
        (7, 54, 9),
        (8, 39, 67),
        (9, 24, 26),
        (9, 99, 99), // 맵 9 기본 문구
        (12, 24, 68),
        (12, 27, 68),
        (12, 25, 63),
        (12, 26, 42),
        (1, 10, 10), // 표지판 없음
      ];

      manager.resetRulesForTest();
      final before = {
        for (final (map, x, y) in coords)
          '$map,$x,$y': manager.getSignMessage(map, x, y),
      };

      await manager.loadData();

      for (final (map, x, y) in coords) {
        expect(
          manager.getSignMessage(map, x, y),
          before['$map,$x,$y'],
          reason: '표지판 불일치: 맵 $map ($x,$y)',
        );
      }

      // 맵 9는 좌표와 무관한 기본 문구를 가진다.
      expect(manager.getSignMessage(9, 5, 5), contains('GAIA TERRA'));
    });

    test('4. JSON이 없으면 내장 규칙으로 동작한다', () async {
      await manager.loadData(bundle: _MissingBundle());

      expect(manager.usingJsonRules, isFalse);
      expect(manager.rulesLoadError, isNotNull);
      // 폴백: 코드 내장 규칙
      expect(manager.findPortal(1, 20, 11)!.targetMapId, 6);
      expect(manager.getSignMessage(2, 31, 44), contains('WIVERN'));
    });

    test('5. 시설 좌표: JSON(facilities.json)과 내장 표가 일치한다', () async {
      // 원작 LORETALK.PAS의 시설 트리거 좌표 (마을별)
      const coords = <(int, int, int)>[
        (6, 8, 71), (6, 14, 69), (6, 14, 73), // CASTLE LORE 무기점
        (6, 87, 14), (6, 86, 12), // 병원
        (6, 21, 12), (6, 25, 13), // 훈련소
        (6, 87, 73), (6, 91, 65), // 식료품점
        (7, 18, 19), (7, 16, 24), // LASTDITCH 훈련소
        (7, 57, 17), (7, 59, 25), // 식료품점
        (7, 59, 56), (7, 59, 60), // 무기점
        (7, 17, 56), (7, 17, 60), // 병원
        (9, 12, 11), (9, 15, 12), // GAIA TERRA 훈련소
        (9, 40, 37), (9, 41, 41), // 식료품점
        (9, 37, 10), (9, 41, 15), // 무기점
        (9, 9, 39), (9, 16, 40), // 병원
        (10, 36, 32), (10, 39, 35), // WATER TOWN 훈련소
        (10, 17, 57), (10, 11, 55), // 식료품점
        (10, 11, 30), (10, 13, 34), // 무기점
        (10, 33, 60), (10, 41, 58), // 병원
        (24, 11, 22), (24, 14, 24), // LAST SHELTER 훈련소
        (24, 33, 35), (24, 41, 38), // 식료품점
        (24, 33, 21), (24, 40, 23), // 무기점
        (24, 15, 36), (24, 14, 40), // 병원
        (1, 0, 0), (6, 0, 0), (7, 0, 0), // 시설 아님
      ];

      manager.resetRulesForTest();
      final before = {
        for (final (map, x, y) in coords)
          '$map,$x,$y': manager.findFacility(map, x, y),
      };

      await manager.loadData();
      expect(manager.usingJsonFacilities, isTrue);

      for (final (map, x, y) in coords) {
        expect(
          manager.findFacility(map, x, y),
          before['$map,$x,$y'],
          reason: '시설 불일치: 맵 $map ($x,$y)',
        );
      }

      // 마을별 시설 코드가 원작과 같다 (1=무기점, 2=병원, 3=훈련소, 4=식료품점)
      expect(manager.findFacility(7, 59, 56), 1);
      expect(manager.findFacility(9, 9, 39), 2);
      expect(manager.findFacility(10, 36, 32), 3);
      expect(manager.findFacility(24, 33, 35), 4);
      // 시설이 없는 좌표는 null
      expect(manager.findFacility(6, 50, 51), isNull);
    });
  });
}

String? _describePortal(PortalInfo? p) {
  if (p == null) return null;
  return '${p.targetMapId}/${p.targetX}/${p.targetY}/${p.name}/${p.scriptId}';
}

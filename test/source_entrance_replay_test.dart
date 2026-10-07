import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_world_manager.dart';
import 'package:lore/logic/lore_ent_procedures.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/logic/lore_portal_session.dart';

class NoEntranceRandom implements Random {
  @override
  int nextInt(int max) => throw StateError('Cancelled entrance consumed RNG');
  @override
  bool nextBool() => throw StateError('Cancelled entrance consumed RNG');
  @override
  double nextDouble() => throw StateError('Cancelled entrance consumed RNG');
}

/// LOREENT.PAS의 load 명령 27곳에서 추출한 실제 진입 좌표 41건을 재생한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('LOREENT.PAS every extracted entry cancels before scripts or RNG', () {
    final fixture = jsonDecode(
      File('test/fixtures/source_entrance_replay.json').readAsStringSync(),
    );
    final scripts = LoreScriptEngine(random: NoEntranceRandom());
    for (final item in fixture['cases']) {
      final portal = LoreEntProcedures.entranceAt(
        item['map'],
        item['x'],
        item['y'],
      )!;
      final plan = LorePortalSession.begin(
        confirmed: false,
        portal: portal,
        context: const ScriptContext(),
        scripts: scripts,
      );
      expect(plan.action, LorePortalAction.cancelled);
      expect(plan.preScript, isNull);
      if (!LoreEntProcedures.isSourceGuardedEntrance(portal.scriptId ?? '')) {
        expect(
          LorePortalSession.begin(
            confirmed: true,
            portal: portal,
            context: const ScriptContext(),
            scripts: scripts,
          ).action,
          LorePortalAction.loadMap,
        );
      }
    }
  });

  test('LOREENT.PAS ground at checks reject every other source coordinate', () {
    final fixture = jsonDecode(
      File('test/fixtures/source_entrance_replay.json').readAsStringSync(),
    );
    for (var map = 1; map <= 5; map++) {
      final points = <(int, int)>{
        for (final item in fixture['cases'])
          if (item['map'] == map) (item['x'] as int, item['y'] as int),
      };
      for (var y = 1; y <= 100; y++) {
        for (var x = 1; x <= 100; x++) {
          expect(
            LoreEntProcedures.entranceAt(map, x, y) != null,
            points.contains((x, y)),
            reason: 'map $map ($x,$y)',
          );
        }
      }
    }
  });

  test('원본 LOREENT 진입 좌표와 실행 중 포털 목적지가 일치한다', () async {
    final data = jsonDecode(
      File('test/fixtures/source_entrance_replay.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final manager = LoreWorldManager.instance;
    manager.resetRulesForTest();
    await manager.loadData();
    for (final raw in data['cases'] as List<dynamic>) {
      final item = raw as Map<String, dynamic>;
      final portal = manager.findPortal(
        item['map'] as int,
        item['x'] as int,
        item['y'] as int,
      );
      expect(portal, isNotNull, reason: 'LOREENT.PAS:${item['line']}');
      expect(
        [portal!.targetMapId, portal.targetX, portal.targetY],
        item['target'],
        reason: 'LOREENT.PAS:${item['line']}',
      );
      final direct = LoreEntProcedures.entranceAt(
        item['map'] as int,
        item['x'] as int,
        item['y'] as int,
      );
      expect(direct, isNotNull, reason: 'direct LOREENT.PAS:${item['line']}');
      expect(
        [direct!.targetMapId, direct.targetX, direct.targetY],
        item['target'],
        reason: 'direct LOREENT.PAS:${item['line']}',
      );
      expect(direct.scriptId, portal.scriptId);
    }
    manager.resetRulesForTest();
  });
}

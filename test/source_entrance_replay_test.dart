import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_world_manager.dart';
import 'package:lore/logic/lore_ent_procedures.dart';

/// LOREENT.PAS의 load 명령 27곳에서 추출한 실제 진입 좌표 41건을 재생한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('원본 LOREENT 진입 좌표와 실행 중 포털 목적지가 일치한다', () async {
    final data = jsonDecode(
      File('test/fixtures/source_entrance_replay.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final manager = LoreWorldManager.instance;
    manager.resetRulesForTest();
    await manager.loadData();
    expect(manager.usingJsonRules, isTrue);
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

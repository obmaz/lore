import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_world_manager.dart';

/// LORESPEC.PAS의 wantexit 목적지를 실제 포털 조회 결과와 비교한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('원본 LORESPEC 출구 21곳의 목적지가 실행 중 포털과 일치한다', () async {
    final data = jsonDecode(
      File('test/fixtures/source_exit_replay.json').readAsStringSync(),
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
      expect(portal, isNotNull, reason: 'LORESPEC.PAS:${item['line']}');
      expect(
        [portal!.targetMapId, portal.targetX, portal.targetY],
        item['target'],
        reason: 'LORESPEC.PAS:${item['line']}',
      );
    }
    manager.resetRulesForTest();
  });
}

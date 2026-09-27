import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_world_manager.dart';
import 'package:lore/logic/lore_portal_session.dart';

void main() {
  final scripts = LoreScriptEngine()
    ..loadFromJson(File('assets/data/scripts.json').readAsStringSync());

  const plain = PortalInfo(
    targetMapId: 2,
    targetX: 10,
    targetY: 10,
    name: 'plain',
  );
  const guarded = PortalInfo(
    targetMapId: 25,
    targetX: 10,
    targetY: 10,
    name: 'guarded',
    scriptId: 'portal-23-25-dungeon',
  );

  test('확인 전에는 스크립트를 실행하지 않고 위치를 유지한다', () {
    final plan = LorePortalSession.begin(
      confirmed: false,
      portal: guarded,
      context: const ScriptContext(),
      scripts: scripts,
    );
    expect(plan.action, LorePortalAction.cancelled);
    expect(plan.preScript, isNull);
  });

  test('진입 전 사건이 없으면 지도 로드로 바로 이어진다', () {
    final plan = LorePortalSession.begin(
      confirmed: true,
      portal: plain,
      context: const ScriptContext(),
      scripts: scripts,
    );
    expect(plan.action, LorePortalAction.loadMap);
  });

  test('원본 수문장 전투는 지도 로드보다 먼저 처리된다', () {
    final plan = LorePortalSession.begin(
      confirmed: true,
      portal: guarded,
      context: const ScriptContext(),
      scripts: scripts,
    );
    expect(plan.action, LorePortalAction.runPreScript);
    expect(plan.preScript?.awaitingBattle, isTrue);
    expect(
      LorePortalSession.afterPreScript(
        completed: false,
        waitingForBattle: true,
        blockMove: false,
      ),
      LorePortalAction.waitForBattle,
    );
    expect(
      LorePortalSession.afterPreScript(
        completed: true,
        waitingForBattle: false,
        blockMove: false,
      ),
      LorePortalAction.loadMap,
    );
  });

  test('진입 전 처리 취소와 이동 차단은 지도를 로드하지 않는다', () {
    expect(
      LorePortalSession.afterPreScript(
        completed: false,
        waitingForBattle: false,
        blockMove: false,
      ),
      LorePortalAction.cancelled,
    );
    expect(
      LorePortalSession.afterPreScript(
        completed: true,
        waitingForBattle: false,
        blockMove: true,
      ),
      LorePortalAction.blocked,
    );
  });
}

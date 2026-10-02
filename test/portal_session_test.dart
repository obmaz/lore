import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_world_manager.dart';
import 'package:lore/logic/lore_portal_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

  test('성 출구 Skeleton 선택은 첫 출구에서만 실행하고 거절해도 방문을 기록한다', () async {
    final world = LoreWorldManager.instance;
    world.resetRulesForTest();
    await world.loadData();
    final exit = world.findPortal(6, 51, 96)!;
    expect(exit.scriptId, 'castle-exit-skeleton');
    final plan = LorePortalSession.begin(
      confirmed: true,
      portal: exit,
      context: const ScriptContext(),
      scripts: scripts,
      x: 51,
      y: 96,
    );
    final first = plan.preScript!.acknowledgeScene();
    expect(plan.action, LorePortalAction.runPreScript);
    expect(first.hasPendingChoice, isTrue);
    expect(first.cancelOptionIndex, 1);
    final accepted = first.choose(0).outcome;
    expect(accepted.recruits.single.key, 'skeleton');
    expect(accepted.setFlags, containsAll(['skeletonJoined', 'etc31_bit1']));
    final declined = first.choose(first.cancelOptionIndex!).outcome;
    expect(declined.recruits, isEmpty);
    expect(declined.setFlags, ['etc31_bit1']);
    final revisit = LorePortalSession.begin(
      confirmed: true,
      portal: exit,
      context: const ScriptContext(flags: {'etc31_bit1'}),
      scripts: scripts,
      x: 51,
      y: 96,
    );
    expect(revisit.action, LorePortalAction.loadMap);
    world.resetRulesForTest();
  });
}

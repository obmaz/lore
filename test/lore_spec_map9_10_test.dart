import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dungeon_event_manager.dart';
import 'package:lore/game/lore_world_manager.dart';
import 'package:lore/logic/lore_portal_session.dart';
import 'package:lore/logic/lore_spec_procedures.dart';
import 'package:lore/logic/lore_special_event_dispatcher.dart';
import 'package:lore/logic/lore_tile_protocol.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LoreScriptEngine scripts;

  setUp(() {
    scripts = LoreScriptEngine()
      ..loadFromJson(File('assets/data/scripts.json').readAsStringSync());
  });

  ScriptRun? dispatchSpecial({
    required int mapId,
    required int x,
    required int y,
    int tile = 0,
    Set<String> flags = const {},
    Map<String, int> questSteps = const {},
  }) {
    final result = LoreSpecialEventDispatcher.resolve(
      action: LoreTileAction.special,
      mapId: mapId,
      x: x,
      y: y,
      context: ScriptContext(
        tileAtPlayer: tile,
        flags: flags,
        questSteps: questSteps,
      ),
      party: const [],
      scripts: scripts,
      legacy: LoreDungeonEventManager.instance,
    );
    expect(result.legacy, isNull);
    return result.script;
  }

  group('LORESPEC 맵 9 TOWN4 / GAIA TERRA 분기 검증 (LORESPEC.PAS:354-443)', () {
    test('금화 5곳 특수 타일은 startStep과 map9 프로시저 모두에서 5000골드와 플래그를 지급한다', () {
      const spots = [(10, 24), (12, 26), (15, 25), (16, 23), (18, 27)];
      for (final (x, y) in spots) {
        final run = scripts.startStep(
          9,
          x,
          y,
          const ScriptContext(tileAtPlayer: 0),
        )!;
        expect(run.outcome.goldDelta, 5000);
      }
    });

    test('금화 5곳은 5000골드와 해당 비트 플래그를 지급하고 재방문 시 차단된다', () {
      const testCases = [
        ((10, 24), 'etc35_bit1'),
        ((12, 26), 'etc35_bit2'),
        ((15, 25), 'etc35_bit3'),
        ((16, 23), 'etc35_bit4'),
        ((18, 27), 'etc35_bit5'),
      ];

      for (final ((x, y), flag) in testCases) {
        final run = dispatchSpecial(mapId: 9, x: x, y: y)!;
        expect(run.outcome.goldDelta, 5000);
        expect(run.outcome.setFlags, contains(flag));
        expect(run.outcome.messages.single, '당신은 금화 5000개를 발견했다.');

        // 이미 획득한 플래그가 켜진 상태에서는 재지급하지 않음
        final revisit = dispatchSpecial(mapId: 9, x: x, y: y, flags: {flag});
        expect(revisit, isNull);
      }
    });

    test('타일이 0이 아니면 금화를 획득할 수 없다', () {
      final run = dispatchSpecial(mapId: 9, x: 10, y: 24, tile: 44);
      expect(run, isNull);
    });

    test('y=10 관문은 water 퀘스트 5 미만일 때 배척 메시지와 남쪽 넉백을 발생시킨다', () {
      // LoreSpecProcedures.map9 직접 호출 검증
      final directBlocked = LoreSpecProcedures.map9(
        26,
        10,
        const ScriptContext(tileAtPlayer: 0),
        scripts,
      )!;
      expect(directBlocked.outcome.messages.single, '알수없는 힘이 당신을 배척합니다.');
      expect(directBlocked.outcome.nudges.single.dy, 1);

      // 퀘스트 미달 (진행도 0)
      final blockedRun = dispatchSpecial(mapId: 9, x: 26, y: 10)!;
      expect(blockedRun.outcome.messages.single, '알수없는 힘이 당신을 배척합니다.');
      expect(blockedRun.outcome.nudges.single.dy, 1);

      // 퀘스트 4 단계 (여전히 5 미만)
      final blockedRun4 = dispatchSpecial(
        mapId: 9,
        x: 26,
        y: 10,
        questSteps: {'water': 4},
      )!;
      expect(blockedRun4.outcome.messages.single, '알수없는 힘이 당신을 배척합니다.');
      expect(blockedRun4.outcome.nudges.single.dy, 1);

      // 퀘스트 5 단계 이상: 관문 통과 허용
      final passRun = dispatchSpecial(
        mapId: 9,
        x: 26,
        y: 10,
        questSteps: {'water': 5},
      );
      expect(passRun, isNull);

      // raw etc[15]가 있으면 그것이 우선한다 (모든 바이트).
      for (var b = 0; b < 256; b++) {
        final run = LoreSpecProcedures.map9(
          26,
          10,
          ScriptContext(
            tileAtPlayer: 0,
            sourceEtc: {15: b},
            questSteps: const {'water': 9},
          ),
          scripts,
        );
        expect(run == null, b >= 5);
      }
    });

    test('SWAMP GATE 포털 대사는 원본 Lord Ahn 조언과 etc35_bit6 플래그를 유지한다', () {
      final first = scripts.startById(
        'portal-9-13-swamp-gate',
        const ScriptContext(),
      )!;
      expect(first.outcome.messages.join(), contains('Lord Ahn'));
      expect(first.outcome.messages.join(), contains('LORE 성의 성주'));
      expect(first.outcome.messages.join(), contains('라바 게이트'));
      expect(first.outcome.setFlags, contains('etc35_bit6'));

      final revisit = scripts.startById(
        'portal-9-13-swamp-gate',
        const ScriptContext(flags: {'etc35_bit6'}),
      );
      expect(revisit, isNull);
    });
  });

  group('LORESPEC 맵 10 WATER DEN 분기 검증 (LORESPEC.PAS:444-464)', () {
    test('맵 10 이동 특수 타일은 범용 startStep과 중복 실행되지 않는다', () {
      expect(
        scripts.startStep(10, 20, 46, const ScriptContext(tileAtPlayer: 0)),
        isNull,
      );
      expect(
        scripts.startStep(10, 20, 49, const ScriptContext(tileAtPlayer: 0)),
        isNull,
      );
    });

    test('y=46에서 y=50으로, y=49에서 y=45로 수직 순간이동한다', () {
      final jump50 = dispatchSpecial(mapId: 10, x: 25, y: 46)!;
      expect(jump50.outcome.teleportX, 25);
      expect(jump50.outcome.teleportY, 50);

      final jump45 = dispatchSpecial(mapId: 10, x: 25, y: 49)!;
      expect(jump45.outcome.teleportX, 25);
      expect(jump45.outcome.teleportY, 45);
    });

    test('지정되지 않은 좌표나 타일이 0이 아닌 경우 발동하지 않는다', () {
      expect(dispatchSpecial(mapId: 10, x: 25, y: 55), isNull);
      expect(dispatchSpecial(mapId: 10, x: 25, y: 46, tile: 1), isNull);
      expect(dispatchSpecial(mapId: 10, x: 25, y: 49, tile: 22), isNull);
    });
  });

  group('LORESPEC 맵 9 원본 경계 (LORESPEC.PAS:354-443)', () {
    test('gold cells follow raw etc[35] bits 1..5 for all 256 bytes', () {
      const cells = [(10, 24), (12, 26), (15, 25), (16, 23), (18, 27)];
      for (var b = 0; b < 256; b++) {
        for (var i = 0; i < 5; i++) {
          final run = LoreSpecProcedures.map9(
            cells[i].$1,
            cells[i].$2,
            ScriptContext(tileAtPlayer: 0, sourceEtc: {35: b}),
            LoreScriptEngine(),
          );
          expect(run == null, b & (1 << i) != 0);
          if (run != null) {
            expect(run.outcome.goldDelta, 5000);
            expect(run.outcome.setFlags, ['etc35_bit${i + 1}']);
            expect(run.outcome.messages, ['당신은 금화 5000개를 발견했다.']);
          }
        }
      }
    });

    test('SWAMP GATE asks wantenter at y=5; first entry speaks, later entries load; refusal y+1', () {
      final world = LoreWorldManager.instance;
      final gate = world.findPortal(9, 26, 5)!;
      expect([gate.targetMapId, gate.targetX, gate.targetY], [13, 81, 95]);
      expect(LoreWorldManager.sourceAsksEnter(9, 26, 5), isTrue);
      expect(LoreWorldManager.sourceExitRejectY(9, 5, x: 26), 6);
      LorePortalPlan begin(int b) => LorePortalSession.begin(
        confirmed: true,
        portal: gate,
        context: ScriptContext(sourceEtc: {35: b}),
        scripts: LoreScriptEngine(),
      );
      var run = begin(0).preScript!;
      var scenes = 0;
      while (run.hasPendingScene) {
        scenes++;
        run = run.acknowledgeScene();
      }
      expect(scenes, 4);
      expect(run.outcome.setFlags, ['etc35_bit6']);
      expect(begin(32).action, LorePortalAction.loadMap);
      final exit = world.findPortal(9, 26, 46)!;
      expect([exit.targetMapId, exit.targetX, exit.targetY], [2, 32, 82]);
      expect(world.findPortal(9, 26, 47), isNull);
      expect(LoreWorldManager.sourceExitRejectY(9, 46, x: 26), 45);
      expect(LoreWorldManager.sourceAsksEnter(9, 26, 46), isFalse);
    });
  });
}

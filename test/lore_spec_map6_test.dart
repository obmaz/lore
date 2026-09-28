import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dungeon_event_manager.dart';
import 'package:lore/game/lore_world_manager.dart';
import 'package:lore/logic/lore_portal_session.dart';
import 'package:lore/logic/lore_special_event_dispatcher.dart';
import 'package:lore/logic/lore_tile_protocol.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LoreScriptEngine scripts;
  setUp(() {
    scripts = LoreScriptEngine()
      ..loadFromJson(File('assets/data/scripts.json').readAsStringSync());
  });

  ScriptRun? dispatchMap6(
    int x,
    int y, {
    int tile = 0,
    Set<String> flags = const {},
  }) {
    final result = LoreSpecialEventDispatcher.resolve(
      action: LoreTileAction.special,
      mapId: 6,
      x: x,
      y: y,
      context: ScriptContext(tileAtPlayer: tile, flags: flags),
      party: const [],
      scripts: scripts,
      legacy: LoreDungeonEventManager.instance,
    );
    expect(result.legacy, isNull);
    return result.script;
  }

  group('LORESPEC 맵 6 분기 통합 검증 (LORESPEC.PAS:190-305)', () {
    test('특수 타일 좌표는 범용 startStep과 중복 실행되지 않는다', () {
      for (final (x, y) in const [
        (62, 82),
        (51, 12),
        (52, 12),
        (41, 79),
      ]) {
        expect(
          scripts.startStep(6, x, y, const ScriptContext(tileAtPlayer: 0)),
          isNull,
          reason: '($x, $y)는 LoreSpecProcedures.map6에서 단일 관리되어야 한다',
        );
      }
    });

    test('1. 상자 분기 (62, 82): 금 1000 지급 후 타일 44로 변경', () {
      final first = dispatchMap6(62, 82, tile: 0);
      expect(first, isNotNull);
      expect(first!.script.id, 'spec-6-L190');
      expect(first.outcome.goldDelta, 1000);
      expect(first.outcome.tileChanges.single,
          (map: null, x: 62, y: 82, tile: 44, ifZero: null));

      // 타일이 44로 변경된 후에는 이벤트 미발생
      final revisit = dispatchMap6(62, 82, tile: 44);
      expect(revisit, isNull);
    });

    test('2. 감옥 전투 분기 (51, 12 / 52, 12): Mad Joe 미구출 시 미발생', () {
      for (final x in [51, 52]) {
        final run = dispatchMap6(x, 12, tile: 0, flags: {});
        expect(run, isNull, reason: 'Mad Joe를 구출하지 않았으면 병사 전투가 발생하지 않음');
      }
    });

    test('2. 감옥 전투 분기 (51, 12 / 52, 12): 첫 조우 시 Soldier 2마리 및 플래그 설정', () {
      for (final x in [51, 52]) {
        final run = dispatchMap6(x, 12, tile: 0, flags: {'madJoeJoined'});
        expect(run, isNotNull);
        expect(run!.script.id, 'prison-battle-first');
        expect(run.awaitingBattle, isTrue);
        expect(run.outcome.battleMonsters, [26, 26]);
        expect(run.outcome.battleTitle, 'Soldier');
        expect(run.outcome.battleEnemyFirst, isTrue);
        expect(run.outcome.setFlags, contains('prisonBattleStarted'));
        expect(run.outcome.messages.first,
            contains('아니! 당신이 우리들을 배신하고 죄수를 풀어주다니'));

        // 전투 승리 후속 스텝 결과 확인
        final victory = run.continueAfterBattle().outcome;
        expect(victory.messages, contains('당신들은 수감소 병사들을 물리쳤다.'));
        expect(victory.setFlags, contains('prisonBattleDone'));
        expect(
          victory.tileChanges,
          containsAll([
            (map: null, x: 51, y: 12, tile: 44, ifZero: null),
            (map: null, x: 52, y: 12, tile: 44, ifZero: null),
            (map: null, x: 50, y: 11, tile: 44, ifZero: null),
            (map: null, x: 53, y: 11, tile: 44, ifZero: null),
          ]),
        );
      }
    });

    test('2. 감옥 전투 분기 (51, 12 / 52, 12): 재방문 시 Soldier 7마리 전투', () {
      final run = dispatchMap6(
        51,
        12,
        tile: 0,
        flags: {'madJoeJoined', 'prisonBattleStarted'},
      );
      expect(run, isNotNull);
      expect(run!.script.id, 'prison-battle-return');
      expect(run.awaitingBattle, isTrue);
      expect(run.outcome.battleMonsters, [26, 26, 26, 26, 26, 26, 26]);
      expect(run.outcome.messages.first, contains('다시 돌아오다니'));

      final victory = run.continueAfterBattle().outcome;
      expect(victory.messages, contains('당신들은 수감소 병사들을 물리쳤다.'));
      expect(victory.setFlags, contains('prisonBattleDone'));
    });

    test('2. 감옥 전투 분기 (51, 12 / 52, 12): 완료 후 또는 일반 바닥에서는 미발생', () {
      expect(
        dispatchMap6(
          51,
          12,
          tile: 0,
          flags: {'madJoeJoined', 'prisonBattleDone'},
        ),
        isNull,
      );
      expect(
        dispatchMap6(
          51,
          12,
          tile: 44,
          flags: {'madJoeJoined'},
        ),
        isNull,
      );
    });

    test('3. 무기실 분기 (41, 79): 3칸 후퇴 연출, 타일 44 변경 및 기본 무기 지급', () {
      final first = dispatchMap6(41, 79, tile: 0, flags: {});
      expect(first, isNotNull);
      expect(first!.script.id, 'lore-weapon-room');
      expect(first.outcome.setFlags, contains('weaponRoomVisited'));
      expect(first.outcome.tileChanges.single,
          (map: 6, x: 41, y: 79, tile: 44, ifZero: null));

      // 서쪽으로 3칸 넉백 (-1, 0)
      expect(first.outcome.nudges.length, 3);
      expect(
        first.outcome.nudges,
        equals([
          (dx: -1, dy: 0),
          (dx: -1, dy: 0),
          (dx: -1, dy: 0),
        ]),
      );

      expect(first.outcome.messages.first, contains('가장 기본적인 무기로'));
      final weaponEquip = first.outcome.equips.single;
      expect(weaponEquip.kind, 'weapon');
      expect(weaponEquip.index, 1);
      expect(weaponEquip.power, 5);
      expect(weaponEquip.onlyUnarmed, isTrue);

      // 재방문 시 미발생
      expect(
        dispatchMap6(41, 79, tile: 0, flags: {'weaponRoomVisited'}),
        isNull,
      );
      expect(
        dispatchMap6(41, 79, tile: 44, flags: {}),
        isNull,
      );
    });

    test('4. 출구 분기: 성 출구 Skeleton 영입 제안 및 방문 플래그 연동', () async {
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
      );
      final first = plan.preScript!;
      expect(first.hasPendingChoice, isTrue);
      expect(first.outcome.messages.first,
          contains('당신이 LORE 성을 떠나려는 순간 누군가가 당신을 불렀다.'));
      expect(first.outcome.messages[1], contains('나는 Skeleton이라 불리는'));

      // 수락 시
      final accepted = first.choose(0).outcome;
      expect(accepted.recruits.single.key, 'skeleton');
      expect(accepted.setFlags, containsAll(['skeletonJoined', 'etc31_bit1']));

      // 거절 시
      final declined = first.choose(1).outcome;
      expect(declined.recruits, isEmpty);
      expect(declined.setFlags, ['etc31_bit1']);
      expect(declined.messages.last, '그렇다면 당신의 뜻대로 하시오.');

      world.resetRulesForTest();
    });
  });
}

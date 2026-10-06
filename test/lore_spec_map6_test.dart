import 'support/legacy_json_fixture_engine.dart';

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_world_manager.dart';
import 'package:lore/logic/lore_portal_session.dart';
import 'package:lore/logic/lore_spec_procedures.dart';
import 'package:lore/logic/lore_special_event_dispatcher.dart';
import 'package:lore/logic/lore_tile_protocol.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LegacyJsonFixtureEngine scripts;
  setUp(() {
    scripts = LegacyJsonFixtureEngine()
      ..loadFromJson(
        File('test/fixtures/legacy_rules/scripts.json').readAsStringSync(),
      );
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
    );

    return result.script;
  }

  group('LORESPEC 맵 6 분기 통합 검증 (LORESPEC.PAS:190-305)', () {
    test('특수 타일 좌표는 범용 startStep과 중복 실행되지 않는다', () {
      for (final (x, y) in const [(62, 82), (51, 12), (52, 12), (41, 79)]) {
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
      expect(first.outcome.tileChanges.single, (
        map: null,
        x: 62,
        y: 82,
        tile: 44,
        ifZero: null,
      ));

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

    test('2. 감옥: 첫 조우는 bit3을 먼저 켜고 Soldier1..2, 승리 시 네 칸을 연다', () {
      for (final x in [51, 52]) {
        final run = dispatchMap6(x, 12, tile: 0, flags: {'madJoeJoined'})!;
        expect(run.script.id, 'prison-battle-first');
        expect(run.outcome.setFlags, isEmpty);
        expect(run.acknowledgeScene().outcome.setFlags, ['etc50_bit3']);
        expect(run.pendingScene!.lines.first, ' 아니! 당신이 우리들을 배신하고 죄수를 풀어');
        final battle = run.acknowledgeScene();
        expect(battle.outcome.battleMonsters, [26, 26]);
        expect(battle.outcome.battleEnemyFirst, isTrue);
        expect(battle.outcome.battleOverrides.map((o) => o['name']), [
          'Soldier1',
          'Soldier2',
        ]);
        expect(
          battle.outcome.battleOverrides.every(
            (o) =>
                o['eNumber'] == 1 && o['special'] == 0 && o['castLevel'] == 0,
          ),
          isTrue,
        );
        final won = battle.continueAfterBattle();
        expect(won.pendingScene!.lines, ['당신들은 수감소 병사들을 물리쳤다.']);
        final after = won.acknowledgeScene().outcome;
        expect(after.tileChanges.map((t) => [t.x, t.y, t.tile]), [
          [51, 12, 44],
          [52, 12, 44],
          [50, 11, 44],
          [53, 11, 44],
        ]);
        expect(battle.continueAfterRunAway().outcome.tileChanges, isEmpty);
      }
    });

    test('2. 감옥: bit3 이후 방문은 player[1] 이름과 Soldier1..7', () {
      final run = dispatchMap6(
        51,
        12,
        tile: 0,
        flags: {'madJoeJoined', 'prisonBattleStarted'},
      )!;
      expect(run.script.id, 'prison-battle-return');
      expect(
        run.pendingScene!.withPartyNames(['아린']).lines.first,
        ' 다시 돌아오다니, 아린',
      );
      final battle = run.acknowledgeScene();
      expect(battle.outcome.battleMonsters, List.filled(7, 26));
      expect(battle.outcome.battleOverrides.last['name'], 'Soldier7');
    });

    test('2. 감옥: raw etc[50] bit2/bit3이 판정하고 열린 칸(44)은 특수 칸이 아니다', () {
      for (var b = 0; b < 256; b++) {
        final run = LoreSpecProcedures.map6(
          51,
          12,
          ScriptContext(
            tileAtPlayer: 0,
            sourceEtc: {50: b},
            flags: const {'madJoeJoined'},
          ),
          scripts,
        );
        if (b & 2 == 0) {
          expect(run, isNull);
          continue;
        }
        expect(
          run!.script.id,
          b & 4 != 0 ? 'prison-battle-return' : 'prison-battle-first',
        );
      }
      expect(dispatchMap6(51, 12, tile: 44, flags: {'madJoeJoined'}), isNull);
    });

    test('3. 무기실 분기 (41, 79): bit4, 3칸 후퇴, 타일 44, 기본 무기', () {
      final first = dispatchMap6(41, 79, tile: 0, flags: {})!;
      expect(first.script.id, 'lore-weapon-room');
      expect(first.outcome.setFlags, ['etc50_bit4']);
      expect(first.outcome.nudges, [
        (dx: -1, dy: 0),
        (dx: -1, dy: 0),
        (dx: -1, dy: 0),
      ]);
      expect(first.outcome.tileChanges.single, (
        map: null,
        x: 41,
        y: 79,
        tile: 44,
        ifZero: null,
      ));
      expect(first.pendingScene!.lines.first, contains('가장 기본적인 무기로'));
      final weaponEquip = first.acknowledgeScene().outcome.equips.single;
      expect(weaponEquip.kind, 'weapon');
      expect(weaponEquip.index, 1);
      expect(weaponEquip.power, 5);
      expect(weaponEquip.onlyUnarmed, isTrue);
      expect(
        dispatchMap6(41, 79, tile: 0, flags: {'weaponRoomVisited'}),
        isNull,
      );
      expect(dispatchMap6(41, 79, tile: 44, flags: {}), isNull);
    });

    test(
      '4. 출구: 다른 모든 특수 칸이 wantexit, Skeleton은 첫 출구에만, 계단 쓰기 후 합류 제안',
      () async {
        final world = LoreWorldManager.instance;
        world.resetRulesForTest();
        await world.loadData();
        final exit = world.findPortal(6, 51, 96)!;
        expect(exit.scriptId, 'castle-exit-skeleton');
        expect(world.findPortal(6, 62, 82), isNull);
        expect(LoreWorldManager.sourceExitRejectY(6, 96, x: 51), 95);

        final plan = LorePortalSession.begin(
          confirmed: true,
          portal: exit,
          context: const ScriptContext(sourceEtc: {31: 0}),
          scripts: scripts,
          x: 51,
          y: 96,
        );
        final called = plan.preScript!;
        expect(
          called.pendingScene!.lines.single,
          ' 당신이 LORE 성을 떠나려는 순간 누군가가 당신을 불렀다.',
        );
        final first = called.acknowledgeScene();
        expect(first.outcome.tileChanges.map((t) => [t.x, t.y, t.tile]), [
          [51, 91, 44],
          [51, 92, 48],
          [51, 92, 44],
          [51, 93, 48],
          [51, 93, 44],
          [51, 94, 48],
          [51, 94, 44],
          [51, 95, 48],
        ]);
        expect(first.hasPendingChoice, isTrue);
        expect(first.cancelOptionIndex, 1);
        final accepting = first.choose(0).acknowledgeConditionRefresh();
        expect(accepting.pendingScene!.lines, isEmpty);
        expect(accepting.outcome.setFlags, isNot(contains('etc31_bit1')));
        final accepted = accepting.acknowledgeScene().outcome;
        expect(accepted.recruits.single.key, 'skeleton');
        expect(
          accepted.setFlags,
          containsAll(['skeletonJoined', 'etc31_bit1']),
        );
        final declining = first.choose(1);
        expect(declining.pendingScene!.lines, ['당신이 바란다면 ...']);
        expect(declining.outcome.setFlags, isNot(contains('etc31_bit1')));
        final declined = declining.acknowledgeScene().outcome;
        expect(declined.recruits, isEmpty);
        expect(declined.setFlags, ['etc31_bit1']);
        expect(declined.messages.last, '당신이 바란다면 ...');
        expect(
          LorePortalSession.begin(
            confirmed: true,
            portal: exit,
            context: const ScriptContext(sourceEtc: {31: 1}),
            scripts: scripts,
            x: 51,
            y: 96,
          ).action,
          LorePortalAction.loadMap,
        );
        world.resetRulesForTest();
      },
    );
  });
}

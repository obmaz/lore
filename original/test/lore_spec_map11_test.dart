
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/logic/lore_spec_procedures.dart';
import 'package:lore/logic/lore_special_event_dispatcher.dart';
import 'package:lore/logic/lore_tile_protocol.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LoreScriptEngine scripts;

  setUp(() {
    scripts = LoreScriptEngine();
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

    );

    return result.script;
  }

  group('LORESPEC 맵 11 TOWN5 / LORE KEEP 분기 검증 (LORESPEC.PAS:465-559)', () {
    test('금화 7곳은 5000골드와 해당 비트 플래그를 지급하고 재방문 시 차단된다', () {
      const testCases = [
        ((20, 30), 'etc33_bit1'),
        ((18, 36), 'etc33_bit2'),
        ((35, 32), 'etc33_bit3'),
        ((33, 36), 'etc33_bit4'),
        ((35, 14), 'etc33_bit5'),
        ((14, 16), 'etc33_bit6'),
        ((37, 12), 'etc33_bit7'),
      ];

      for (final ((x, y), flag) in testCases) {
        // LoreSpecProcedures.map11 직접 실행
        final direct = LoreSpecProcedures.map11(
          x,
          y,
          const ScriptContext(tileAtPlayer: 0),
          scripts,
        )!;
        expect(direct.outcome.goldDelta, 5000);
        expect(direct.outcome.setFlags, contains(flag));
        expect(direct.outcome.messages.single, '당신은 금화 5000개를 발견했다.');

        // Dispatcher 연동 실행
        final run = dispatchSpecial(mapId: 11, x: x, y: y)!;
        expect(run.outcome.goldDelta, 5000);
        expect(run.outcome.setFlags, contains(flag));

        // 획득 후 재방문 차단
        final revisit = dispatchSpecial(mapId: 11, x: x, y: y, flags: {flag});
        expect(revisit, isNull);
      }
    });

    test('타일이 0이 아니면 금화를 획득할 수 없다', () {
      final run = dispatchSpecial(mapId: 11, x: 20, y: 30, tile: 44);
      expect(run, isNull);
    });

    test('y=44에서 오이디푸스의 창을 획득하고 플래그 획득 후에는 재발동하지 않는다', () {
      final found = dispatchSpecial(mapId: 11, x: 25, y: 44)!;
      expect(found.pendingScene!.lines, ['당신은 어떤 창을 발견했다.']);
      expect(found.outcome.equips, isEmpty);
      final spearRun = found.acknowledgeScene().acknowledgeScene();
      expect(spearRun.outcome.equips.single.kind, 'weapon');
      expect(spearRun.outcome.equips.single.index, 3);
      expect(spearRun.outcome.equips.single.power, 12);
      expect(spearRun.outcome.equips.single.prompt, isTrue);
      expect(spearRun.outcome.setFlags, ['etc33_bit8']);
      expect(spearRun.outcome.messages.last, '누가 오이디푸스의 창을 다루겠습니까 ?');

      // 이미 획득한 경우 (oedipusSpearTaken 또는 etc33_bit8)
      expect(
        dispatchSpecial(mapId: 11, x: 25, y: 44, flags: {'oedipusSpearTaken'}),
        isNull,
      );
      expect(
        dispatchSpecial(mapId: 11, x: 25, y: 44, flags: {'etc33_bit8'}),
        isNull,
      );
    });

    test('y=24 미이라의 방은 lastditch 퀘스트 단계가 1일 때만 전투가 발동한다', () {
      // 퀘스트 단계 1: Sphinx 2명 + Major Mummy 1명
      final mummyRun = dispatchSpecial(
        mapId: 11,
        x: 30,
        y: 24,
        questSteps: {'lastditch': 1},
      )!;
      expect(mummyRun.pendingScene!.lines, ['당신은 미이라의 방을 발견했다.']);
      final battle = mummyRun.acknowledgeScene();
      expect(battle.outcome.battleMonsters, [35, 35, 26]);
      expect(battle.awaitingBattle, isTrue);
      // Escape with the Major Mummy dead counts as the source success.
      final won = battle.continueAfterRunAway(defeatedEnemySlots: {3});
      expect(won.pendingScene!.lines.first, '당신들은 Major Mummy 물리쳤다.');
      final done = won.acknowledgeScene();
      expect(done.outcome.questChanges.single.inc, 1);
      final fled = battle.continueAfterRunAway(defeatedEnemySlots: {1, 2});
      expect(
        fled.hasPendingScene || fled.outcome.questChanges.isNotEmpty,
        isFalse,
      );
      // LORESPEC.PAS:551 tests `enemy[3].hp <= 0`, not `dead`: an
      // unconscious Major Mummy (hp <= 0, alive) is enough.
      final down = battle.continueAfterRunAway(
        defeatedEnemySlots: const {},
        hpZeroEnemySlots: {3},
      );
      expect(down.pendingScene!.lines.first, '당신들은 Major Mummy 물리쳤다.');

      // 퀘스트 단계 0 또는 2 이상: 발동하지 않음
      expect(
        dispatchSpecial(mapId: 11, x: 30, y: 24, questSteps: {'lastditch': 0}),
        isNull,
      );
      expect(
        dispatchSpecial(mapId: 11, x: 30, y: 24, questSteps: {'lastditch': 2}),
        isNull,
      );
    });

    test('특수 사건이 없는 좌표는 null을 반환한다', () {
      expect(dispatchSpecial(mapId: 11, x: 10, y: 10), isNull);
    });
  });

  test('raw etc[33] bits decide gold and the spear for all 256 bytes', () {
    const cells = [
      (20, 30),
      (18, 36),
      (35, 32),
      (33, 36),
      (35, 14),
      (14, 16),
      (37, 12),
    ];
    for (var b = 0; b < 256; b++) {
      ScriptRun? at(int x, int y) => LoreSpecProcedures.map11(
        x,
        y,
        ScriptContext(
          tileAtPlayer: 0,
          sourceEtc: {33: b},
          flags: const {'oedipusSpearTaken'},
        ),
        LoreScriptEngine(),
      );
      for (var i = 0; i < 7; i++) {
        expect(at(cells[i].$1, cells[i].$2) == null, b & (1 << i) != 0);
      }
      expect(at(25, 44) == null, b & 128 != 0);
    }
  });
}

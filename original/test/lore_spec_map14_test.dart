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

  group('LORESPEC 맵 14 DEN1 / SWAMP DEN 분기 검증 (LORESPEC.PAS:814-878)', () {
    test('MENACE 중심 (25,8), (26,8)은 lordahn 퀘스트 단계가 3일 때 발동하여 4로 진행한다', () {
      // LoreSpecProcedures.map14 직접 호출 검증
      final direct = LoreSpecProcedures.map14(
        25,
        8,
        const ScriptContext(questSteps: {'lordahn': 3}),
        scripts,
      )!;
      expect(direct.outcome.messages.any((m) => m.contains("MENACE")), isTrue);

      // 퀘스트 단계 3이 아닐 때
      final notReady = dispatchSpecial(
        mapId: 14,
        x: 25,
        y: 8,
        questSteps: {'lordahn': 2},
      );
      expect(notReady, isNull);

      // 퀘스트 단계 3일 때 (25, 8)
      final run25 = dispatchSpecial(
        mapId: 14,
        x: 25,
        y: 8,
        questSteps: {'lordahn': 3},
      )!;
      expect(run25.outcome.messages.any((m) => m.contains("MENACE")), isTrue);
      expect(
        run25.acknowledgeScene().outcome.questChanges.any(
          (q) => q.name == 'lordahn' && q.set == 4,
        ),
        isTrue,
      );

      // 퀘스트 단계 3일 때 (26, 8)
      final run26 = dispatchSpecial(
        mapId: 14,
        x: 26,
        y: 8,
        questSteps: {'lordahn': 3},
      )!;
      expect(run26.outcome.messages.any((m) => m.contains("MENACE")), isTrue);
      expect(
        run26.acknowledgeScene().outcome.questChanges.any(
          (q) => q.name == 'lordahn' && q.set == 4,
        ),
        isTrue,
      );
    });

    test('금화 6곳은 원작 비트 플래그에 의해 1회만 획득된다', () {
      final chests = [
        (6, 6, 'etc32_bit1', 1000),
        (18, 10, 'etc32_bit2', 2500),
        (6, 44, 'etc32_bit3', 400),
        (31, 30, 'etc32_bit4', 600),
        (31, 8, 'etc32_bit5', 1500),
        (14, 28, 'etc32_bit6', 1000),
      ];

      for (final (x, y, flag, gold) in chests) {
        // 미획득 상태
        final run = dispatchSpecial(mapId: 14, x: x, y: y)!;
        expect(run.outcome.goldDelta, gold);
        expect(run.outcome.setFlags, contains(flag));
        expect(run.outcome.messages.any((m) => m.contains('$gold')), isTrue);

        // 이미 획득한 상태
        final rerun = dispatchSpecial(mapId: 14, x: x, y: y, flags: {flag});
        expect(rerun, isNull);
      }
    });

    test('황금의 방패 (16,20)는 etc32_bit7에 의해 1회만 제공된다', () {
      // 미획득 상태
      final run = dispatchSpecial(mapId: 14, x: 16, y: 20)!;
      expect(run.outcome.messages.any((m) => m.contains('황금의 방패')), isTrue);
      expect(run.outcome.equips, isEmpty);
      final waiting = run.acknowledgeScene();
      expect(waiting.pendingConditionRefresh, isTrue);
      expect(waiting.outcome.setFlags, isEmpty);
      final taken = waiting.acknowledgeConditionRefresh();
      expect(taken.outcome.equips.single.kind, 'shield');
      expect(taken.outcome.setFlags, contains('etc32_bit7'));

      // 이미 획득한 상태
      final rerun = dispatchSpecial(
        mapId: 14,
        x: 16,
        y: 20,
        flags: {'etc32_bit7'},
      );
      expect(rerun, isNull);
    });

    test('특수 사건 위치가 아닌 곳은 null을 반환한다', () {
      final normal = dispatchSpecial(mapId: 14, x: 10, y: 10);
      expect(normal, isNull);

      final blockedTile = dispatchSpecial(mapId: 14, x: 6, y: 6, tile: 99);
      expect(blockedTile, isNull);
    });
  });

  test('raw etc[32] bits and etc[10] decide map 14 for all 256 bytes', () {
    const cells = [
      (6, 6),
      (18, 10),
      (6, 44),
      (31, 30),
      (31, 8),
      (14, 28),
      (16, 20),
    ];
    for (var b = 0; b < 256; b++) {
      for (var i = 0; i < 7; i++) {
        final run = LoreSpecProcedures.map14(
          cells[i].$1,
          cells[i].$2,
          ScriptContext(tileAtPlayer: 0, sourceEtc: {32: b}),
          LoreScriptEngine(),
        );
        expect(run == null, b & (1 << i) != 0);
      }
      final menace = LoreSpecProcedures.map14(
        25,
        8,
        ScriptContext(
          tileAtPlayer: 0,
          sourceEtc: {10: b},
          questSteps: const {'lordahn': 3},
        ),
        LoreScriptEngine(),
      );
      expect(menace == null, b != 3);
    }
    expect(
      LoreSpecProcedures.map14(
        25,
        46,
        const ScriptContext(tileAtPlayer: 0),
        LoreScriptEngine(),
      ),
      isNull,
    );
  });
}

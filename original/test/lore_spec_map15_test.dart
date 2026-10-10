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

  group('LORESPEC 맵 15 T_DEN3 / QUAKE DEN 분기 검증 (LORESPEC.PAS:879-965)', () {
    test('y=48 상자는 첫 방문 6000골드, 둘째 방문 4000골드를 지급하고 타일을 44로 바꾼다', () {
      // LoreSpecProcedures.map15 직접 호출 검증
      final directFirst = LoreSpecProcedures.map15(
        10,
        48,
        const ScriptContext(),
        scripts,
      )!;
      expect(directFirst.outcome.goldDelta, 6000);
      expect(directFirst.outcome.setFlags, contains('etc36_bit1'));
      expect(
        directFirst.outcome.tileChanges.any(
          (t) => t.x == 10 && t.y == 48 && t.tile == 44,
        ),
        isTrue,
      );

      // 1회차: 6000골드
      final first = dispatchSpecial(mapId: 15, x: 10, y: 48)!;
      expect(first.outcome.goldDelta, 6000);
      expect(first.outcome.setFlags, contains('etc36_bit1'));
      expect(
        first.outcome.tileChanges.any(
          (t) => t.x == 10 && t.y == 48 && t.tile == 44,
        ),
        isTrue,
      );
      expect(
        first.outcome.tileChanges.any(
          (t) => t.x == 10 && t.y == 47 && t.tile == 44,
        ),
        isTrue,
      );

      // 2회차: etc36_bit1 설정 시 4000골드
      final second = dispatchSpecial(
        mapId: 15,
        x: 40,
        y: 48,
        flags: {'etc36_bit1'},
      )!;
      expect(second.outcome.goldDelta, 4000);
      expect(second.outcome.setFlags, contains('etc36_bit2'));
      expect(
        second.outcome.tileChanges.any(
          (t) => t.x == 40 && t.y == 48 && t.tile == 44,
        ),
        isTrue,
      );

      // 3회차: etc36_bit2 설정 시 발동 안 함
      final third = dispatchSpecial(
        mapId: 15,
        x: 11,
        y: 48,
        flags: {'etc36_bit1', 'etc36_bit2'},
      );
      expect(third, isNull);
    });

    test('황금의 방패 (14,7)는 etc36_bit3에 의해 1회만 제공된다', () {
      final run = dispatchSpecial(mapId: 15, x: 14, y: 7)!;
      expect(run.outcome.messages.any((m) => m.contains('황금의 방패')), isTrue);
      expect(run.outcome.setFlags, isEmpty);
      expect(
        run.acknowledgeScene().acknowledgeConditionRefresh().outcome.setFlags,
        contains('etc36_bit3'),
      );

      final rerun = dispatchSpecial(
        mapId: 15,
        x: 14,
        y: 7,
        flags: {'etc36_bit3'},
      );
      expect(rerun, isNull);
    });

    test('황금의 갑옷 (45,19)는 etc36_bit4에 의해 1회만 제공된다', () {
      final run = dispatchSpecial(mapId: 15, x: 45, y: 19)!;
      expect(run.outcome.messages.any((m) => m.contains('황금의 갑옷')), isTrue);
      expect(run.outcome.setFlags, isEmpty);
      expect(
        run.acknowledgeScene().acknowledgeConditionRefresh().outcome.setFlags,
        contains('etc36_bit4'),
      );

      final rerun = dispatchSpecial(
        mapId: 15,
        x: 45,
        y: 19,
        flags: {'etc36_bit4'},
      );
      expect(rerun, isNull);
    });

    test('y=27 ArchiGagoyle 전투는 gaia 퀘스트 단계가 4일 때 발동한다', () {
      // 퀘스트 조건 불충족
      final notReady = dispatchSpecial(
        mapId: 15,
        x: 20,
        y: 27,
        questSteps: {'gaia': 3},
      );
      expect(notReady, isNull);

      // 퀘스트 조건 충족 (gaia == 4)
      final battle = dispatchSpecial(
        mapId: 15,
        x: 20,
        y: 27,
        questSteps: {'gaia': 4},
      )!.acknowledgeScene();
      expect(battle.awaitingBattle, isTrue);
      expect(battle.outcome.battleMonsters, [36, 36, 42]);
      expect(
        battle.outcome.messages.any((m) => m.contains('ArchiGagoyle')),
        isTrue,
      );

      final victory = battle.continueAfterBattle().acknowledgeScene();
      expect(
        victory.outcome.questChanges.any((q) => q.name == 'gaia' && q.inc == 1),
        isTrue,
      );
      expect(victory.outcome.messages.any((m) => m.contains('물리쳤다')), isTrue);

      // 이미 승리하여 퀘스트 단계가 5가 된 경우
      final done = dispatchSpecial(
        mapId: 15,
        x: 20,
        y: 27,
        questSteps: {'gaia': 5},
      );
      expect(done, isNull);
    });

    test('특수 사건 위치가 아닌 곳은 null을 반환한다', () {
      final normal = dispatchSpecial(mapId: 15, x: 1, y: 1);
      expect(normal, isNull);
    });
  });

  test(
    'raw etc[36]: gold 6000 then 4000 at any of the four cells, equipment bits',
    () {
      for (var b = 0; b < 256; b++) {
        ScriptRun? at(int x, int y) => LoreSpecProcedures.map15(
          x,
          y,
          ScriptContext(tileAtPlayer: 0, sourceEtc: {36: b}),
          LoreScriptEngine(),
        );
        for (final x in [10, 11, 40, 41]) {
          final run = at(x, 48);
          if (b & 2 != 0) {
            expect(run, isNull);
            continue;
          }
          final first = b & 1 == 0;
          expect(run!.outcome.goldDelta, first ? 6000 : 4000);
          expect(run.outcome.setFlags, [first ? 'etc36_bit1' : 'etc36_bit2']);
          expect(run.outcome.messages, [
            '당신은 금화 ${first ? 6000 : 4000}개를 발견했다.',
          ]);
        }
        expect(at(14, 7) == null, b & 4 != 0);
        expect(at(45, 19) == null, b & 8 != 0);
      }
      expect(
        LoreSpecProcedures.map15(
          25,
          71,
          const ScriptContext(tileAtPlayer: 0),
          LoreScriptEngine(),
        ),
        isNull,
      );
    },
  );
}

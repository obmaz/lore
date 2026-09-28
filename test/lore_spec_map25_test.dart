import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dungeon_event_manager.dart';
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

  group('LORESPEC 맵 25 K_DEN2 / CASTLE KEEP 분기 검증 (LORESPEC.PAS:1995-2103)', () {
    test('y=43 금속 수호자 조우 및 횃불·전투·전직(class 10) 시퀀스 검증', () {
      final runDirect = LoreSpecProcedures.map25(
        25,
        43,
        const ScriptContext(tileAtPlayer: 0),
        scripts,
      )!;
      expect(runDirect.outcome.torchLit, isTrue);
      expect(
        runDirect.outcome.messages,
        contains(' 금속으로된 어떤 적이 나타났다.'),
      );
      expect(runDirect.awaitingBattle, isTrue);
      expect(runDirect.outcome.battleMonsters, [66, 66, 66, 66, 71]);

      final runDispatcher = dispatchSpecial(
        mapId: 25,
        x: 25,
        y: 43,
        tile: 0,
      )!;
      expect(runDispatcher.awaitingBattle, isTrue);

      final defeated = LoreSpecProcedures.map25(
        25,
        43,
        const ScriptContext(tileAtPlayer: 0, flags: {'keep3MetalGuardianCleared'}),
        scripts,
      );
      expect(defeated, isNull);
    });

    test('(15, 34) 및 (36, 34) 비밀 통로 개방 분기 검증', () {
      final run15 = LoreSpecProcedures.map25(
        15,
        34,
        const ScriptContext(tileAtPlayer: 0),
        scripts,
      )!;
      expect(run15.outcome.tileChanges.any((t) => t.x == 15 && t.y == 34 && t.tile == 41), isTrue);

      final run36 = LoreSpecProcedures.map25(
        36,
        34,
        const ScriptContext(tileAtPlayer: 0),
        scripts,
      )!;
      expect(run36.outcome.tileChanges.any((t) => t.x == 36 && t.y == 34 && t.tile == 41), isTrue);
    });

    test('(5, 34) 및 (46, 34) 레버 조작 및 최종 방 입구 개방 분기 검증', () {
      // 1. 레버 A 처음 당김
      final runAFirst = LoreSpecProcedures.map25(
        5,
        34,
        const ScriptContext(tileAtPlayer: 0),
        scripts,
      )!;
      expect(runAFirst.outcome.setFlags, contains('etc45_bit7'));
      expect(runAFirst.outcome.tileChanges, isEmpty);

      // 2. 레버 B (레버 A가 이미 당겨진 상태) -> 문 개방
      final runBSecond = LoreSpecProcedures.map25(
        46,
        34,
        const ScriptContext(tileAtPlayer: 0, flags: {'etc45_bit7'}),
        scripts,
      )!;
      expect(runBSecond.outcome.setFlags, contains('etc45_bit8'));
      expect(runBSecond.outcome.tileChanges.any((t) => t.x == 25 && t.y == 27 && t.tile == 54), isTrue);
      expect(runBSecond.outcome.tileChanges.any((t) => t.x == 26 && t.y == 27 && t.tile == 54), isTrue);

      // 3. 디스패처로도 정상 실행
      final runBDispatcher = dispatchSpecial(
        mapId: 25,
        x: 46,
        y: 34,
        tile: 0,
        flags: {'etc45_bit7'},
      )!;
      expect(runBDispatcher.outcome.tileChanges.any((t) => t.x == 25 && t.y == 27 && t.tile == 54), isTrue);
    });
  });
}

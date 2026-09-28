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

  group('LORESPEC 맵 16 DEN2 / TYPHOON DEN 분기 검증 (LORESPEC.PAS:966-1004)', () {
    test('y=10 Wivern 조우는 wivern 퀘스트 단계(남은 수)에 따라 3, 2, 1마리가 등장하고 전멸 후 시체만 남는다', () {
      // LoreSpecProcedures.map16 직접 호출 검증 (0마리 처치 시 3마리 조우)
      final direct = LoreSpecProcedures.map16(
        20,
        10,
        const ScriptContext(),
        scripts,
      )!;
      expect(direct.awaitingBattle, isTrue);
      expect(direct.outcome.battleMonsters, [43, 43, 43]);
      expect(direct.outcome.messages.any((m) => m.contains('세마리')), isTrue);

      // 단계 0: 3마리 조우
      final battle3 = dispatchSpecial(
        mapId: 16,
        x: 20,
        y: 10,
        questSteps: {'wivern': 0},
      )!;
      expect(battle3.awaitingBattle, isTrue);
      expect(battle3.outcome.battleMonsters, [43, 43, 43]);
      expect(battle3.outcome.messages.any((m) => m.contains('세마리')), isTrue);

      // 단계 1: 2마리 조우
      final battle2 = dispatchSpecial(
        mapId: 16,
        x: 20,
        y: 10,
        questSteps: {'wivern': 1},
      )!;
      expect(battle2.awaitingBattle, isTrue);
      expect(battle2.outcome.battleMonsters, [43, 43]);
      expect(battle2.outcome.messages.any((m) => m.contains('두마리')), isTrue);

      // 단계 2: 1마리 조우
      final battle1 = dispatchSpecial(
        mapId: 16,
        x: 20,
        y: 10,
        questSteps: {'wivern': 2},
      )!;
      expect(battle1.awaitingBattle, isTrue);
      expect(battle1.outcome.battleMonsters, [43]);
      expect(battle1.outcome.messages.any((m) => m.contains('한마리')), isTrue);

      // 단계 3: 모두 처치 후 시체 메시지
      final cleared = dispatchSpecial(
        mapId: 16,
        x: 20,
        y: 10,
        questSteps: {'wivern': 3},
      )!;
      expect(cleared.awaitingBattle, isFalse);
      expect(cleared.outcome.messages.any((m) => m.contains('시체만이')), isTrue);
    });

    test('특수 사건 위치가 아닌 곳은 null을 반환한다', () {
      final normal = dispatchSpecial(mapId: 16, x: 20, y: 15);
      expect(normal, isNull);
    });
  });
}

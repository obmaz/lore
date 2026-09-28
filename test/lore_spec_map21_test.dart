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

  group('LORESPEC 맵 21 KEEP1 / SWAMP KEEP 분기 검증 (LORESPEC.PAS:1760-1815)', () {
    test('(25, 20) 라바 게이트 관문은 2개 봉인 미해제 시 밀어내고 통과를 막는다', () {
      // 1. 봉인 미해제 시 (둘 다 미해제)
      final blockedBoth = LoreSpecProcedures.map21(
        25,
        20,
        const ScriptContext(tileAtPlayer: 0),
        scripts,
      )!;
      expect(
        blockedBoth.outcome.messages,
        contains(' 당신은 아직 라바 게이트를 열수가 없다'),
      );
      expect(blockedBoth.outcome.nudges.first.dy, 1);

      // 2. 디스패처를 통한 진입 검증
      final runDispatcher = dispatchSpecial(
        mapId: 21,
        x: 25,
        y: 20,
        tile: 0,
      )!;
      expect(
        runDispatcher.outcome.messages,
        contains(' 당신은 아직 라바 게이트를 열수가 없다'),
      );
      expect(runDispatcher.outcome.nudges.first.dy, 1);

      // 3. 한쪽만 해제된 경우 (etc40_bit1 만 있음) -> 여전히 막힘
      final blockedOne = LoreSpecProcedures.map21(
        25,
        20,
        const ScriptContext(tileAtPlayer: 0, flags: {'etc40_bit1'}),
        scripts,
      )!;
      expect(
        blockedOne.outcome.messages,
        contains(' 당신은 아직 라바 게이트를 열수가 없다'),
      );
      expect(blockedOne.outcome.nudges.first.dy, 1);

      // 4. 둘 다 해제된 경우 (etc40_bit1, etc41_bit1) -> 이벤트 없이 통과 허용 (null)
      final opened = LoreSpecProcedures.map21(
        25,
        20,
        const ScriptContext(
          tileAtPlayer: 0,
          flags: {'etc40_bit1', 'etc41_bit1'},
        ),
        scripts,
      );
      expect(opened, isNull);

      final openedAliased = LoreSpecProcedures.map21(
        25,
        20,
        const ScriptContext(
          tileAtPlayer: 0,
          flags: {'evilSealRoomCleared', 'den7MazeCleared'},
        ),
        scripts,
      );
      expect(openedAliased, isNull);
    });

    test('그 밖의 특수 타일에서 몬스터 58번 3~6마리와 타일 변형이 실행된다', () {
      final run = dispatchSpecial(mapId: 21, x: 20, y: 20, tile: 52)!;
      expect(run.script.id, 'keep1-special-ambush');
      expect(run.awaitingBattle, isTrue);
      expect(run.outcome.battleMonsters.length, inInclusiveRange(3, 6));
      expect(run.outcome.battleMonsters.every((id) => id == 58), isTrue);
      expect(run.continueAfterBattle().outcome.playerTiles,
          contains((tile: 46, ifZero: 40)));
      expect(dispatchSpecial(mapId: 21, x: 20, y: 46, tile: 52), isNull);
      expect(dispatchSpecial(mapId: 21, x: 25, y: 20, tile: 52,
          flags: {'etc40_bit1', 'etc41_bit1'}), isNull);
    });
  });
}

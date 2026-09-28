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

  group('LORESPEC 맵 23 KEEP3 / DUNGEON OF EVIL 분기 검증 (LORESPEC.PAS:1880-1979)', () {
    test('y=26 가짜 네크로맨서 및 도플갱어 2단계 전투 시퀀스 검증', () {
      final runDirect = LoreSpecProcedures.map23(
        25,
        26,
        const ScriptContext(tileAtPlayer: 52),
        scripts,
      )!;
      expect(
        runDirect.outcome.messages,
        contains(' 잘도 여기까지 찾아왔구나.'),
      );
      expect(runDirect.awaitingBattle, isTrue);
      expect(runDirect.outcome.battleMirrorParty, isTrue);

      final runDispatcher = dispatchSpecial(
        mapId: 23,
        x: 25,
        y: 26,
        tile: 52,
      )!;
      expect(runDispatcher.awaitingBattle, isTrue);

      final defeated = LoreSpecProcedures.map23(
        25,
        26,
        const ScriptContext(tileAtPlayer: 52, flags: {'keep3NecromancerCleared'}),
        scripts,
      );
      expect(defeated, isNull);
    });

    test('(25, 27) 레버 조작 및 감추어진 성 부상 지형 변형 분기 검증', () {
      final runTrap = LoreSpecProcedures.map23(
        25,
        27,
        const ScriptContext(tileAtPlayer: 52),
        scripts,
      )!;
      expect(
        runTrap.outcome.messages,
        contains(' 푯말에 쓰여 있는 대로 이 곳의 레버를 당겼 '),
      );
      expect(
        runTrap.outcome.setFlags,
        contains('keep3TrapCleared'),
      );
      expect(
        runTrap.outcome.tileChanges.any((t) => t.x == 25 && t.y == 27 && t.tile == 46),
        isTrue,
      );

      final runDispatcher = dispatchSpecial(
        mapId: 23,
        x: 25,
        y: 27,
        tile: 52,
      )!;
      expect(runDispatcher.outcome.messages, contains(' 푯말에 쓰여 있는 대로 이 곳의 레버를 당겼 '));

      final completed = LoreSpecProcedures.map23(
        25,
        27,
        const ScriptContext(tileAtPlayer: 52, flags: {'keep3TrapCleared'}),
        scripts,
      );
      expect(completed, isNull);
    });
  });
}

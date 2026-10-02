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

  group(
    'LORESPEC 맵 23 KEEP3 / DUNGEON OF EVIL 분기 검증 (LORESPEC.PAS:1880-1979)',
    () {
      test('y=26 가짜 네크로맨서: 장면 두 개 뒤 환상(미러) 전투로 이어지고 정리 플래그는 무시한다', () {
        final run = LoreSpecProcedures.map23(
          25,
          26,
          const ScriptContext(tileAtPlayer: 52),
          scripts,
        )!;
        expect(run.pendingScene!.lines.first, ' 잘도 여기까지 찾아왔구나 ');
        expect(run.pendingScene!.appendPartyNameSuffix, '.');
        expect(run.awaitingBattle, isFalse);
        final battle = run.acknowledgeScene().acknowledgeScene();
        expect(battle.awaitingBattle, isTrue);
        expect(battle.outcome.battleMirrorParty, isTrue);
        expect(battle.outcome.battleEnemyFirst, isTrue);

        final viaDispatcher = dispatchSpecial(
          mapId: 23,
          x: 25,
          y: 26,
          tile: 52,
        )!;
        expect(viaDispatcher.hasPendingScene, isTrue);

        // 원본에는 격파 플래그가 없다. 재방문은 맵 타일이 판정한다.
        final stale = LoreSpecProcedures.map23(
          25,
          26,
          const ScriptContext(
            tileAtPlayer: 52,
            flags: {'keep3NecromancerCleared'},
          ),
          scripts,
        );
        expect(stale, isNotNull);
        // LORESPEC.PAS:1881 `if map[x,y] = 0 then exit`.
        expect(
          LoreSpecProcedures.map23(
            12,
            26,
            const ScriptContext(tileAtPlayer: 0),
            scripts,
          ),
          isNull,
        );
      });

      test('(25, 27) 레버: 맵을 먼저 쓰고 대사를 출력하며 별도 완료 플래그를 만들지 않는다', () {
        final run = LoreSpecProcedures.map23(
          25,
          27,
          const ScriptContext(tileAtPlayer: 52),
          scripts,
        )!;
        expect(run.pendingScene!.lines, contains(' 푯말에 쓰여 있는 대로 이 곳의 레버를 당겼 '));
        expect(run.outcome.setFlags, isEmpty);
        expect(
          run.outcome.tileChanges.any(
            (t) => t.x == 25 && t.y == 27 && t.tile == 46,
          ),
          isTrue,
        );

        final viaDispatcher = dispatchSpecial(
          mapId: 23,
          x: 25,
          y: 27,
          tile: 52,
        )!;
        expect(viaDispatcher.pendingScene!.lines, run.pendingScene!.lines);

        final stale = LoreSpecProcedures.map23(
          25,
          27,
          const ScriptContext(tileAtPlayer: 52, flags: {'keep3TrapCleared'}),
          scripts,
        );
        expect(stale, isNotNull);
      });
    },
  );
}

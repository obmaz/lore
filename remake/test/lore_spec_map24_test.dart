
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

  group(
    'LORESPEC 맵 24 K_DEN1 / LAST SHELTER 분기 검증 (LORESPEC.PAS:1980-1994)',
    () {
      test('맵 24 내부 좌표에서는 LORESPEC 특수 타일 이벤트가 없으며 포털로만 처리된다', () {
        final direct = LoreSpecProcedures.map24(
          25,
          25,
          const ScriptContext(tileAtPlayer: 0),
          scripts,
        );
        expect(direct, isNull);

        final dispatched = dispatchSpecial(mapId: 24, x: 25, y: 25, tile: 0);
        expect(dispatched, isNull);
      });
    },
  );
}

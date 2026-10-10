import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_world_manager.dart';
import 'package:lore/logic/lore_talk_dispatcher.dart';

void main() {
  LoreTalkDispatch resolve(int map, int x, int y) => LoreTalkDispatcher.resolve(
    mapId: map,
    x: x,
    y: y,
    context: const ScriptContext(),
    world: LoreWorldManager.instance,
    scripts: LoreScriptEngine(),
  );
  test(
    'LORETALK.PAS facility coordinates select native facilities without assets',
    () {
      expect(resolve(6, 8, 71).source, LoreTalkSource.facility);
      expect(resolve(6, 8, 71).facility, 1);
    },
  );
  test('LORETALK.PAS complete talkmode owns all town and pyramid speech', () {
    for (final (map, x, y) in [
      (6, 40, 15),
      (7, 37, 41),
      (10, 40, 56),
      (6, 51, 28),
      (7, 38, 17),
      (9, 42, 25),
      (24, 33, 10),
      (27, 21, 12),
    ]) {
      final selected = resolve(map, x, y);
      expect(selected.source, LoreTalkSource.procedure);
      expect(selected.procedure, LoreTalkProcedure.talkMode);
    }
    expect(resolve(10, 25, 18).procedure, LoreTalkProcedure.waterFieldLord);
  });
  test('An unspecified original map has no fallback NPC speech', () {
    expect(resolve(2, 11, 11).source, LoreTalkSource.none);
  });
}

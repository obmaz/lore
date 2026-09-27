import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dungeon_event_manager.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/logic/lore_special_event_dispatcher.dart';
import 'package:lore/logic/lore_tile_protocol.dart';
import 'package:lore/logic/script_world_reducer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LoreScriptEngine scripts;
  setUp(() {
    scripts = LoreScriptEngine()
      ..loadFromJson(File('assets/data/scripts.json').readAsStringSync());
  });

  ScriptRun selected(int x, int y, Set<String> flags) {
    final result = LoreSpecialEventDispatcher.resolve(
      action: LoreTileAction.special,
      mapId: 4,
      x: x,
      y: y,
      context: ScriptContext(tileAtPlayer: 0, flags: flags),
      party: const [],
      scripts: scripts,
      legacy: LoreDungeonEventManager.instance,
    );
    expect(result.legacy, isNull);
    return result.script!;
  }

  test('LORESPEC 맵 4 Draconian은 완료 여부를 먼저, 독심술을 다음에 검사한다', () {
    for (final (x, y) in const [(40, 18), (26, 16), (20, 39)]) {
      expect(
        scripts.startStep(4, x, y, const ScriptContext(tileAtPlayer: 0)),
        isNull,
        reason: '원본형 절차와 JSON 자동 선택이 동시에 실행되면 안 된다',
      );
    }
    final lecture = selected(26, 16, {});
    expect(lecture.script.id, 'spec-4-L37-1');
    expect(lecture.hasPendingChoice, isFalse);
    expect(lecture.outcome.recruits, isEmpty);

    final offer = selected(26, 16, {'etc5'});
    expect(offer.script.id, 'spec-4-L37-2');
    expect(offer.hasPendingChoice, isTrue);
    final accepted = offer.choose(0).outcome;
    expect(accepted.recruits.single, (key: 'draconian', slot: 4));
    expect(accepted.setFlags, contains('draconianMet'));
    expect(offer.choose(1).outcome.recruits, isEmpty);
    expect(offer.choose(1).outcome.setFlags, isNot(contains('draconianMet')));

    for (final flags in [
      {'draconianMet'},
      {'draconianMet', 'etc5'},
    ]) {
      final empty = selected(26, 16, flags);
      expect(empty.script.id, 'spec-4-L37-3');
      expect(empty.outcome.blockMove, isTrue);
      expect(empty.outcome.recruits, isEmpty);
    }
  });

  test('Ancient Evil 첫 방문은 원본의 마지막 (16,15) 위치를 복원한다', () async {
    final map = await LoreMapData.loadFromAsset('SWAMP', category: 'ground');
    final first = selected(20, 39, {});
    expect(first.script.id, 'ancient-evil-first');
    expect(
      first.outcome.events.where((event) => event.kind == 'peek'),
      hasLength(3),
    );
    expect(first.outcome.teleportX, 16);
    expect(first.outcome.teleportY, 15);
    expect(first.outcome.setFlags, contains('ancientEvilMet'));
    final after = ScriptWorldReducer.applyMap(
      ScriptMapState(mapId: 4, x: 20, y: 39, direction: 0, grid: map.grid),
      first.outcome,
    );
    expect((after.x, after.y), (16, 15));

    final revisit = selected(20, 39, {'ancientEvilMet'});
    expect(revisit.script.id, 'ancient-evil-later');
    expect((revisit.outcome.teleportX, revisit.outcome.teleportY), (46, 41));
    expect(selected(40, 18, {}).outcome.teleportX, 46);
  });
}

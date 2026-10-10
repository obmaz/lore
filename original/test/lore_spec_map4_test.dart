import 'support/legacy_json_fixture_engine.dart';

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/logic/lore_spec_procedures.dart';
import 'package:lore/logic/lore_special_event_dispatcher.dart';
import 'package:lore/logic/lore_tile_protocol.dart';
import 'package:lore/logic/script_world_reducer.dart';

/// LORESPEC.PAS:37-189 (map 4) and the map 6 chest at LORESPEC.PAS:190-195.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LegacyJsonFixtureEngine scripts;
  setUp(() {
    scripts = LegacyJsonFixtureEngine()
      ..loadFromJson(
        File('test/fixtures/legacy_rules/scripts.json').readAsStringSync(),
      );
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
    );

    return result.script!;
  }

  ScriptRun drain(ScriptRun run) {
    while (run.hasPendingScene) {
      run = run.acknowledgeScene();
    }
    return run;
  }

  test('LORESPEC 맵 4 Draconian은 완료 여부를 먼저, 독심술을 다음에 검사한다', () {
    for (final (x, y) in const [(40, 18), (26, 16), (20, 39)]) {
      expect(
        scripts.startStep(4, x, y, const ScriptContext(tileAtPlayer: 0)),
        isNull,
        reason: '원본형 절차와 JSON 자동 선택이 동시에 실행되면 안 된다',
      );
    }
    final lecture = drain(selected(26, 16, {}));
    expect(lecture.script.id, 'spec-4-L37-1');
    expect(lecture.hasPendingChoice, isFalse);
    expect(lecture.outcome.recruits, isEmpty);

    final offer = drain(selected(26, 16, {'etc5'}));
    expect(offer.script.id, 'spec-4-L37-2');
    expect(offer.hasPendingChoice, isTrue);
    final accepted = offer.choose(0).acknowledgeConditionRefresh().outcome;
    final recruit = accepted.recruits.single;
    expect((recruit.key, recruit.slot), ('draconian', 4));
    expect(recruit.cancelSteps, isEmpty);
    expect(accepted.setFlags, contains('draconianMet'));
    expect(offer.choose(1).outcome.recruits, isEmpty);
    expect(offer.choose(1).outcome.setFlags, isNot(contains('draconianMet')));

    for (final flags in [
      {'draconianMet'},
      {'draconianMet', 'etc5'},
    ]) {
      final empty = drain(selected(26, 16, flags));
      expect(empty.script.id, 'spec-4-L37-3');
      // Source `exit` ends the procedure; the party stays on the tile.
      expect(empty.outcome.messages.last, ' 그러나, 아무도 살고 있지 않았다.');
      expect(empty.outcome.recruits, isEmpty);
    }
  });

  test('Ancient Evil 첫 방문은 원본의 마지막 (16,15) 위치를 복원한다', () async {
    final map = await LoreMapData.loadFromAsset('SWAMP', category: 'ground');
    final first = drain(selected(20, 39, {}));
    expect(first.script.id, 'ancient-evil-first');
    // scroll(FALSE) at (48,57) and (82,16); (16,15) is the final position.
    expect(
      first.outcome.events.where((event) => event.kind == 'peek'),
      hasLength(2),
    );
    expect(first.outcome.teleportX, 16);
    expect(first.outcome.teleportY, 15);
    expect(first.outcome.setFlags, contains('ancientEvilMet'));
    final after = ScriptWorldReducer.applyMap(
      ScriptMapState(mapId: 4, x: 20, y: 39, direction: 0, grid: map.grid),
      first.outcome,
    );
    expect((after.x, after.y), (16, 15));

    final revisit = drain(selected(20, 39, {'ancientEvilMet'}));
    expect(revisit.script.id, 'ancient-evil-later');
    expect((revisit.outcome.teleportX, revisit.outcome.teleportY), (46, 41));
    expect(selected(40, 18, {}).outcome.teleportX, 46);
  });

  test('LORESPEC 맵 6 상자는 한 번만 보상하고 타일을 일반 바닥으로 바꾼다', () {
    LoreSpecialEventDispatch chest(int tile) =>
        LoreSpecialEventDispatcher.resolve(
          action: LoreTileAction.special,
          mapId: 6,
          x: 62,
          y: 82,
          context: ScriptContext(tileAtPlayer: tile),
          party: const [],
          scripts: scripts,
        );

    expect(
      scripts.startStep(6, 62, 82, const ScriptContext(tileAtPlayer: 0)),
      isNull,
    );
    final first = chest(0);

    expect(first.script!.script.id, 'spec-6-L190');
    expect(first.script!.outcome.goldDelta, 1000);
    expect(first.script!.outcome.tileChanges.single, (
      map: null,
      x: 62,
      y: 82,
      tile: 44,
      ifZero: null,
    ));
    expect(chest(44).script, isNull);
  });

  test('raw etc[16] bits and etc[5] decide the Draconian and Ancient Evil branches', () {
    for (var b = 0; b < 256; b++) {
      for (final mind in [0, 1, 200]) {
        final run = drain(
          LoreSpecProcedures.map4(
            26,
            16,
            ScriptContext(tileAtPlayer: 0, sourceEtc: {16: b, 5: mind}),
            scripts,
          )!,
        );
        final id = b & 2 != 0
            ? 'spec-4-L37-3'
            : mind == 0
            ? 'spec-4-L37-1'
            : 'spec-4-L37-2';
        expect(run.script.id, id);
      }
      final ae = LoreSpecProcedures.map4(
        20,
        39,
        ScriptContext(tileAtPlayer: 0, sourceEtc: {16: b}),
        scripts,
      )!;
      expect(
        ae.script.id,
        b & 1 != 0 ? 'ancient-evil-later' : 'ancient-evil-first',
      );
    }
    final offer = drain(
      LoreSpecProcedures.map4(
        26,
        16,
        const ScriptContext(tileAtPlayer: 0, sourceEtc: {16: 0, 5: 3}),
        scripts,
      )!,
    );
    expect(offer.choiceTexts, ['저도 바라던 차입니다', '별로 좋지는 않군요']);
    expect(offer.hasCancelSteps, isFalse);
    expect(
      offer.choose(0).acknowledgeConditionRefresh().outcome.setFlags,
      contains('etc16_bit2'),
    );
  });
}

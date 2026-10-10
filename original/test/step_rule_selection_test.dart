import 'support/legacy_json_fixture_engine.dart';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/game/lore_world_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('모든 활성 발걸음 규칙은 자신의 조건에서 선택된다', () async {
    final engine = LegacyJsonFixtureEngine()
      ..loadFromJson(File('test/fixtures/legacy_rules/scripts.json').readAsStringSync());
    final maps = <int, LoreMapData>{};
    const earlierProgress = <String, Set<String>>{
      'keep1-seal-gate-b': {'sealPuzzleA'},
      'den7-master-y13': {'den7DragonsCleared'},
      'den7-return-y13': {'den7DragonsCleared', 'den7MudmenCleared'},
    };
    for (final entry in LoreWorldManager.mapRegistry.entries) {
      maps[entry.key] = await LoreMapData.loadFromAsset(
        entry.value.fileName,
        category: entry.value.category.name,
      );
    }

    final unselected = <String>[];
    for (final script in engine.scripts.where(
      (script) => script.trigger == 'step' && !script.disabled,
    )) {
      final require = script.require;
      final flags = <String>{
        ?require.flag,
        ...require.allFlags,
        ...?earlierProgress[script.id],
      };
      final quests = <String, int>{};
      for (final quest in require.quests) {
        quests[quest.name] = quest.eq ?? quest.gte ?? 0;
      }
      final context = ScriptContext(
        flags: flags,
        partyNames: {?require.partyMember},
        enteredFromMap: require.enteredFromMap,
        mindReadActive: require.mindRead,
        maxEspLevel: require.minEspLevel ?? 0,
        tileAtPlayer: require.tileAtPlayerZero ? 0 : require.tileAtPlayerValue,
        moveDy: require.moveDyNot == 0 ? 1 : 0,
        questSteps: quests,
      );
      final map = maps[script.map]!;
      var selected = false;
      for (var y = 5; y < map.ymax - 3 && !selected; y++) {
        for (var x = 5; x < map.xmax - 3; x++) {
          if (!script.matches('step', script.map, x, y)) continue;
          if (engine.find('step', script.map, x, y, context)?.id == script.id) {
            selected = true;
            break;
          }
        }
      }
      if (!selected) unselected.add(script.id);
    }
    expect(unselected, isEmpty);
  });

  test('보스 전투 후속은 별도 발걸음 규칙 대신 같은 전투에서 이어진다', () {
    final engine = LegacyJsonFixtureEngine()
      ..loadFromJson(File('test/fixtures/legacy_rules/scripts.json').readAsStringSync());
    final hidra = engine.startStep(
      17,
      22,
      30,
      const ScriptContext(questSteps: {'water': 1}),
    )!;
    expect(hidra.script.id, 'spec-17-L1010-1xx');
    expect(hidra.awaitingBattle, isTrue);
    expect(hidra.continueAfterRunAway().outcome.nudges, [(dx: 1, dy: 0)]);
    expect(
      hidra.continueAfterBattle().outcome.questChanges,
      contains((name: 'water', set: 2, inc: null)),
    );

    final dragon = engine.startStep(
      18,
      31,
      30,
      const ScriptContext(questSteps: {'water': 3}),
    )!;
    expect(dragon.script.id, 'spec-18-L1174-1xxxx');
    expect(dragon.awaitingBattle, isTrue);
    final escaped = dragon.continueAfterRunAway().outcome;
    expect((escaped.teleportX, escaped.teleportY), (25, 94));
    expect(escaped.questChanges, isEmpty);
    expect(
      dragon.continueAfterBattle().outcome.questChanges,
      contains((name: 'water', set: 4, inc: null)),
    );

    for (final id in const [
      'spec-11-L465-2x',
      'spec-11-L465-3x',
      'spec-15-L879-2xxxx',
      'spec-15-L879-3',
      'spec-17-L1010-3',
      'spec-17-L1010-4',
      'spec-17-L1010-5',
      'spec-17-L1010-6',
      'spec-18-L1174-3x',
      'spec-18-L1174-4x',
      'spec-18-L1174-5x',
      'spec-18-L1174-6x',
    ]) {
      expect(
        engine.scripts.singleWhere((script) => script.id == id).disabled,
        isTrue,
        reason: id,
      );
    }
  });

  test('KEEP2 남쪽 범위는 실제 지도 이동 경계 바깥이다', () async {
    final map = await LoreMapData.loadFromAsset('KEEP2', category: 'keep');
    final engine = LegacyJsonFixtureEngine()
      ..loadFromJson(File('test/fixtures/legacy_rules/scripts.json').readAsStringSync());
    final fragment = engine.scripts.singleWhere(
      (script) => script.id == 'keep2-ambush-zone-b',
    );
    expect(fragment.disabled, isTrue);
    expect(fragment.yMin, greaterThanOrEqualTo(map.ymax - 3));
  });
}

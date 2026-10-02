import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dungeon_event_manager.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/logic/lore_special_event_dispatcher.dart';
import 'package:lore/logic/lore_tile_protocol.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LoreScriptEngine scripts;
  final legacy = LoreDungeonEventManager.instance;
  final flags = LoreDialogueManager.instance;

  setUp(() {
    scripts = LoreScriptEngine()
      ..loadFromJson(File('assets/data/scripts.json').readAsStringSync());
    flags.collectedTreasures.clear();
  });
  tearDown(() => flags.collectedTreasures.clear());

  test('기존 금화 좌표 18곳은 모두 JSON 사건으로 처리한다', () {
    for (final site in LoreDungeonEventManager.goldSites) {
      final result = LoreSpecialEventDispatcher.resolve(
        action: LoreTileAction.special,
        mapId: site.mapId,
        x: site.x,
        y: site.y,
        context: const ScriptContext(),
        party: const [],
        scripts: scripts,
        legacy: legacy,
      );
      expect(
        result.script?.outcome.goldDelta,
        site.amount,
        reason: '${site.mapId} (${site.x},${site.y})',
      );
      expect(result.legacy, isNull);
    }
    expect(flags.collectedTreasures, isEmpty);
  });

  test('JSON 획득 플래그가 켜진 뒤 옛 처리기로 금화를 다시 주지 않는다', () {
    final first = LoreSpecialEventDispatcher.resolve(
      action: LoreTileAction.special,
      mapId: 9,
      x: 10,
      y: 24,
      context: const ScriptContext(),
      party: const [],
      scripts: scripts,
      legacy: legacy,
    );
    expect(first.script?.outcome.goldDelta, 5000);
    expect(first.script?.outcome.setFlags, contains('etc35_bit1'));

    final revisit = LoreSpecialEventDispatcher.resolve(
      action: LoreTileAction.special,
      mapId: 9,
      x: 10,
      y: 24,
      context: const ScriptContext(flags: {'etc35_bit1'}),
      party: const [],
      scripts: scripts,
      legacy: legacy,
    );
    expect(revisit.script, isNull);
    expect(revisit.legacy, isNull);
    expect(flags.collectedTreasures, isEmpty);
  });

  test('직접 이식한 지도는 JSON이 없어도 레거시 사건을 쓰지 않는다', () {
    final unavailable = LoreScriptEngine();
    final result = LoreSpecialEventDispatcher.resolve(
      action: LoreTileAction.special,
      mapId: 9,
      x: 10,
      y: 24,
      context: const ScriptContext(),
      party: const [],
      scripts: unavailable,
      legacy: legacy,
    );
    expect(result.legacy, isNull);
    expect(result.script!.outcome.goldDelta, 5000);

    final nonSpecial = LoreSpecialEventDispatcher.resolve(
      action: LoreTileProtocol.classify('ground', 48),
      mapId: 1,
      x: 94,
      y: 68,
      context: const ScriptContext(),
      party: const [],
      scripts: unavailable,
      legacy: legacy,
    );
    expect(nonSpecial.script, isNull);
    expect(nonSpecial.legacy, isNull);
  });

  test('LORESPEC 맵 1은 JSON 가용성과 무관하게 원본형 절차 한쪽만 실행한다', () {
    for (final engine in [scripts, LoreScriptEngine()]) {
      final result = LoreSpecialEventDispatcher.resolve(
        action: LoreTileAction.special,
        mapId: 1,
        x: 42,
        y: 84,
        context: const ScriptContext(tileAtPlayer: 0),
        party: const [],
        scripts: engine,
        legacy: legacy,
      );
      expect(result.script?.script.id, 'lorespec-map1-food');
      expect(result.script?.outcome.foodDelta, 100);
      expect(result.legacy, isNull);
    }
  });
}

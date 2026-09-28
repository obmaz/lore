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
    int tile = 52,
    Set<String> flags = const {},
  }) {
    final result = LoreSpecialEventDispatcher.resolve(
      action: LoreTileAction.special,
      mapId: mapId,
      x: x,
      y: y,
      context: ScriptContext(
        tileAtPlayer: tile,
        flags: flags,
      ),
      party: const [],
      scripts: scripts,
      legacy: LoreDungeonEventManager.instance,
    );
    expect(result.legacy, isNull);
    return result.script;
  }

  group('LORESPEC 맵 13 SWAMP FIELD 분기 검증 (LORESPEC.PAS:669-813)', () {
    test('(76..86, 71..81) 피라미드 시퀀스는 특수 타일 52에서 발동한다', () {
      // LoreSpecProcedures.map13 직접 호출 검증
      final direct = LoreSpecProcedures.map13(
        80,
        71,
        const ScriptContext(tileAtPlayer: 52),
        scripts,
      )!;
      expect(direct.outcome.messages, contains('CHAPTER 4'));
      expect((direct.outcome.teleportX, direct.outcome.teleportY), (81, 77));

      // Dispatcher 연동 실행
      final run = dispatchSpecial(mapId: 13, x: 80, y: 71, tile: 52)!;
      expect(run.outcome.messages, contains('CHAPTER 4'));
      expect((run.outcome.teleportX, run.outcome.teleportY), (81, 77));

      // 특수 타일(52)이 아니면 발동하지 않는다
      expect(
        dispatchSpecial(mapId: 13, x: 80, y: 71, tile: 41),
        isNull,
      );
    });

    test('y=68 Gorgon 전투는 1회성 플래그 etc38_bit5에 의해 제어된다', () {
      final battle = dispatchSpecial(mapId: 13, x: 81, y: 68, tile: 52)!;
      expect(battle.outcome.battleMonsters, [50, 51, 52]);
      expect(battle.outcome.battleVictoryFlags, contains('etc38_bit5'));

      // 플래그 설정 후 재방문 시 미발동
      expect(
        dispatchSpecial(mapId: 13, x: 81, y: 68, tile: 52, flags: {'etc38_bit5'}),
        isNull,
      );
    });

    test('특수 사건 좌표가 아닌 곳은 null을 반환한다', () {
      expect(
        dispatchSpecial(mapId: 13, x: 10, y: 10, tile: 52),
        isNull,
      );
    });
  });
}

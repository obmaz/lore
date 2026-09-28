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

  group('LORESPEC 맵 20 DEN5 / ASTRAL DEN 분기 검증 (LORESPEC.PAS:1475-1759)', () {
    test('y=88 및 y=71 퀴즈 문은 타일 0이면 통과 워프, 아니면 동굴 밖으로 퇴장시킨다', () {
      // LoreSpecProcedures.map20 직접 호출 검증 (타일 0 통과)
      final directPass = LoreSpecProcedures.map20(
        8,
        88,
        const ScriptContext(tileAtPlayer: 0),
        scripts,
      )!;
      expect(directPass.outcome.teleportY, 80);

      // y=88 통과
      final pass88 = dispatchSpecial(mapId: 20, x: 8, y: 88, tile: 0)!;
      expect(pass88.outcome.teleportY, 80);

      // y=88 실패 퇴장
      final fail88 = dispatchSpecial(mapId: 20, x: 8, y: 88, tile: 52)!;
      expect((fail88.outcome.teleportMap, fail88.outcome.teleportX, fail88.outcome.teleportY), (4, 82, 17));

      // y=71 통과
      final pass71 = dispatchSpecial(mapId: 20, x: 8, y: 71, tile: 0)!;
      expect(pass71.outcome.teleportY, 63);

      // y=71 실패 퇴장
      final fail71 = dispatchSpecial(mapId: 20, x: 8, y: 71, tile: 52)!;
      expect((fail71.outcome.teleportMap, fail71.outcome.teleportX, fail71.outcome.teleportY), (4, 82, 17));
    });

    test('y=48 Minotaur 수호자 전투는 etc41_bit4에 의해 1회만 발동한다', () {
      final battle = dispatchSpecial(mapId: 20, x: 25, y: 48)!;
      expect(battle.awaitingBattle, isTrue);
      expect(battle.outcome.battleMonsters, [53]);

      final rerun = dispatchSpecial(
        mapId: 20,
        x: 25,
        y: 48,
        flags: {'etc41_bit4'},
      );
      expect(rerun, isNull);
    });

    test('y=13 3연전은 Dragons -> Mudmen -> Astral Mud 보스전 순서로 진행된다', () {
      // 1차전: Dragons
      final wave1 = dispatchSpecial(mapId: 20, x: 25, y: 13)!;
      expect(wave1.awaitingBattle, isTrue);
      expect(wave1.outcome.battleMonsters, [54, 54, 54]);

      // 2차전: Mudmen (etc41_bit2 설정 시)
      final wave2 = dispatchSpecial(
        mapId: 20,
        x: 25,
        y: 13,
        flags: {'etc41_bit2'},
      )!;
      expect(wave2.awaitingBattle, isTrue);
      expect(wave2.outcome.battleMonsters, [31, 31, 31, 31, 31, 31, 31]);

      // 3차전: Astral Mud 보스전 (etc41_bit2, etc41_bit3 설정 시)
      final wave3 = dispatchSpecial(
        mapId: 20,
        x: 25,
        y: 13,
        flags: {'etc41_bit2', 'etc41_bit3'},
      )!;
      expect(wave3.awaitingBattle, isTrue);
      expect(wave3.outcome.battleMonsters, contains(57));
      expect(wave3.outcome.messages.any((m) => m.contains('Astral Mud')), isTrue);

      final victory = wave3.continueAfterBattle();
      expect(victory.outcome.setFlags, contains('etc41_bit1'));
      expect((victory.outcome.teleportMap, victory.outcome.teleportX, victory.outcome.teleportY), (4, 82, 17));

      // 모두 완료 후 (etc41_bit1 설정 시)
      final done = dispatchSpecial(
        mapId: 20,
        x: 25,
        y: 13,
        flags: {'etc41_bit1', 'etc41_bit2', 'etc41_bit3'},
      );
      expect(done, isNull);
    });

    test('특수 사건 위치가 아닌 곳은 null을 반환한다', () {
      final normal = dispatchSpecial(mapId: 20, x: 1, y: 1);
      expect(normal, isNull);
    });
  });
}

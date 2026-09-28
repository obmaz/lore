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

  group('LORESPEC 맵 19 DEN4 / EVIL DEN 분기 검증 (LORESPEC.PAS:1366-1474)', () {
    test('(11,40) 및 (41,39) 늪속 레버는 공중부상 시 차단되고, 일반 상태에서는 작동하여 통로를 연다', () {
      // LoreSpecProcedures.map19 직접 호출 검증 (공중부상 차단)
      final directBlocked = LoreSpecProcedures.map19(
        11,
        40,
        const ScriptContext(flags: {'levitationActive'}),
        scripts,
      )!;
      expect(directBlocked.outcome.messages.any((m) => m.contains('들어갈수가 없다')), isTrue);

      // 레버 A: 공중부상 미활성
      final leverA = dispatchSpecial(mapId: 19, x: 11, y: 40)!;
      expect(leverA.outcome.messages.any((m) => m.contains('굉음이 들렸다')), isTrue);
      expect(leverA.outcome.setFlags, contains('evilSealLeverA'));

      // 레버 B: 공중부상 미활성
      final leverB = dispatchSpecial(mapId: 19, x: 41, y: 39)!;
      expect(leverB.outcome.messages.any((m) => m.contains('더 큰 굉음이')), isTrue);
      expect(leverB.outcome.tileAreas, isNotEmpty);
    });

    test('y in 8..12 복도 수호자는 봉인 해제 전 출현하고 해제 후 미출현한다', () {
      final guardian = dispatchSpecial(mapId: 19, x: 14, y: 10)!;
      expect(guardian.awaitingBattle, isTrue);

      final cleared = dispatchSpecial(
        mapId: 19,
        x: 14,
        y: 10,
        flags: {'etc40_bit1'},
      );
      expect(cleared, isNull);
    });

    test('y=6 봉인 방은 오답 방과 정답 방(보스전 및 봉인 해제)으로 구분된다', () {
      // 방 3(x=22)이 정답 방으로 지정된 상황
      // 오답 방(방 1, x=14)
      final wrong = dispatchSpecial(
        mapId: 19,
        x: 14,
        y: 6,
        flags: {'evilSealRoom3'},
      )!;
      expect(wrong.outcome.messages.any((m) => m.contains('발견되지 않았다')), isTrue);

      // 정답 방(방 3, x=22)
      final boss = dispatchSpecial(
        mapId: 19,
        x: 22,
        y: 6,
        flags: {'evilSealRoom3'},
      )!;
      expect(boss.awaitingBattle, isTrue);
      expect(boss.outcome.messages.any((m) => m.contains('CRAB GOD의 왕이다')), isTrue);

      final victory = boss.continueAfterBattle();
      expect(victory.outcome.setFlags, contains('etc40_bit1'));
      expect(victory.outcome.messages.any((m) => m.contains('봉인을 풀어버렸다')), isTrue);

      // 이미 봉인이 풀린 후
      final rerun = dispatchSpecial(
        mapId: 19,
        x: 22,
        y: 6,
        flags: {'evilSealRoom3', 'etc40_bit1'},
      );
      expect(rerun, isNull);
    });

    test('특수 사건 위치가 아닌 곳은 null을 반환한다', () {
      final normal = dispatchSpecial(mapId: 19, x: 1, y: 1);
      expect(normal, isNull);
    });
  });
}

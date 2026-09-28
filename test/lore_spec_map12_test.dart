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
    int moveDy = 0,
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
        moveDy: moveDy,
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

  group('LORESPEC 맵 12 T_DEN2 / GAIA DEN 분기 검증 (LORESPEC.PAS:560-668)', () {
    test('y=50 수수께끼 문은 정답(x=33)과 오답(x!=33)을 올바르게 처리한다', () {
      // LoreSpecProcedures.map12 직접 실행 검증
      final directRight = LoreSpecProcedures.map12(
        33,
        50,
        const ScriptContext(tileAtPlayer: 0),
        scripts,
      )!;
      expect(directRight.outcome.messages.single, '여기는 옳은 문이었다.');

      // 정답 문 (x=33)
      final right = dispatchSpecial(mapId: 12, x: 33, y: 50)!;
      expect(right.outcome.messages.single, '여기는 옳은 문이었다.');
      expect(right.outcome.tileChanges.single.x, 33);
      expect(right.outcome.tileChanges.single.y, 49);
      expect(right.outcome.tileChanges.single.tile, 0);

      // 오답 문 (x=20)
      final wrong = dispatchSpecial(mapId: 12, x: 20, y: 50)!;
      expect(wrong.outcome.messages.single, '당신은 바보군요, 다시 생각하십시오.');
      expect((wrong.outcome.teleportX, wrong.outcome.teleportY), (25, 70));

      // 남쪽으로 이동 중(moveDy == 1)에는 문이 발동하지 않는다
      expect(dispatchSpecial(mapId: 12, x: 33, y: 50, moveDy: 1), isNull);
      expect(dispatchSpecial(mapId: 12, x: 20, y: 50, moveDy: 1), isNull);
    });

    test('y=10에서 x=18은 황금의 봉인을 획득하고 다른 x는 늪 함정을 발동한다', () {
      // 황금의 봉인 (x=18, gaia 퀘스트 < 2)
      final seal = dispatchSpecial(
        mapId: 12,
        x: 18,
        y: 10,
        questSteps: {'gaia': 1},
      )!;
      expect(seal.outcome.messages, contains('당신은 황금의 봉인을 찾았다 !!'));
      expect(seal.outcome.questChanges.single.set, 2);
      expect(seal.outcome.tileChanges.single.tile, 0);

      // 늪 함정 (x=15, gaia 퀘스트 < 2)
      final trap = dispatchSpecial(
        mapId: 12,
        x: 15,
        y: 10,
        questSteps: {'gaia': 1},
      )!;
      final area = trap.outcome.tileAreas.single;
      expect(area.tile, 49);
      expect((area.yMin, area.yMax), (10, 23));

      // 퀘스트 완료 후(gaia >= 2)에는 y=10 사건이 발동하지 않는다
      expect(
        dispatchSpecial(mapId: 12, x: 18, y: 10, questSteps: {'gaia': 2}),
        isNull,
      );
      expect(
        dispatchSpecial(mapId: 12, x: 15, y: 10, questSteps: {'gaia': 2}),
        isNull,
      );
    });

    test('(12,48) Rigel 만남은 3가지 선택지를 제공하고 완료 후에는 재발동하지 않는다', () {
      final rigel = dispatchSpecial(mapId: 12, x: 12, y: 48)!;
      expect(rigel.hasPendingChoice, isTrue);
      expect(rigel.outcome.messages.join(), contains('Rigel'));
      expect(rigel.choiceTexts!.length, 3);
      expect(rigel.choiceTexts![0], '좋소, 같이 모험을 합시다');
      expect(rigel.choiceTexts![1], '식량과 치료는 해결해 주겠소');
      expect(rigel.choiceTexts![2], '당신을 도와줄 시간이 없소');

      // 이미 만난 뒤에는 재발동하지 않는다
      expect(
        dispatchSpecial(mapId: 12, x: 12, y: 48, flags: {'rigelMet'}),
        isNull,
      );
      expect(
        dispatchSpecial(mapId: 12, x: 12, y: 48, flags: {'etc31_bit2'}),
        isNull,
      );
    });

    test('타일이 0이 아니면 특수 사건이 발동하지 않는다', () {
      expect(dispatchSpecial(mapId: 12, x: 33, y: 50, tile: 1), isNull);
      expect(dispatchSpecial(mapId: 12, x: 18, y: 10, tile: 44), isNull);
    });
  });
}

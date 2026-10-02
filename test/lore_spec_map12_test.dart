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

      // 오답 문 (원본 지도의 x=19는 특수 타일 0)
      final wrong = dispatchSpecial(mapId: 12, x: 19, y: 50)!;
      expect(wrong.outcome.messages.single, '당신은 바보군요, 다시 생각하십시오.');
      expect((wrong.outcome.teleportX, wrong.outcome.teleportY), (25, 70));

      // 남쪽 이동에서는 문 대신 마지막 절벽 분기가 적용된다.
      expect(
        dispatchSpecial(mapId: 12, x: 33, y: 50, moveDy: 1)!.outcome.stepBack,
        isTrue,
      );
      expect(
        dispatchSpecial(mapId: 12, x: 19, y: 50, moveDy: 1)!.outcome.stepBack,
        isTrue,
      );
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

      // 늪 함정 (원본 지도의 x=13은 특수 타일 0)
      final trap = dispatchSpecial(
        mapId: 12,
        x: 13,
        y: 10,
        questSteps: {'gaia': 1},
      )!;
      final area = trap.outcome.tileAreas.single;
      expect(area.tile, 49);
      expect((area.yMin, area.yMax), (10, 23));

      // 퀘스트 완료 후(gaia >= 2)에는 봉인/함정 대신 절벽 분기가 적용된다.
      expect(
        dispatchSpecial(
          mapId: 12,
          x: 18,
          y: 10,
          questSteps: {'gaia': 2},
        )!.outcome.stepBack,
        isTrue,
      );
      expect(
        dispatchSpecial(
          mapId: 12,
          x: 13,
          y: 10,
          questSteps: {'gaia': 2},
        )!.outcome.stepBack,
        isTrue,
      );
    });

    test('(12,48) Rigel 만남은 3가지 선택지를 제공하고 완료 후에는 재발동하지 않는다', () {
      final mapBytes = File('assets/maps/T_DEN2.MAP').readAsBytesSync();
      final mapWidth = mapBytes[0];
      expect(mapBytes[2 + (48 - 1) * mapWidth + 12 - 1], 52);
      final met = dispatchSpecial(mapId: 12, x: 12, y: 48, tile: 52)!;
      expect(met.pendingScene!.lines.last, '못하는 한 남자와 마주쳤다.');
      final rigel = met.acknowledgeScene();
      expect(rigel.hasPendingChoice, isTrue);
      // select() = 0 (Escape): dec(y) and no etc[31] bit.
      final fled = rigel.cancel();
      expect(fled.outcome.nudges.single.dy, -1);
      expect(fled.outcome.setFlags, isEmpty);
      for (var b = 0; b < 256; b++) {
        final run = LoreSpecProcedures.map12(
          12,
          48,
          ScriptContext(
            tileAtPlayer: 52,
            sourceEtc: {31: b},
            flags: const {'rigelMet'},
          ),
          scripts,
        );
        expect(run == null, b & 2 != 0);
      }
      expect(rigel.outcome.messages.join(), contains('Rigel'));
      expect(rigel.choiceTexts!.length, 3);
      expect(rigel.choiceTexts![0], '좋소, 같이 모험을 합시다');
      expect(rigel.choiceTexts![1], '식량과 치료는 해결해 주겠소');
      expect(rigel.choiceTexts![2], '당신을 도와줄 시간이 없소');

      // 이미 만난 뒤에는 재발동하지 않는다
      expect(
        dispatchSpecial(mapId: 12, x: 12, y: 48, tile: 52, flags: {'rigelMet'}),
        isNull,
      );
      expect(
        dispatchSpecial(
          mapId: 12,
          x: 12,
          y: 48,
          tile: 52,
          flags: {'etc31_bit2'},
        ),
        isNull,
      );
    });

    test('공중 부상 없이 다른 특수 칸에 들어서면 뒤로 물리고 출구는 제외한다', () {
      final mapBytes = File('assets/maps/T_DEN2.MAP').readAsBytesSync();
      final mapWidth = mapBytes[0];
      expect(mapBytes[2 + (60 - 1) * mapWidth + 25 - 1], 0);
      final cliff = dispatchSpecial(mapId: 12, x: 25, y: 60, tile: 0)!;
      expect(cliff.script.id, 'gaia-den-cliff-no-levitation');
      expect(cliff.outcome.stepBack, isTrue);
      expect(cliff.outcome.messages.single, '일행들은 절벽으로 떨어질뻔 했다.');
      expect(
        dispatchSpecial(mapId: 12, x: 25, y: 60, tile: 0, flags: {'etc4'}),
        isNull,
      );
      expect(
        dispatchSpecial(
          mapId: 12,
          x: 25,
          y: 60,
          tile: 0,
          flags: {'levitateActive'},
        ),
        isNull,
      );
      expect(dispatchSpecial(mapId: 12, x: 25, y: 71, tile: 52), isNull);
    });

    test('특수 타일 0·52 이외에서는 특수 사건이 발동하지 않는다', () {
      expect(dispatchSpecial(mapId: 12, x: 33, y: 50, tile: 1), isNull);
      expect(dispatchSpecial(mapId: 12, x: 18, y: 10, tile: 44), isNull);
    });
  });
}

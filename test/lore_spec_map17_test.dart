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
    bool mindReadActive = false,
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
        mindReadActive: mindReadActive,
      ),
      party: const [],
      scripts: scripts,
      legacy: LoreDungeonEventManager.instance,
    );
    expect(result.legacy, isNull);
    return result.script;
  }

  group('LORESPEC 맵 17 DEN3 / DRAGON DEN 분기 검증 (LORESPEC.PAS:1006-1173)', () {
    test('(75,52) Red Antares는 미습득 시 강의, 독심술 보유 시 영입 제의, 부재 시 대기 대사를 보인다', () {
      // LoreSpecProcedures.map17 직접 호출 검증
      final direct = LoreSpecProcedures.map17(
        75,
        52,
        const ScriptContext(),
        scripts,
      )!;
      expect(direct.outcome.messages.any((m) => m.contains('Red Antares')), isTrue);
      expect(direct.outcome.setFlags, contains('etc38_bit1'));

      // 1. 최초 방문: 강의 및 용암 변형
      final teach = dispatchSpecial(mapId: 17, x: 75, y: 52)!;
      expect(teach.outcome.messages.any((m) => m.contains('간접 공격')), isTrue);
      expect(teach.outcome.setFlags, contains('etc38_bit1'));

      // 2. 재방문 (독심술 없음): 대기 대사
      final wait = dispatchSpecial(
        mapId: 17,
        x: 75,
        y: 52,
        flags: {'etc38_bit1'},
        mindReadActive: false,
      )!;
      expect(wait.outcome.messages.any((m) => m.contains('영혼의 세계로')), isTrue);

      // 3. 재방문 (독심술 있음): 영입 선택지
      final join = dispatchSpecial(
        mapId: 17,
        x: 75,
        y: 52,
        flags: {'etc38_bit1'},
        mindReadActive: true,
      )!;
      expect(join.outcome.messages.any((m) => m.contains('모험을 하고 싶소')), isTrue);
      expect(join.hasPendingChoice, isTrue);

      // 4. 이미 영입 또는 결정 완료 시 (etc38_bit2 설정)
      final done = dispatchSpecial(
        mapId: 17,
        x: 75,
        y: 52,
        flags: {'etc38_bit1', 'etc38_bit2'},
        mindReadActive: true,
      );
      expect(done, isNull);
    });

    test('x=22 Hidra 보스 전투는 swamp 퀘스트 단계 2 미만일 때 발동한다', () {
      // swamp 퀘스트 단계 < 2
      final battle = dispatchSpecial(
        mapId: 17,
        x: 22,
        y: 50,
        questSteps: {'swamp': 0},
      )!;
      expect(battle.awaitingBattle, isTrue);
      expect(battle.outcome.battleMonsters, [49, 49, 49]);

      final victory = battle.continueAfterBattle();
      expect(
        victory.outcome.questChanges.any((q) => q.name == 'swamp' && q.set == 2),
        isTrue,
      );
      expect((victory.outcome.teleportX, victory.outcome.teleportY), (56, 93));

      // swamp 퀘스트 단계 >= 2: 재대결 불가
      final done = dispatchSpecial(
        mapId: 17,
        x: 22,
        y: 50,
        questSteps: {'swamp': 2},
      );
      expect(done, isNull);
    });

    test('y=80, y=44, x=72, y=38 통로 및 이동 트랩이 정상 작동한다', () {
      // y=80 워프
      final wrap = dispatchSpecial(mapId: 17, x: 50, y: 80)!;
      expect(wrap.outcome.teleportY, 6);

      // y=44 통로 개방
      final p44 = dispatchSpecial(mapId: 17, x: 50, y: 44)!;
      expect(p44.outcome.tileAreas, isNotEmpty);

      // x=72 지형 개방
      final s72 = dispatchSpecial(mapId: 17, x: 72, y: 20)!;
      expect(s72.outcome.tileChanges, isNotEmpty);

      // y=38 통로 복구 및 귀환
      final p38 = dispatchSpecial(mapId: 17, x: 50, y: 38)!;
      expect((p38.outcome.teleportX, p38.outcome.teleportY), (56, 93));
    });

    test('특수 사건 위치가 아닌 곳은 null을 반환한다', () {
      final normal = dispatchSpecial(mapId: 17, x: 1, y: 1);
      expect(normal, isNull);
    });
  });
}

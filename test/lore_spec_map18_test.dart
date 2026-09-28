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
    int maxEspLevel = 0,
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
        maxEspLevel: maxEspLevel,
      ),
      party: const [],
      scripts: scripts,
      legacy: LoreDungeonEventManager.instance,
    );
    expect(result.legacy, isNull);
    return result.script;
  }

  group('LORESPEC 맵 18 T_DEN4 / LOCKUP 분기 검증 (LORESPEC.PAS:1174-1365)', () {
    test('(37,31) Spica는 미습득 시 강의, 독심술 및 초능력 레벨에 따라 합류/거부 분기를 탄다', () {
      // LoreSpecProcedures.map18 직접 호출 검증
      final direct = LoreSpecProcedures.map18(
        37,
        31,
        const ScriptContext(),
        scripts,
      )!;
      expect(direct.outcome.messages.any((m) => m.contains('Spica')), isTrue);
      expect(direct.outcome.setFlags, contains('etc39_bit1'));

      // 1. 최초 방문: 수도 중인 Spica 만남 및 초자연력 강의
      final teach = dispatchSpecial(mapId: 18, x: 37, y: 31)!;
      expect(teach.outcome.messages.any((m) => m.contains('초자연력')), isTrue);
      expect(teach.outcome.setFlags, contains('etc39_bit1'));

      // 2. 재방문 (독심술 미활성): 지체할 시간 없음
      final inactive = dispatchSpecial(
        mapId: 18,
        x: 37,
        y: 31,
        flags: {'etc39_bit1'},
        mindReadActive: false,
      )!;
      expect(inactive.outcome.messages.any((m) => m.contains('지체할 시간')), isTrue);

      // 3. 재방문 (독심술 활성, 초능력 레벨 < 5): 능력 부족
      final cannotRead = dispatchSpecial(
        mapId: 18,
        x: 37,
        y: 31,
        flags: {'etc39_bit1'},
        mindReadActive: true,
        maxEspLevel: 4,
      )!;
      expect(cannotRead.outcome.messages.any((m) => m.contains('끌어낼수는 없습니다')), isTrue);

      // 4. 재방문 (독심술 활성, 초능력 레벨 >= 5): 영입 제의 선택지
      final join = dispatchSpecial(
        mapId: 18,
        x: 37,
        y: 31,
        flags: {'etc39_bit1'},
        mindReadActive: true,
        maxEspLevel: 5,
      )!;
      expect(join.outcome.messages.any((m) => m.contains('무찌르겠습니다')), isTrue);
      expect(join.hasPendingChoice, isTrue);

      // 5. 이미 결정 완료 (etc39_bit2 설정): null
      final done = dispatchSpecial(
        mapId: 18,
        x: 37,
        y: 31,
        flags: {'etc39_bit1', 'etc39_bit2'},
        mindReadActive: true,
        maxEspLevel: 5,
      );
      expect(done, isNull);
    });

    test('(22,41) 통로 개방과 (21,41) 괴물 수호자 전투가 정상 실행된다', () {
      // 통로 개방
      final passage = dispatchSpecial(mapId: 18, x: 22, y: 41)!;
      expect(passage.outcome.tileChanges.length, 2);

      // 괴물 수호자 전투
      final battle = dispatchSpecial(mapId: 18, x: 21, y: 41)!;
      expect(battle.awaitingBattle, isTrue);
      expect(battle.outcome.battleMonsters, [53]);

      // 격파 후 재방문
      final rerun = dispatchSpecial(
        mapId: 18,
        x: 21,
        y: 41,
        flags: {'etc39_bit3'},
      );
      expect(rerun, isNull);
    });

    test('x=31 Huge Dragon 보스 전투는 swamp 퀘스트 단계 4 미만일 때 발동한다', () {
      final battle = dispatchSpecial(
        mapId: 18,
        x: 31,
        y: 10,
        questSteps: {'swamp': 2},
      )!;
      expect(battle.awaitingBattle, isTrue);
      expect(battle.outcome.battleMonsters, [54, 39, 30, 31, 32, 30, 31]);

      final victory = battle.continueAfterBattle();
      expect(
        victory.outcome.questChanges.any((q) => q.name == 'swamp' && q.set == 4),
        isTrue,
      );

      // 이미 승리하여 4단계 이상인 경우
      final done = dispatchSpecial(
        mapId: 18,
        x: 31,
        y: 10,
        questSteps: {'swamp': 4},
      );
      expect(done, isNull);
    });

    test('특수 사건 위치가 아닌 곳은 null을 반환한다', () {
      final normal = dispatchSpecial(mapId: 18, x: 1, y: 1);
      expect(normal, isNull);
    });
  });
}

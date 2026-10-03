import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/game/lore_world_manager.dart';
import 'package:lore/logic/lore_talk_dispatcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LoreScriptEngine scripts;
  final world = LoreWorldManager.instance;
  final dialogues = LoreDialogueManager.instance;

  setUp(() async {
    world.resetRulesForTest();
    await world.loadData();
    dialogues.loadFlags({});
    scripts = LoreScriptEngine()
      ..loadFromJson(File('assets/data/scripts.json').readAsStringSync());
  });
  tearDown(() {
    world.resetRulesForTest();
    dialogues.loadFlags({});
  });

  LoreTalkDispatch resolve(int map, int x, int y, ScriptContext context) =>
      LoreTalkDispatcher.resolve(
        mapId: map,
        x: x,
        y: y,
        context: context,
        world: world,
        scripts: scripts,
      );

  test('시설은 대화 스크립트보다 앞서 선택된다', () {
    final result = resolve(6, 8, 71, const ScriptContext());
    expect(result.source, LoreTalkSource.facility);
    expect(result.facility, 1);
    expect(result.script, isNull);
  });

  test('Mad Joe 첫 만남은 선택형 스크립트이며 기존 합류를 중복 실행하지 않는다', () {
    final result = resolve(6, 40, 15, const ScriptContext());
    expect(result.source, LoreTalkSource.script);
    expect(result.script?.script.id, 'madjoe-join');
    expect(result.script?.hasPendingChoice, isTrue);
    expect(dialogues.madJoeJoined, isFalse);
  });

  test('합류 후 Mad Joe 칸은 원본처럼 아무것도 출력하지 않는다', () {
    dialogues.setFlag('madJoeJoined');
    final result = resolve(
      6,
      40,
      15,
      const ScriptContext(flags: {'madJoeJoined'}),
    );
    expect(result.source, LoreTalkSource.none);
  });

  test('LORETALK.PAS:406 퀘스트 완료 뒤 Polaris 대화는 합류를 발생시키지 않는다', () {
    dialogues.applyQuestStep('lastditch', set: 2);
    final result = resolve(
      7,
      37,
      41,
      const ScriptContext(questSteps: {'lastditch': 2}),
    );
    expect(result.source, LoreTalkSource.none);
    expect(dialogues.polarisJoined, isFalse);
  });

  test('등록되지 않은 좌표는 명시적으로 빈 선택 결과를 돌려준다', () {
    expect(
      resolve(2, 11, 11, const ScriptContext()).source,
      LoreTalkSource.none,
    );
  });
}

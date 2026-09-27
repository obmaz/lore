// 원작 `LORETALK.PAS` 맵 27(운명의 피라밋) 이벤트의 이관 검증.
//
// - 좌표별 "의지" 대사(데네브/알비레오/카노푸스/아크투루스)가 스크립트로 존재한다.
// - (21,12)의 유골 문서 선택지(`select`)가 choice 스텝으로 옮겨졌다.
// - 좌표가 없는 기본 else 분기가 `talk-27-any`로 옮겨졌고,
//   좌표별 스크립트를 가리지 않는다(원작은 첫 일치 분기만 실행).
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/logic/lore_tile_protocol.dart';
import 'package:lore/logic/script_world_reducer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    LoreScriptEngine.instance.resetForTest();
    await LoreScriptEngine.instance.load();
  });
  tearDown(() => LoreScriptEngine.instance.resetForTest());

  test('맵 27 좌표별 의지 대사 스크립트가 모두 존재한다', () {
    final ids = LoreScriptEngine.instance.scripts.map((s) => s.id).toSet();
    for (final id in const [
      'talk-27-15-6',
      'talk-27-10-14',
      'talk-27-10-18',
      'talk-27-10-30',
      'talk-27-21-32',
      'talk-27-21-22',
      'talk-27-21-12',
      'talk-27-any',
    ]) {
      expect(ids.contains(id), isTrue, reason: '$id 누락');
    }
  });

  test('(21,12) 유골 문서는 읽기/지나가기 선택지와 예언 문구를 갖는다', () {
    final s = LoreScriptEngine.instance.scripts.firstWhere(
      (s) => s.id == 'talk-27-21-12',
    );
    final choice = s.steps.firstWhere((st) => st.kind == 'choice');
    expect(choice.options!.length, 2);
    expect(choice.options![0].text, '그 문서를 읽어 보고 싶다');
    expect(choice.options![1].text, '그냥 지나 가겠다');

    // 2번(지나가기)은 아무 문장도 없다(원작 `exit`).
    expect(choice.options![1].steps, isEmpty);

    final texts = choice.options![0].steps
        .where((st) => st.kind == 'say')
        .map((st) => st.text)
        .toList();
    expect(texts, contains(' 머리를 푼 별이 나타날때'));
    expect(texts, contains(' 거대한 세 왕자가 서로를 적대한다'));
    expect(texts, contains(' 평화는 하늘에서 당하고 대지는 요동한다'));
    expect(texts, contains(' 그 찬미해야 할 높은 오류 속에서'));
    expect(texts, contains(' Necromancer 는 해안으로 밀려나리라.'));
    // 프랑스어 원문(Nostradamus 인용)도 함께 남긴다.
    expect(texts, contains(" Durant l'estoille cheuelue apparente,"));
    expect(texts, contains(' Neromancer sur le bord mis.'));

    final tile = choice.options![0].steps
        .where((st) => st.kind == 'setTileAtTarget')
        .toList();
    expect(tile.length, 1);
    expect(tile.first.tileValue, 35);
  });

  test('원본 map[x+x1,y+y1] := 35인 다섯 대화는 재방문 타일을 없앤다', () async {
    final map = await LoreMapData.loadFromAsset('PYRAMID1', category: 'town');
    for (final (x, y) in const [
      (10, 14),
      (10, 18),
      (10, 30),
      (21, 32),
      (21, 22),
    ]) {
      expect(map.actionForTile(map.getTile(x, y)), LoreTileAction.talk);
      final run = LoreScriptEngine.instance.startTalk(
        27,
        x,
        y,
        const ScriptContext(),
      )!;
      expect(run.outcome.tileAtTarget, 35, reason: '($x,$y)');
      final after = ScriptWorldReducer.applyMap(
        ScriptMapState(mapId: 27, x: 15, y: 20, direction: 0, grid: map.grid),
        run.outcome,
        talkTargetX: x,
        talkTargetY: y,
      );
      expect(after.grid[y - 1][x - 1], 35);
      expect(map.actionForTile(35), LoreTileAction.walk);
    }
  });

  test('좌표 없는 기본 else는 좌표별 스크립트를 가리지 않는다', () {
    final scripts = LoreScriptEngine.instance.scripts;
    final anyIndex = scripts.indexWhere((s) => s.id == 'talk-27-any');
    expect(anyIndex, greaterThan(-1));
    // 좌표별 스크립트가 전부 앞에 있어야 한다(find는 첫 일치를 실행).
    for (final id in const ['talk-27-15-6', 'talk-27-10-14', 'talk-27-21-12']) {
      expect(
        scripts.indexWhere((s) => s.id == id),
        lessThan(anyIndex),
        reason: '$id 가 talk-27-any 보다 뒤에 있다',
      );
    }

    final run = LoreScriptEngine.instance.startTalk(
      27,
      15,
      6,
      const ScriptContext(mindReadActive: false, maxEspLevel: 0),
    );
    expect(run, isNotNull);
    expect(run!.script.id, 'talk-27-15-6');

    final fallback = LoreScriptEngine.instance.startTalk(
      27,
      18,
      20,
      const ScriptContext(mindReadActive: false, maxEspLevel: 0),
    );
    expect(fallback, isNotNull);
    expect(fallback!.script.id, 'talk-27-any');
    expect(fallback.outcome.messages, contains(' 당신이 유골에 다가가자 재로 변하였다.'));
    expect(fallback.outcome.tileAtTarget, 35);
  });
}

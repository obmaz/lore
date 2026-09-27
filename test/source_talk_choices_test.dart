import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    LoreScriptEngine.instance.resetForTest();
    await LoreScriptEngine.instance.load();
  });
  tearDown(() => LoreScriptEngine.instance.resetForTest());

  test('LORETALK의 네 select 분기는 수락 때만 원본 지도 효과를 낸다', () {
    final engine = LoreScriptEngine.instance;
    for (final case_ in const [
      (map: 6, x: 40, y: 15, key: 'mad_joe', tile: 47),
      (map: 7, x: 37, y: 41, key: 'polaris', tile: 44),
      (map: 10, x: 40, y: 56, key: 'lore_hunter', tile: 44),
    ]) {
      final run = engine.startTalk(
        case_.map,
        case_.x,
        case_.y,
        const ScriptContext(),
      )!;
      expect(run.hasPendingChoice, isTrue);
      final accepted = run.choose(0).outcome;
      expect(accepted.recruits.single.key, case_.key);
      expect(
        accepted.tileChanges,
        contains((
          map: case_.map,
          x: case_.x,
          y: case_.y,
          tile: case_.tile,
          ifZero: null,
        )),
      );
      final declined = run.choose(1).outcome;
      expect(declined.recruits, isEmpty);
      expect(declined.tileChanges, isEmpty);
    }

    final parchment = engine.startTalk(27, 21, 12, const ScriptContext())!;
    expect(parchment.hasPendingChoice, isTrue);
    final read = parchment.choose(0).outcome;
    expect(read.tileAtTarget, 35);
    expect(read.messages, contains(" Durant l'estoille cheuelue apparente,"));
    final skipped = parchment.choose(1).outcome;
    expect(skipped.tileAtTarget, isNull);
    expect(skipped.recruits, isEmpty);
  });
}

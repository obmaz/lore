// 원작 `LORESPEC.PAS`(좌표 이벤트) 이관 검증.
//
// - 좌표 조건(`on(x,y)`)별로 스크립트가 나뉘고, 진행 플래그로 갈라진다.
// - 옮기지 못한 효과(전투/장비 등)를 가진 좌표는 손으로 쓴 스크립트를
//   그대로 쓰고, 옮긴 쪽은 `disabled` 로 보관만 한다.
// - 맵 26(Necromancer 최후)처럼 한 칸에서 이어지는 연출은 시퀀스 스크립트로
//   옮기되 원작과 같이 `map[x,y] = 0` 인 칸에서만 발동한다.
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    LoreScriptEngine.instance.resetForTest();
    await LoreScriptEngine.instance.load();
  });
  tearDown(() => LoreScriptEngine.instance.resetForTest());

  test('원작 LORESPEC 좌표 이벤트가 스크립트로 들어와 있다', () {
    final ids = LoreScriptEngine.instance.scripts.map((s) => s.id).toSet();
    expect(ids.where((id) => id.startsWith('spec-')).length, greaterThan(100));
  });

  test('맵 26 최후 연출은 map[x,y]=0 인 칸에서만 발동한다', () {
    final seq = LoreScriptEngine.instance.scripts.firstWhere(
      (s) => s.id.startsWith('spec-26-') && s.id.endsWith('-seq'),
    );
    expect(seq.require.tileAtPlayerZero, isTrue);
    // 원작 `Print(13,' 당신들이 나를 없에겠다고 온자들인가?')` 문구가 살아 있다.
    expect(seq.steps.any((st) => st.text == ' 당신들이 나를 없에겠다고 온자들인가?'), isTrue);
    expect(
      seq.steps.any((st) => st.text == ' 욱!!! 역시 너희들의 능력으로 여기까지 뚫고'),
      isTrue,
    );

    // 타일이 0이 아니면 걸리지 않는다.
    expect(
      LoreScriptEngine.instance.startStep(
        26,
        26,
        20,
        const ScriptContext(tileAtPlayer: 44),
      ),
      isNull,
    );
  });

  test('옮기지 못한 조건을 가진 분기는 실행하지 않고 보관만 한다', () {
    final disabled = LoreScriptEngine.instance.scripts
        .where((s) => s.id.startsWith('spec-'))
        .where((s) => s.disabled)
        .toList();
    expect(disabled, isNotEmpty);
    // 보관된 문구는 남아 있다(원문 대조용).
    expect(
      disabled.any(
        (s) => s.steps.any((st) => (st.text ?? '').contains('라바 게이트를 열수가 없다')),
      ),
      isTrue,
    );
  });

  test('맵 4(26,16) Draconian 분기는 진행 플래그로 갈라진다', () {
    final variants = LoreScriptEngine.instance.scripts
        .where((s) => s.map == 4 && s.x == 26 && s.y == 16)
        .toList();
    expect(variants.length, greaterThanOrEqualTo(3));
    // 첫 방문(강의) / 재방문(동료 권유) / 이미 동료(짧은 인사) 세 갈래.
    final lecture = variants.firstWhere(
      (s) => s.steps.length > 40,
      orElse: () => variants.first,
    );
    expect(
      lecture.steps.any((st) => (st.text ?? '').contains('나는 Draconian이라고 하오')),
      isTrue,
    );
  });
}

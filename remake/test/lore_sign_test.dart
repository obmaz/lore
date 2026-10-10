import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_sign.dart';

void main() {
  test('LOREENT.PAS:sign literal lines preserve blank spacing and colors', () {
    final castle = LoreSign.lines(6, 51, 84);
    expect(castle.take(3), [(7, '푯말에 쓰여있기로 ...'), (7, ''), (7, '')]);
    expect(castle.last, (13, 'Lord Ahn'));
    expect(LoreSign.lines(12, 24, 68).last, (15, '               X 는 7'));
    expect(LoreSign.lines(12, 27, 68).last, (15, '               Y 는 9'));
    expect(LoreSign.lines(12, 25, 63).last, (15, '       바른 문의 번호는 X + Y'));
    expect(LoreSign.lines(12, 26, 42).last, (15, '            Z 는 2 * Y + X'));
    expect(LoreSign.lines(17, 58, 53)[4], (10, '      이 게임을 만든 사람'));
    expect(
      LoreSign.lines(1, 5, 5).length,
      3,
    ); // Header even without a map-specific case.
  });
  test(
    'LOREENT.PAS:sign dynamic door/passcode uses source integer division',
    () {
      for (var x = 5; x <= 75; x++) {
        expect(
          LoreSign.lines(12, x, 56).last.$2,
          "           문의 번호는 '${(x - 6) ~/ 7 + 12}'",
        );
        expect(
          LoreSign.lines(12, x, 29).last.$2,
          "           패스코드는 '${(x - 3) ~/ 5 + 2}'",
        );
      }
    },
  );
}

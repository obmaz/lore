import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_sub_text.dart';

/// LORESUB.PAS `ReturnWeapon` (Josa) and `ReturnMessage` (how = 1).
void main() {
  test('ReturnWeapon josa: 0, 2..4, 6..9 take 으, the rest do not', () {
    for (var id = 0; id <= 9; id++) {
      final withJosa = id == 0 || (id >= 2 && id <= 4) || (id >= 6 && id <= 9);
      expect(LoreSubText.weaponJosa(id), withJosa ? '으' : '', reason: '$id');
    }
  });

  test('ReturnMessage how 1 inserts the weapon josa before 로', () {
    expect(
      LoreSubText.returnMessage(actor: 'A', how: 1, what: 4, target: 'Orc'),
      'A는 장검으로 Orc를 공격했다',
    );
    expect(
      LoreSubText.returnMessage(actor: 'A', how: 1, what: 1, target: 'Orc'),
      'A는 단도로 Orc를 공격했다',
    );
    expect(LoreSubText.returnMessage(actor: 'A', how: 7), '일행은 도망을 시도했다');
  });
}

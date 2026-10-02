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

  test('ReturnMagic: ids in [2,9,10,14..16,18..21,25..28,32,38,40,41] take no 으 and 를', () {
    const noJosa = {
      2,
      9,
      10,
      14,
      15,
      16,
      18,
      19,
      20,
      21,
      25,
      26,
      27,
      28,
      32,
      38,
      40,
      41,
    };
    for (var id = 1; id <= 45; id++) {
      expect(
        LoreSubText.magicJosa(id),
        noJosa.contains(id) ? '' : '으',
        reason: '$id',
      );
      expect(
        LoreSubText.magicMokjuk(id),
        noJosa.contains(id) ? '를' : '을',
        reason: '$id',
      );
    }
  });

  test('ReturnMessage how 2/6 use the corrected magic josa', () {
    expect(
      LoreSubText.returnMessage(actor: 'A', how: 2, what: 2, target: 'Orc'),
      "A는 '마법 화구'로 Orc에게 공격했다",
    );
    expect(
      LoreSubText.returnMessage(actor: 'A', how: 2, what: 1, target: 'Orc'),
      "A는 '마법 화살'으로 Orc에게 공격했다",
    );
    expect(
      LoreSubText.returnMessage(actor: 'A', how: 6, what: 1, target: 'Orc'),
      'A는 Orc에게 투시를 사용했다',
    );
  });
}

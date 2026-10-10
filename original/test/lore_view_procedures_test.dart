import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_source_memory.dart';
import 'package:lore/logic/lore_view_procedures.dart';
import 'package:lore/models/party_member.dart';

/// LOREMENU.PAS `ViewParty`, `ViewCharacter` and `QuickView` texts.
void main() {
  test('ViewParty: x/y, food, gold, then torch/levitate/water/swamp', () {
    final lines = LoreViewProcedures.viewParty(
      x: 51,
      y: 31,
      food: 20,
      gold: 2000,
      etc: LorePartyEtc({1: 3, 2: 0, 3: 255, 4: 0}),
    );
    expect(lines.map((l) => l.$2), [
      'X 축 = 51',
      'Y 축 = 31',
      '남은 식량 = 20',
      '남은 황금 = 2000',
      '마법의 횃불 : 가능',
      '공중 부상   : 불가',
      '물위를 걸음 : 불가',
      '늪위를 걸음 : 가능',
    ]);
  });

  test('ViewCharacter pages use ReturnClass/ReturnDefense; shield/armor only when set', () {
    final knight = PartyMember.createPreset(1)
      ..weapon = 4
      ..shield = 0
      ..armor = 5;
    final first = LoreViewProcedures.characterPage1(knight);
    expect(first.take(3).map((l) => l.$1), [11, 11, 11]);
    expect(first[1].$2, '# 성별 : 남성');
    expect(first[2].$2, '# 계급 : 기사');
    expect(first.skip(3).map((l) => l.$1), everyElement(3));
    expect(first.last.$2, '행운   : ${knight.luck}');
    final second = LoreViewProcedures.characterPage2(knight).map((l) => l.$2);
    expect(second, contains('사용 무기 - 장검'));
    expect(second, contains('갑옷 - 금제 갑옷'));
    expect(second.any((t) => t.startsWith('방패 - ')), isFalse);
    expect(second, contains('## 경험치   : ${knight.experience}'));
  });

  test('QuickView: header and one row per named member', () {
    final party = [
      PartyMember.createPreset(1)
        ..poison = 2
        ..unconscious = 7
        ..dead = 0,
      PartyMember.blank(),
      PartyMember.createPreset(3),
    ];
    final lines = LoreViewProcedures.quickView(party);
    expect(lines.length, 3);
    expect(lines.first.$2, contains('이름'));
    expect(lines.first.$2, endsWith(' 중독 의식불명 죽음'));
    expect(lines[1].$2, startsWith(party.first.name));
    expect(lines[1].$2, 'Hercules              2      7     0');
  });
}

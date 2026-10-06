import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_mirror_enemy.dart';
import 'package:lore/models/party_member.dart';

void main() {
  test('Necromancer 환상은 일행 능력치를 복제하고 빈 슬롯은 Wraith로 채운다', () {
    final hunter = PartyMember(
      name: 'Hunter',
      playerClass: PlayerClass.hunter,
      strength: 19,
      mentality: 16,
      concentration: 12,
      endurance: 14,
      resistance: 8,
      agility: 17,
      accArms: 11,
      accMagic: 9,
      accEsp: 7,
      luck: 5,
      battleLevel: 9,
      magicLevel: 8,
      ac: 4,
    );
    final enemies = createMindMirrorEnemies([hunter]);
    expect(enemies, hasLength(6));
    final mirror = enemies.first;
    expect(mirror.name, 'Hunter');
    expect(mirror.eNumber, 1);
    expect(mirror.strength, hunter.strength);
    expect(mirror.ac, hunter.ac);
    expect(mirror.special, 2);
    expect(mirror.castLevel, 2);
    expect(mirror.level, 9);
    expect(mirror.hp, hunter.endurance * hunter.battleLevel);
    expect(enemies.skip(1).map((e) => e.name), everyElement('Wraith'));
    expect(enemies.skip(1).map((e) => e.eNumber), everyElement(1));
  });
}

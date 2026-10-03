import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/field_magic_logic.dart';
import 'package:lore/models/party_member.dart';

/// 원작 `LOREMENU.PAS` 비전투 마법(CureSpell/PhenominaSpell) 이식 검증.
///
/// 원작은 SP 비용을 **시전자/대상 상태로 계산**한다:
///  - `HealOne`       : `i := 2 * level[2]` 소모, `hp += i * 3 div 2`
///  - `CureOne`       : 15 소모
///  - `ConsciousOne`  : `10 * unconscious` 소모
///  - `RevitalizeOne` : `30 * dead` 소모
void main() {
  PartyMember makeMember({
    String name = 'Merlin',
    int magicLevel = 1,
    int endurance = 10,
    int battleLevel = 1,
    int sp = 100,
    int? hp,
  }) {
    return PartyMember(
      name: name,
      // hp/sp는 생성자가 계산하므로 필요할 때만 지정한다.
      sex: Gender.male,
      playerClass: PlayerClass.mage,
      strength: 5,
      mentality: 10,
      concentration: 5,
      endurance: endurance,
      resistance: 5,
      agility: 5,
      accArms: 5,
      accMagic: 10,
      accEsp: 5,
      luck: 10,
      battleLevel: battleLevel,
      magicLevel: magicLevel,
      sp: sp,
      hp: hp,
    );
  }

  group('원작 LOREMENU.PAS 비전투 마법 (CureSpell / PhenominaSpell)', () {
    test('1. 문구와 슬롯 제한이 원작 식과 같다', () {
      // 원작 AttackSpell / SPnotEnough 문구
      expect(
        FieldMagicLogic.attackSpellMessage,
        '전투 모드가 아닐때는 공격 마법을 사용할 수 없습니다.',
      );
      expect(FieldMagicLogic.spNotEnoughMessage, '그러나, 마법 지수가 충분하지 않습니다.');

      // 전체 치료: level[2] div 2 - 3 (음수면 거절, 0이면 첫 항목만 고를 수 있음)
      expect(FieldMagicLogic.groupCureSlots(6), 0);
      expect(FieldMagicLogic.groupCureSlots(8), 1);
      expect(FieldMagicLogic.groupCureSlots(20), 7);
      expect(
        FieldMagicLogic.strongCureNotReady('Merlin'),
        'Merlin는 강한 치료 마법은 아직 불가능 합니다.',
      );
    });

    test('ConsciousOne/RevitalizeOne cost is stored in a 16-bit integer', () {
      // `i := 10 * unconscious` / `i := 30 * dead` with `i : integer`.
      expect(FieldMagicLogic.consciousSpCost(100), 1000);
      expect(FieldMagicLogic.consciousSpCost(3277), -32766);
      expect(FieldMagicLogic.revitalizeSpCost(1092), 32760);
      expect(FieldMagicLogic.revitalizeSpCost(1093), -32746);
      expect(FieldMagicLogic.revitalizeSpCost(30000), -17504);
      // The wrapped negative cost passes `sp < i` and is subtracted as is.
      final caster = makeMember(magicLevel: 5, sp: 100);
      final target = makeMember(name: 'Kaiser')..dead = 30000;
      final result = FieldMagicLogic.revitalizeOne(caster, target);
      expect(result.success, isTrue);
      expect(caster.sp, 100 + 17504);
    });

    test('2. HealOne: SP = 2×마법Lv, 회복 = SP×3÷2, 상한 = 체력×전투Lv', () {
      final caster = makeMember(magicLevel: 5, sp: 100);
      final target = makeMember(
        name: 'Kaiser',
        endurance: 10,
        battleLevel: 3,
        hp: 1,
      ); // 최대 HP = 30

      final result = FieldMagicLogic.healOne(caster, target);
      expect(result.success, isTrue);
      expect(result.spSpent, 10); // 2 * 5
      expect(caster.sp, 90);
      // 원작은 `hp := hp + i * 3 div 2` 로 더한다 (1 + 15 = 16)
      expect(target.hp, 16);
      expect(result.messages.single, 'Kaiser는 치료되어 졌습니다.');

      // 상한 초과 시 최대 HP로 제한
      target.hp = 29;
      FieldMagicLogic.healOne(caster, target);
      expect(target.hp, 30);
    });

    test('3. HealOne의 원작 예외 문구 3종', () {
      final caster = makeMember(magicLevel: 3);
      final target = makeMember(endurance: 10, battleLevel: 2, hp: 20);

      // 만땅이면 "치료할 필요가 없습니다."
      expect(
        FieldMagicLogic.healOne(caster, target).messages.single,
        'Merlin는 치료할 필요가 없습니다.',
      );
      // 기절/독/사망 상태면 "치료될 상태가 아닙니다."
      target.hp = 1;
      target.poison = 1;
      expect(
        FieldMagicLogic.healOne(caster, target).messages.single,
        'Merlin는 치료될 상태가 아닙니다.',
      );
      // SP 부족
      target.poison = 0;
      caster.sp = 1;
      expect(
        FieldMagicLogic.healOne(caster, target).messages.single,
        FieldMagicLogic.spNotEnoughMessage,
      );
    });

    test('4. CureOne(15 SP) / ConsciousOne(10×수치) / RevitalizeOne(30×수치)', () {
      final caster = makeMember(magicLevel: 4, sp: 200);

      // 독 치료
      final poisoned = makeMember(hp: 5)..poison = 3;
      final cure = FieldMagicLogic.cureOne(caster, poisoned);
      expect(cure.spSpent, 15);
      expect(poisoned.poison, 0);
      expect(cure.messages.single, 'Merlin의 독은 제거 되었습니다.');
      // 독이 없으면 안내
      expect(
        FieldMagicLogic.cureOne(caster, makeMember()).messages.single,
        'Merlin는 독에 걸리지 않았습니다.',
      );

      // 의식 회복 (10 * unconscious)
      final fainted = makeMember(hp: 0)..unconscious = 3;
      final conscious = FieldMagicLogic.consciousOne(caster, fainted);
      expect(conscious.spSpent, 30);
      expect(fainted.unconscious, 0);
      expect(fainted.hp, 1); // hp<=0이면 1로
      expect(conscious.messages.single, 'Merlin는 의식을 되찾았습니다.');

      // 부활 (30 * dead)
      final dead = makeMember()..dead = 2;
      final revive = FieldMagicLogic.revitalizeOne(caster, dead);
      expect(revive.spSpent, 60);
      expect(dead.dead, 0);
      expect(dead.unconscious, 1);
      expect(revive.messages.single, 'Merlin는 다시 생명을 얻었습니다.');
      // 살아 있으면 안내
      expect(
        FieldMagicLogic.revitalizeOne(caster, makeMember()).messages.single,
        'Merlin는 아직 살아 있습니다.',
      );
    });

    test('5. 개인 마법 7종의 조합 순서가 원작과 같다', () {
      final caster = makeMember(magicLevel: 4, sp: 200);
      final target = makeMember(hp: 1)
        ..poison = 1
        ..unconscious = 1
        ..dead = 1;

      // 7번(한명 복합 치료) = 부활 → 의식 → 해독 → 치료 순
      final result = FieldMagicLogic.castPersonalCure(caster, target, 7);
      expect(result.messages, [
        'Merlin는 다시 생명을 얻었습니다.',
        'Merlin는 의식을 되찾았습니다.',
        'Merlin의 독은 제거 되었습니다.',
        'Merlin는 치료되어 졌습니다.',
      ]);
      expect(result.spSpent, 30 + 10 + 15 + 8); // dead 1 / unc 1 / 15 / 2*4
    });

    test('6. 전체 마법은 파티 인원만큼 개인 마법을 반복한다', () {
      final caster = makeMember(magicLevel: 6, sp: 300);
      final party = [
        makeMember(name: 'Hercules', endurance: 10, battleLevel: 2, hp: 5),
        makeMember(name: 'Merlin', endurance: 10, battleLevel: 2, hp: 5),
        makeMember(name: 'Genius Kie', endurance: 10, battleLevel: 2, hp: 5),
      ];

      final result = FieldMagicLogic.castGroupCure(caster, party, 1);
      expect(result.messages.length, 3);
      expect(result.spSpent, 3 * 12); // 2 * 6 = 12 씩 3명
      expect(result.messages.first, 'Hercules는 치료되어 졌습니다.');
    });

    test('6b. 전체 마법 조합은 LOREMENU CureSpell 의 단계 순서와 5·6번 배치를 따른다', () {
      PartyMember patient(String name) => makeMember(name: name, hp: 1)
        ..poison = 1
        ..unconscious = 1;
      // 5 : ConscoisAll; CureAll; HealAll (각 단계가 파티 전체를 먼저 돈다)
      var caster = makeMember(magicLevel: 20, sp: 1000);
      var party = [patient('A'), patient('B')];
      var result = FieldMagicLogic.castGroupCure(caster, party, 5);
      expect(result.messages, [
        'A는 의식을 되찾았습니다.',
        'B는 의식을 되찾았습니다.',
        'A의 독은 제거 되었습니다.',
        'B의 독은 제거 되었습니다.',
        'A는 치료되어 졌습니다.',
        'B는 치료되어 졌습니다.',
      ]);
      // 6 : RevitalizeAll 만 실행한다.
      caster = makeMember(magicLevel: 20, sp: 1000);
      party = [makeMember(name: 'A')..dead = 1, patient('B')];
      result = FieldMagicLogic.castGroupCure(caster, party, 6);
      expect(result.messages, ['A는 다시 생명을 얻었습니다.', 'B는 아직 살아 있습니다.']);
      // 7 : RevitalizeAll; ConscoisAll; CureAll; HealAll
      caster = makeMember(magicLevel: 20, sp: 1000);
      party = [makeMember(name: 'A')..dead = 1, patient('B')];
      result = FieldMagicLogic.castGroupCure(caster, party, 7);
      expect(result.messages.take(3), [
        'A는 다시 생명을 얻었습니다.',
        'B는 아직 살아 있습니다.',
        'A는 의식을 되찾았습니다.',
      ]);
    });
  });
}

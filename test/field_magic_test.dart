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
      expect(
        FieldMagicLogic.spNotEnoughMessage,
        '그러나, 마법 지수가 충분하지 않습니다.',
      );

      // 개인 치료: level[2] div 2 + 1 (최대 7)
      expect(FieldMagicLogic.personalCureSlots(1), 1);
      expect(FieldMagicLogic.personalCureSlots(4), 3);
      expect(FieldMagicLogic.personalCureSlots(20), 7);
      // 전체 치료: level[2] div 2 - 3 (0 이하면 사용 불가)
      expect(FieldMagicLogic.groupCureSlots(6), 0);
      expect(FieldMagicLogic.groupCureSlots(8), 1);
      expect(FieldMagicLogic.groupCureSlots(20), 7);
      expect(
        FieldMagicLogic.strongCureNotReady('Merlin'),
        'Merlin는 강한 치료 마법은 아직 불가능 합니다.',
      );
      // 현상계: level[2] div 2 + 1 (최대 8)
      expect(FieldMagicLogic.phenominaSlots(1), 1);
      expect(FieldMagicLogic.phenominaSlots(20), 8);
      // 원작 PhenominaSpell 고정 SP (33~40)
      expect(FieldMagicLogic.phenominaSpCosts, [1, 5, 10, 20, 25, 30, 50, 30]);
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

    test('7. 현상계 8종: SP·식량 제조·금지 동굴이 원작과 같다', () {
      final caster = makeMember(magicLevel: 10, sp: 200);

      expect(FieldMagicLogic.torch(caster).spSpent, 1);
      expect(FieldMagicLogic.levitate(caster).spSpent, 5);
      expect(FieldMagicLogic.waterWalk(caster).spSpent, 10);
      expect(FieldMagicLogic.swampWalk(caster).spSpent, 20);
      expect(FieldMagicLogic.vaporizeMoveSpCost, 25);
      expect(FieldMagicLogic.terrainChangeSpCost, 30);
      expect(FieldMagicLogic.spaceMoveSpCost, 50);

      // 식량 제조: 파티 인원수만큼 증가, 255 상한
      final party = [makeMember(), makeMember(name: 'Kaiser')];
      final food = FieldMagicLogic.createFood(caster, party, 100);
      expect(food.spSpent, 30);
      expect(food.messages[1], '            2 개의 식량이 증가됨');
      expect(food.messages[2], '      일행의 현재 식량은 102 개 입니다');
      final capped = FieldMagicLogic.createFood(caster, party, 254);
      expect(capped.messages[2], contains('255'));

      // 금지 동굴(원작 party.map in [20,25,26])
      expect(FieldMagicLogic.isPhenominaBlocked(20), isTrue);
      expect(FieldMagicLogic.isPhenominaBlocked(25), isTrue);
      expect(FieldMagicLogic.isPhenominaBlocked(26), isTrue);
      expect(FieldMagicLogic.isPhenominaBlocked(19), isFalse);
    });

    test('8. 기화/공간 이동의 지형 판정과 이동 거리', () {
      // 기화 이동: 항상 2칸, 지도 밖이면 불가
      expect(FieldMagicLogic.vaporizeTarget(20, 20, 0, -1, 50, 50), (20, 18));
      expect(FieldMagicLogic.vaporizeTarget(2, 20, 0, -1, 50, 50), isNull);
      // 공간 이동: 1~9칸 (원작 입력 범위)
      expect(FieldMagicLogic.clampSpaceMoveDistance(0), 1);
      expect(FieldMagicLogic.clampSpaceMoveDistance(12), 9);
      expect(FieldMagicLogic.spaceMoveTarget(20, 20, 1, 0, 5, 50, 50), (25, 20));

      // 지형 변화 타일 (원작 town:47 ground:41 den/keep:43)
      expect(FieldMagicLogic.terrainChangeTile('town'), 47);
      expect(FieldMagicLogic.terrainChangeTile('ground'), 41);
      expect(FieldMagicLogic.terrainChangeTile('den'), 43);
      expect(FieldMagicLogic.terrainChangeTile('keep'), 43);

      // 기화 이동 허용 타일 범위
      expect(FieldMagicLogic.vaporizeTileAllowed('den', 43), isTrue);
      expect(FieldMagicLogic.vaporizeTileAllowed('den', 30), isFalse);
      expect(FieldMagicLogic.vaporizeTileAllowed('ground', 24), isTrue);
      expect(FieldMagicLogic.vaporizeTileAllowed('ground', 23), isFalse);
      // 공간 이동 허용 타일 범위 (원작 town/keep 27~47, ground 24~47, den 41~47)
      expect(FieldMagicLogic.spaceMoveTileAllowed('town', 27), isTrue);
      expect(FieldMagicLogic.spaceMoveTileAllowed('town', 26), isFalse);
      expect(FieldMagicLogic.spaceMoveTileAllowed('den', 41), isTrue);
      expect(FieldMagicLogic.spaceMoveTileAllowed('den', 40), isFalse);
    });
  });
}

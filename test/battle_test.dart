import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/item.dart';
import 'package:lore/logic/battle_engine.dart';

/// 고정된 난수 시퀀스를 반환하는 Mock Random 클래스
class DeterministicRandom implements Random {
  final List<int> _values;
  int _index = 0;

  DeterministicRandom(this._values);

  @override
  int nextInt(int max) {
    if (_values.isEmpty) return 0;
    final val = _values[_index % _values.length];
    _index++;
    return val % max;
  }

  @override
  bool nextBool() => nextInt(2) == 1;

  @override
  double nextDouble() => nextInt(100) / 100.0;
}

void main() {
  group('LORE 1993 전투 공식 및 엔진 검증 (BattleEngine Tests)', () {
    test('1. 경험치 및 골드 보상 공식 검증', () {
      final engine = BattleEngine();

      // Orc (eNumber: 1, Level: 1, AC: 1)
      final orc = Monster.create(1);
      expect(engine.calculateExperience(orc), equals(1)); // 1^3 / 8 = 0 -> min 1

      // Imp (eNumber: 9, Level: 3, AC: 2)
      final imp = Monster.create(9);
      // 9^3 / 8 = 729 / 8 = 91
      expect(engine.calculateExperience(imp), equals(91));

      // Skeleton (eNumber: 16, Level: 5, AC: 3)
      final skeleton = Monster.create(16);
      // 16^3 / 8 = 4096 / 8 = 512
      expect(engine.calculateExperience(skeleton), equals(512));

      // 골드 보상: sum(level^3 * ac)
      // orc: 1^3 * 1 = 1
      // imp: 3^3 * 2 = 54
      // skeleton: 5^3 * 3 = 375
      // 총합 = 1 + 54 + 375 = 430
      final gold = engine.calculateGold([orc, imp, skeleton]);
      expect(gold, equals(430));
    });

    test('2. 플레이어 무기 공격 명중 및 대미지 공식 검증', () {
      // 주사위: [명중(0: 0 <= accArms), 분산(0: 분산감소 0%), 저항(99: 저항 실패), 방어차감 난수(0: +1/10)]
      final mockRandom = DeterministicRandom([0, 0, 99, 0]);
      final engine = BattleEngine(random: mockRandom);

      final hero = PartyMember.createPreset(1); // Hercules: strength=17, accArms=15, level=1, weaPower=3 (기사 기본)
      hero.equipWeapon(Item.weapons[4]); // 장검 (power 10 + 기사 보너스 50% = 15)
      expect(hero.weaPower, equals(15));

      final orc = Monster.create(1); // Orc: HP=8, AC=1, Level=1, Resistance=0
      expect(orc.hp, equals(8));

      // Base Damage = 17 * 15 * 1 ~/ 20 = 255 ~/ 20 = 12
      // Variance = 0% 감소 -> 12
      // Resistance = 99 >= 0 -> 저지 실패
      // DefReduce = round(1 * 1 * (0 + 1) / 10) = round(0.1) = 0
      // Final Damage = 12 - 0 = 12
      final result = engine.executePlayerWeaponAttack(hero, orc);

      expect(result.outcome, equals(AttackOutcome.unconscious)); // 체력 8인데 12 대미지 -> 기절
      expect(result.damage, equals(12));
      expect(orc.hp, equals(0));
      expect(orc.isUnconscious, isTrue);
      expect(orc.isDead, isFalse);
      expect(hero.experience, greaterThan(0));
    });

    test('3. 기절(의식불명) 적에 대한 처형 즉사 판정 검증', () {
      final engine = BattleEngine();
      final hero = PartyMember.createPreset(1);
      final orc = Monster.create(1);

      orc.hp = 0;
      orc.isUnconscious = true;
      orc.isDead = false;

      final result = engine.executePlayerWeaponAttack(hero, orc);
      expect(result.outcome, equals(AttackOutcome.killed));
      expect(orc.isDead, isTrue);
    });

    test('4. 마법 공격 SP 소모 및 대미지 공식 검증', () {
      // [명중(0 < 18), 저항(99 >= 0), 방어난수(0)]
      final mockRandom = DeterministicRandom([0, 99, 0]);
      final engine = BattleEngine(random: mockRandom);

      final mage = PartyMember.createPreset(3); // Merlin: mentality=19, accMagic=18, magicLevel=1, SP=19
      final troll = Monster.create(2); // Troll: HP=6, AC=1, Level=1, Resistance=0

      // 1번 마법 시전 (magicIndex=1)
      // SP 소모: round(1 * 1 * 1 / 2) = round(0.5) = 1
      // 기본 위력: 1 * 1 * 1 * 2 = 2
      // DefReduce: round(1 * 1 * 1 / 10) = 0
      // Final Damage: 2
      final initialSp = mage.sp;
      final result = engine.executePlayerMagicAttack(mage, troll, 1);

      expect(mage.sp, equals(initialSp - 1));
      expect(result.outcome, equals(AttackOutcome.hit));
      expect(result.damage, equals(2));
      expect(troll.hp, equals(4)); // 6 - 2 = 4
    });

    test('5. 적의 공격 및 파티원 기절/사망 누적 판정 검증', () {
      // [명중(0 < accArms), 대미지난수(9: (9+1)/10 = 10/10), 플레이어 저항(49 >= 11), 플레이어 방어난수(0)]
      final mockRandom = DeterministicRandom([0, 9, 49, 0]);
      final engine = BattleEngine(random: mockRandom);

      final giant = Monster.create(6); // Giant: Strength=15, Level=2, accArms=8
      // Enemy Base Dmg = 15 * 2 * 10 / 10 = 30
      final hero = PartyMember.createPreset(1); // Hercules: endurance=17, level=1, AC=1 (기사 기본)
      hero.hp = 10;

      // 1차 피격: HP 10 -> 0 이하로 떨어져 기절(unconscious = 1)
      final r1 = engine.executeEnemyWeaponAttack(giant, hero);
      expect(r1.outcome, equals(AttackOutcome.unconscious));
      expect(hero.isUnconscious, isTrue);
      expect(hero.isDead, isFalse);
      expect(hero.unconscious, greaterThan(0));

      // 2차 피격: 기절 상태에서 추가 대미지를 받아 unconscious 누적치가 endurance * level(17)을 초과하면 사망
      final r2 = engine.executeEnemyWeaponAttack(giant, hero);
      expect(hero.isDead, isTrue);
      expect(r2.outcome, equals(AttackOutcome.killed));
    });

    test('6. 도망(RunAway) 확률 공식 검증', () {
      // Random(50) <= agility
      // Hercules agility = 15
      final hero = PartyMember.createPreset(1);

      // 주사위 10 -> 10 <= 15 -> 성공
      final engineSuccess = BattleEngine(random: DeterministicRandom([10]));
      expect(engineSuccess.checkRunAway(hero), isTrue);

      // 주사위 40 -> 40 > 15 -> 실패
      final engineFail = BattleEngine(random: DeterministicRandom([40]));
      expect(engineFail.checkRunAway(hero), isFalse);
    });
  });
}

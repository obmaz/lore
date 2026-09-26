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
      expect(
        engine.calculateExperience(orc),
        equals(1),
      ); // 1^3 / 8 = 0 -> min 1

      // Imp (eNumber: 9, Level: 3, AC: 2)
      final imp = Monster.create(9);
      // 9^3 / 8 = 729 / 8 = 91
      expect(engine.calculateExperience(imp), equals(91));

      // Salamander (eNumber: 16, Level: 4, AC: 3)
      final salamander = Monster.create(16);
      // 16^3 / 8 = 4096 / 8 = 512
      expect(engine.calculateExperience(salamander), equals(512));

      // 골드 보상: sum(level^3 * ac)
      // orc: 1^3 * 1 = 1
      // imp: 3^3 * 2 = 54
      // salamander: 4^3 * 3 = 192
      // 총합 = 1 + 54 + 192 = 247
      final gold = engine.calculateGold([orc, imp, salamander]);
      expect(gold, equals(247));
    });

    test('Major Mummy 전투 금화는 덮어쓴 능력치 대신 원본 도감 값을 쓴다', () {
      final engine = BattleEngine();
      // LORESPEC.PAS:533-546: Sprite 둘을 Sphinx로 바꾸고 E_number=20,
      // Mummy는 AC를 1로 바꾼다. PlusGold는 enemydata[20/26]을 조회한다.
      final enemies = [
        Monster.create(35).withOverrides(name: 'Sphinx', level: 4, eNumber: 20),
        Monster.create(35).withOverrides(name: 'Sphinx', level: 4, eNumber: 20),
        Monster.create(26).withOverrides(name: 'Major Mummy', ac: 1),
      ];
      expect(enemies.last.ac, 1);
      // Kelpie(#20): 5^3 * 2 = 250, Mummy(#26): 7^3 * 3 = 1029.
      expect(engine.calculateGold(enemies), 1529);
    });

    test('의식불명 적의 처형 경험치는 행동 가능한 일행 전원에게 지급한다', () {
      final engine = BattleEngine(random: DeterministicRandom([0, 0, 99, 0]));
      final hero = PartyMember.createPreset(1)..weaPower = 100;
      final ally = PartyMember.createPreset(3);
      final empty = PartyMember.createPreset(4)..name = '';
      final unconscious = PartyMember.createPreset(5)..unconscious = 1;
      final dead = PartyMember.createPreset(6)..dead = 1;
      final noHp = PartyMember.createPreset(7)..hp = 0;
      final party = [hero, ally, empty, unconscious, dead, noHp];
      final before = [for (final member in party) member.experience];
      final target = Monster.create(9)
        ..hp = 0
        ..isUnconscious = true;

      final result = engine.executePlayerWeaponAttack(
        hero,
        target,
        party: party,
      );
      expect(result.outcome, AttackOutcome.killed);
      expect(result.expGained, 91);
      expect(hero.experience, before[0] + 91);
      expect(ally.experience, before[1] + 91);
      for (var i = 2; i < party.length; i++) {
        expect(party[i].experience, before[i]);
      }

      // 멀쩡한 적을 처음 쓰러뜨린 경험치는 공격자에게만 간다.
      final fresh = Monster.create(1);
      final knockdown = engine.executePlayerWeaponAttack(
        hero,
        fresh,
        party: party,
      );
      expect(knockdown.outcome, AttackOutcome.unconscious);
      expect(hero.experience, before[0] + 92);
      expect(ally.experience, before[1] + 91);
    });

    test('단일 마법은 의식불명 적을 SP 없이 처형하고 일행 경험치를 지급한다', () {
      final engine = BattleEngine();
      final mage = PartyMember.createPreset(3)..sp = 0;
      final ally = PartyMember.createPreset(1);
      final party = [mage, ally];
      final beforeMage = mage.experience;
      final beforeAlly = ally.experience;
      final target = Monster.create(9)
        ..hp = 0
        ..isUnconscious = true;

      final result = engine.executePlayerSingleMagicAttack(
        mage,
        target,
        1,
        party: party,
      );
      expect(result.outcome, AttackOutcome.killed);
      expect(mage.sp, 0);
      expect(mage.experience, beforeMage + 91);
      expect(ally.experience, beforeAlly + 91);

      mage.sp = 100;
      final second = Monster.create(9)
        ..hp = 0
        ..isUnconscious = true;
      final all = engine.executePlayerAllMagicAttack(
        mage,
        [second],
        7,
        party: party,
      );
      expect(all.single.outcome, AttackOutcome.killed);
      expect(mage.experience, beforeMage + 182);
      expect(ally.experience, beforeAlly + 182);
    });

    test('염력 1~6단계는 첫 기절과 처형에 각각 원본 경험치 분기를 적용한다', () {
      final engine = BattleEngine(random: DeterministicRandom([0]));
      final caster = PartyMember.createPreset(2)
        ..espLevel = 1
        ..esp = 40;
      final ally = PartyMember.createPreset(1);
      final party = [caster, ally];
      final beforeCaster = caster.experience;
      final beforeAlly = ally.experience;
      final orc = Monster.create(1);

      final knockout = engine.executePlayerESP(
        caster,
        orc,
        45,
        party,
        enemies: [orc],
      );
      expect(knockout.outcome, AttackOutcome.unconscious);
      expect(knockout.expGained, 1);
      expect(orc.isUnconscious, isTrue);
      expect(caster.experience, beforeCaster + 1);
      expect(ally.experience, beforeAlly);

      final execution = engine.executePlayerESP(
        caster,
        orc,
        45,
        party,
        enemies: [orc],
      );
      expect(execution.outcome, AttackOutcome.killed);
      expect(execution.expGained, 1);
      expect(orc.isDead, isTrue);
      expect(caster.experience, beforeCaster + 2);
      expect(ally.experience, beforeAlly + 1);
      expect(caster.esp, 0);
    });

    test('염력 7~10단계는 적 전체를 공격하고 원본의 선택 대상 경험치 계산을 따른다', () {
      final engine = BattleEngine(random: DeterministicRandom([6]));
      final caster = PartyMember.createPreset(2)
        ..espLevel = 7
        ..esp = 40;
      final ally = PartyMember.createPreset(1);
      final party = [caster, ally];
      final selected = Monster.create(1);
      final sleeping = Monster.create(9)
        ..hp = 0
        ..isUnconscious = true;
      final sturdy = Monster.create(2)..hp = 100;
      final enemies = [selected, sleeping, sturdy];
      final beforeCaster = caster.experience;
      final beforeAlly = ally.experience;

      final result = engine.executePlayerESP(
        caster,
        selected,
        45,
        party,
        enemies: enemies,
      );
      expect(result.outcome, AttackOutcome.killed);
      expect(result.damage, 105); // k=7, 적마다 35
      expect(selected.isUnconscious, isTrue);
      expect(sleeping.isDead, isTrue);
      expect(sturdy.hp, 65);
      // 원본은 처형 시 sleeping(#9)이 아닌 선택한 selected(#1)로
      // PlusExperience를 호출한다. 첫 기절 +1, 처형 일행에게 +1.
      expect(result.expGained, 2);
      expect(caster.experience, beforeCaster + 2);
      expect(ally.experience, beforeAlly + 1);
      expect(caster.esp, 20);
    });

    test('염력 13~14단계 중독은 저항과 ESP 명중 판정을 모두 통과해야 한다', () {
      final caster = PartyMember.createPreset(2)
        ..espLevel = 13
        ..esp = 60
        ..accEsp = 5;
      final party = [caster];
      final resistant = Monster.create(1)..resistance = 40;
      final resisted = BattleEngine(random: DeterministicRandom([12, 0]))
          .executePlayerESP(caster, resistant, 45, party, enemies: [resistant]);
      expect(resisted.outcome, AttackOutcome.resisted);
      expect(resistant.isPoisoned, isFalse);

      final missedTarget = Monster.create(1);
      final missed = BattleEngine(random: DeterministicRandom([12, 50, 39]))
          .executePlayerESP(
            caster,
            missedTarget,
            45,
            party,
            enemies: [missedTarget],
          );
      expect(missed.outcome, AttackOutcome.miss);
      expect(missedTarget.isPoisoned, isFalse);

      final poisonedTarget = Monster.create(1);
      final success = BattleEngine(random: DeterministicRandom([12, 50, 0]))
          .executePlayerESP(
            caster,
            poisonedTarget,
            45,
            party,
            enemies: [poisonedTarget],
          );
      expect(success.outcome, AttackOutcome.debuffed);
      expect(poisonedTarget.isPoisoned, isTrue);
      expect(caster.esp, 0);
    });

    test('염력 15~17단계 심장 정지는 저항·부분 피해·저체력 기절·성공을 구분한다', () {
      final caster = PartyMember.createPreset(2)
        ..espLevel = 15
        ..esp = 80
        ..accEsp = 5;
      final party = [caster];
      final resistant = Monster.create(1)
        ..hp = 20
        ..resistance = 20;
      final resisted = BattleEngine(random: DeterministicRandom([14, 0]))
          .executePlayerESP(caster, resistant, 45, party, enemies: [resistant]);
      expect(resisted.outcome, AttackOutcome.resisted);
      expect(resistant.resistance, 15);
      expect(resistant.hp, 20);
      expect(resistant.isUnconscious, isFalse);

      final sturdy = Monster.create(1)..hp = 20;
      final graze = BattleEngine(random: DeterministicRandom([14, 50, 79]))
          .executePlayerESP(caster, sturdy, 45, party, enemies: [sturdy]);
      expect(graze.outcome, AttackOutcome.hit);
      expect(sturdy.hp, 15);
      expect(sturdy.isUnconscious, isFalse);

      final weak = Monster.create(1)..hp = 8;
      final weakHit = BattleEngine(random: DeterministicRandom([14, 50, 79]))
          .executePlayerESP(caster, weak, 45, party, enemies: [weak]);
      expect(weakHit.outcome, AttackOutcome.unconscious);
      expect(weak.hp, 0);
      expect(weak.isUnconscious, isTrue);

      final successTarget = Monster.create(1)..hp = 20;
      final success = BattleEngine(random: DeterministicRandom([14, 50, 0]))
          .executePlayerESP(
            caster,
            successTarget,
            45,
            party,
            enemies: [successTarget],
          );
      expect(success.outcome, AttackOutcome.unconscious);
      expect(successTarget.hp, 20); // 원본은 명중 시 HP를 건드리지 않는다.
      expect(successTarget.isUnconscious, isTrue);
      expect(caster.esp, 0);
    });

    test('염력 18단계 이상 환상은 저항 시 민첩, 성공 시 두 정확도를 낮춘다', () {
      final caster = PartyMember.createPreset(2)
        ..espLevel = 18
        ..esp = 60
        ..accEsp = 5;
      final party = [caster];
      final resistant = Monster.create(3)..resistance = 10;
      final agility = resistant.agility;
      final resisted = BattleEngine(random: DeterministicRandom([17, 0]))
          .executePlayerESP(caster, resistant, 45, party, enemies: [resistant]);
      expect(resisted.outcome, AttackOutcome.resisted);
      expect(resistant.agility, agility - 5);

      final missedTarget = Monster.create(3)..resistance = 0;
      final arms = missedTarget.accArms;
      final magic = missedTarget.accMagic;
      final missed = BattleEngine(random: DeterministicRandom([17, 39, 29]))
          .executePlayerESP(
            caster,
            missedTarget,
            45,
            party,
            enemies: [missedTarget],
          );
      expect(missed.outcome, AttackOutcome.miss);
      expect(missedTarget.accArms, arms);
      expect(missedTarget.accMagic, magic);

      final hitTarget = Monster.create(3)..resistance = 0;
      final hit = BattleEngine(random: DeterministicRandom([17, 39, 0]))
          .executePlayerESP(caster, hitTarget, 45, party, enemies: [hitTarget]);
      expect(hit.outcome, AttackOutcome.debuffed);
      expect(hitTarget.accArms, arms - 1);
      expect(hitTarget.accMagic, magic - 1);
      expect(caster.esp, 0);
    });

    test('2. 플레이어 무기 공격 명중 및 대미지 공식 검증', () {
      // 주사위: [명중(0: 0 <= accArms), 분산(0: 분산감소 0%), 저항(99: 저항 실패), 방어차감 난수(0: +1/10)]
      final mockRandom = DeterministicRandom([0, 0, 99, 0]);
      final engine = BattleEngine(random: mockRandom);

      final hero = PartyMember.createPreset(
        1,
      ); // Hercules: strength=17, accArms=15, level=1, weaPower=3 (기사 기본)
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

      expect(
        result.outcome,
        equals(AttackOutcome.unconscious),
      ); // 체력 8인데 12 대미지 -> 기절
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

      final mage = PartyMember.createPreset(
        3,
      ); // Merlin: mentality=19, accMagic=18, magicLevel=1, SP=19
      final troll = Monster.create(
        2,
      ); // Troll: HP=6, AC=1, Level=1, Resistance=0

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
      final hero = PartyMember.createPreset(
        1,
      ); // Hercules: endurance=17, level=1, AC=1 (기사 기본)
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

    test('7. 원작 `with enemy[i] do` 적별 덮어쓰기(이름/방어도/레벨)', () {
      // 원작 map 11 미이라의 방: `name := 'Sphinx'; level := 4; E_number := 20`
      final sphinx = Monster.create(35)
          .withOverrides(name: 'Sphinx', level: 4, special: 0, eNumber: 20);
      expect(sphinx.name, 'Sphinx');
      expect(sphinx.level, 4);
      expect(sphinx.eNumber, 20);
      expect(sphinx.special, 0);
      // 원작은 `level` 을 바꾸면 최대 HP 도 `endurance * level` 로 다시 잡는다.
      expect(sphinx.maxHp, sphinx.endurance * 4);
      expect(sphinx.hp, sphinx.maxHp);

      // 원작 map 18: `enemy[2] do begin name := 'Dragon''s tail'; ac := 8; end;`
      final tail = Monster.create(39)
          .withOverrides(name: "Dragon's tail", ac: 8);
      expect(tail.name, "Dragon's tail");
      expect(tail.ac, 8);
      // 레벨을 건드리지 않으면 HP 는 그대로다.
      expect(tail.level, Monster.create(39).level);
      expect(tail.hp, Monster.create(39).hp);
    });
  });
}

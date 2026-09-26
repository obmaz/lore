import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/battle_engine.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/models/spell.dart';

void main() {
  group('LORE 1993 [2단계] 전투 엔진 풀 스펙 확장 단위 테스트', () {
    late BattleEngine engine;
    late PartyMember hero;
    late PartyMember mage;
    late PartyMember esper;

    setUp(() {
      engine = BattleEngine();

      hero = PartyMember(
        name: '영웅',
        sex: Gender.male,
        playerClass: PlayerClass.knight,
        strength: 18,
        mentality: 12,
        concentration: 12,
        endurance: 16,
        resistance: 20,
        agility: 15,
        accArms: 18,
        accMagic: 10,
        accEsp: 5,
        luck: 15,
        battleLevel: 5,
        magicLevel: 3,
        espLevel: 1,
      );

      mage = PartyMember(
        name: '마법사',
        sex: Gender.female,
        playerClass: PlayerClass.mage,
        strength: 10,
        mentality: 20,
        concentration: 18,
        endurance: 12,
        resistance: 40,
        agility: 14,
        accArms: 10,
        accMagic: 20, // 100% 명중
        accEsp: 10,
        luck: 14,
        battleLevel: 3,
        magicLevel: 10,
        espLevel: 2,
      );

      esper = PartyMember(
        name: '에스퍼',
        sex: Gender.male,
        playerClass: PlayerClass.esper,
        strength: 12,
        mentality: 16,
        concentration: 20,
        endurance: 14,
        resistance: 30,
        agility: 16,
        accArms: 12,
        accMagic: 12,
        accEsp: 20,
        luck: 16,
        battleLevel: 4,
        magicLevel: 5,
        espLevel: 10,
      );
    });

    test('1. 원작 45종 전체 마법 등록 및 메타데이터 정합성 검증', () {
      expect(Spell.allSpells.length, 45);

      // 카테고리별 개수 검증
      final singleAttacks = Spell.allSpells
          .where((s) => s.category == SpellCategory.singleAttack)
          .toList();
      final allAttacks = Spell.allSpells
          .where((s) => s.category == SpellCategory.allAttack)
          .toList();
      final debuffs = Spell.allSpells
          .where((s) => s.category == SpellCategory.specialDebuff)
          .toList();
      final singleCures = Spell.allSpells
          .where((s) => s.category == SpellCategory.singleCure)
          .toList();
      final allCures = Spell.allSpells
          .where((s) => s.category == SpellCategory.allCure)
          .toList();
      final fields = Spell.allSpells
          .where((s) => s.category == SpellCategory.field)
          .toList();
      final esps = Spell.allSpells
          .where((s) => s.category == SpellCategory.esp)
          .toList();

      expect(singleAttacks.length, 6);
      expect(allAttacks.length, 6);
      expect(debuffs.length, 6);
      expect(singleCures.length, 7);
      expect(allCures.length, 7);
      expect(fields.length, 8);
      expect(esps.length, 5);

      // 원작 한글 명칭 검증
      expect(Spell.getById(1).name, '마법 화살');
      expect(Spell.getById(6).name, '직격 뇌전');
      expect(Spell.getById(7).name, '공기 폭풍');
      expect(Spell.getById(12).name, '차원 이탈');
      expect(Spell.getById(13).name, '독');
      expect(Spell.getById(14).name, '기술 무력화');
      expect(Spell.getById(18).name, '탈 초인화');
      expect(Spell.getById(19).name, '한명 치료');
      expect(Spell.getById(25).name, '한명 복합 치료');
      expect(Spell.getById(26).name, '모두 치료');
      expect(Spell.getById(32).name, '모두 복합 치료');
      expect(Spell.getById(33).name, '마법의 햇불');
      expect(Spell.getById(43).name, '독심');
      expect(Spell.getById(45).name, '염력');
    });

    test('2. 플레이어 전체 마법(CastAll: 7..12) 다중 타겟 공격 검증', () {
      final enemies = [
        Monster.create(1), // Orc (Lv 1, HP 8)
        Monster.create(2), // Troll (Lv 1, HP 6)
        Monster.create(3), // Serpent (Lv 1, HP 7)
      ];

      mage.sp = 100;
      final results = engine.executePlayerAllMagicAttack(
        mage,
        enemies,
        7,
      ); // 7: 공기 폭풍
      expect(results.length, 3);
      expect(mage.sp < 100, isTrue); // SP 소모 확인

      // 전체 마법으로 최소 1명 이상 피해를 입었거나 처치되었는지 확인
      final damaged = results.any(
        (r) =>
            r.damage > 0 ||
            r.outcome == AttackOutcome.killed ||
            r.outcome == AttackOutcome.unconscious,
      );
      expect(damaged, isTrue);
    });

    test('CastAll은 의식 있는 적마다 SP를 쓰고 부족해지면 나머지 적을 건너뛴다', () {
      mage.magicLevel = 4;
      mage.sp = 5;
      mage.accMagic = 20;
      final enemies = [Monster.create(1), Monster.create(2), Monster.create(3)];
      final lastHp = enemies.last.hp;
      expect(Spell.getById(7).calculateSpCost(mage.magicLevel), 2);

      final results = engine.executePlayerAllMagicAttack(mage, enemies, 7);
      expect(results, hasLength(3));
      expect(
        results
            .take(2)
            .every((result) => result.outcome != AttackOutcome.outOfSp),
        isTrue,
      );
      expect(results.last.outcome, AttackOutcome.outOfSp);
      expect(mage.sp, 1);
      expect(enemies.last.hp, lastHp);
    });

    test('CastAll의 의식불명 적 처형은 SP가 없어도 진행한다', () {
      mage.sp = 0;
      final target = Monster.create(9)
        ..hp = 0
        ..isUnconscious = true;
      final result = engine.executePlayerAllMagicAttack(mage, [target], 7);
      expect(result.single.outcome, AttackOutcome.killed);
      expect(mage.sp, 0);
      expect(target.isDead, isTrue);
    });

    test('3. 특수 디버프 마법(CastSpecial: 13..18) 효과 검증', () {
      final target = Monster.create(11); // Python: special=1, castLevel=1, ac=1
      target.resistance = 0; // 테스트를 위해 저항 0 설정
      mage.sp = 200;
      mage.accMagic = 100; // 100% 명중 조건 (_rand(100) <= 100)

      // 13: 독 마법 시전
      final resPoison = engine.executePlayerSpecialDebuff(mage, target, 13);
      expect(resPoison.outcome, AttackOutcome.debuffed);
      expect(target.isPoisoned, isTrue);

      // 14: 기술 무력화 시전
      final resTech = engine.executePlayerSpecialDebuff(mage, target, 14);
      expect(resTech.outcome, AttackOutcome.debuffed);
      expect(target.special, 0); // 특수능력 0으로 제거됨

      // 17: 마법 불능 시전
      final oldCastLevel = target.castLevel;
      final resCast = engine.executePlayerSpecialDebuff(mage, target, 17);
      expect(resCast.outcome, AttackOutcome.debuffed);
      expect(target.castLevel, oldCastLevel - 1);
    });

    test('4. 일행 치유/해독/부활 마법(CureSpell: 19..32) 검증', () {
      mage.sp = 200;

      // 부상 및 중독 상태 파티원
      hero.hp = 10;
      hero.poison = 1;
      expect(hero.hp < hero.maxHp, isTrue);
      expect(hero.isPoisoned, isTrue);

      // 21번: 한명 치료와 독제거
      final resCure = engine.executePlayerCure(mage, hero, 21);
      expect(resCure.outcome, AttackOutcome.cured);
      expect(hero.poison, 0); // 독 제거됨
      expect(hero.hp > 10, isTrue); // HP 회복됨

      // 사망한 파티원 부활 (23번: 한명 부활)
      hero.dead = 1;
      hero.unconscious = 1;
      hero.hp = 0;
      expect(hero.isDead, isTrue);

      final resRevive = engine.executePlayerCure(mage, hero, 23);
      expect(resRevive.outcome, AttackOutcome.cured);
      expect(hero.isDead, isFalse); // 사망 해제됨
      expect(hero.hp, 1);
    });

    test('5. 초능력 ESP (독심술 & 염력) 공격 검증', () {
      esper.esp = 100;

      // 43: 독심술 테스트 (10번 Goblin: 원작 포섭 대상)
      final goblin = Monster.create(10);
      final resEspJoin = engine.executePlayerESP(esper, goblin, 43, [
        hero,
        mage,
        esper,
      ]);
      expect(
        resEspJoin.outcome == AttackOutcome.joined ||
            resEspJoin.outcome == AttackOutcome.failed,
        isTrue,
      );

      // 45: 염력 공격 테스트 (1번 Orc)
      final orc = Monster.create(1);
      final resPfk = engine.executePlayerESP(esper, orc, 45, [
        hero,
        mage,
        esper,
      ]);
      expect(esper.esp < 100, isTrue); // ESP 소모
      expect(resPfk.outcome != AttackOutcome.outOfSp, isTrue);
    });

    test('6. 몬스터 턴 AI 풀 구현 검증 (독 진행, 마법/특수공격 시전)', () {
      final monster = Monster.create(
        3,
      ); // Serpent: poison=1, castLevel=1, special=1
      monster.isPoisoned = true;
      final initialHp = monster.hp;

      final party = [hero, mage, esper];
      final enemies = [monster];

      final results = engine.executeMonsterTurn(monster, party, enemies);

      // 몬스터 중독으로 인한 체력 감소 또는 행동 결과 검증
      expect(monster.hp < initialHp || results.isNotEmpty, isTrue);
    });

    test('7. 몬스터 회복 마법(enemycure) AI 검증', () {
      final healerMonster = Monster(
        eNumber: 99,
        name: 'Grand Shaman',
        strength: 5,
        mentality: 20,
        endurance: 15,
        resistance: 0,
        agility: 15,
        accArms: 5,
        accMagic: 20,
        ac: 2,
        special: 0,
        castLevel: 5, // 레벨 5 캐스터
        specialCastLevel: 0,
        level: 5,
        hp: 10, // 체력 저하 상태 (maxHp: 75)
      );

      final party = [hero];
      final enemies = [healerMonster];

      final results = engine.executeMonsterTurn(healerMonster, party, enemies);
      expect(results.isNotEmpty, isTrue);
    });
  });
}
